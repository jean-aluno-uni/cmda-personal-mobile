import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_classic/flutter_blue_classic.dart';

import 'api.dart';

const descricaoDtc = {
  'P0217': 'Superaquecimento do motor',
  'P0301': 'Falha de ignição no cilindro 1',
  'P0562': 'Tensão do sistema baixa',
  'P0563': 'Tensão do sistema alta',
  'P0700': 'Falha no sistema de transmissão',
};

String origemDoDtc(String codigo) {
  if (codigo.startsWith('P07')) return 'Transmissao';
  if (codigo.startsWith('P056')) return 'Bateria';
  return 'Motor';
}

class Obd extends ChangeNotifier {
  Obd._();

  static final instancia = Obd._();

  final _bluetooth = FlutterBlueClassic();
  BluetoothConnection? _conexao;
  StreamSubscription<Uint8List>? _entrada;
  Completer<String>? _resposta;
  Timer? _timer;
  String _buffer = '';
  bool _lendo = false;
  bool _manual = false;
  int _falhas = 0;
  Set<String> _dtcsAnteriores = {};
  String? _endereco;

  bool conectado = false;
  bool conectando = false;
  String? dispositivo;
  String? aviso;
  Map<String, num> ultimaLeitura = {};
  List<String> dtcs = [];
  DateTime? ultimaAtualizacao;

  Future<List<BluetoothDevice>> pareados() async => await _bluetooth.bondedDevices ?? [];

  Future<bool> conectar(String endereco, String nome) async {
    _manual = false;
    _endereco = endereco;
    dispositivo = nome;
    conectando = true;
    aviso = null;
    notifyListeners();
    try {
      final conexao = await _bluetooth.connect(endereco);
      if (conexao == null || !conexao.isConnected) throw Exception();
      _conexao = conexao;
      _entrada = conexao.input?.listen(_receber, onDone: () => _perdeu('O veículo encerrou a conexão Bluetooth.'));
      for (final comando in ['ATZ', 'ATE0', 'ATL0', 'ATS0', 'ATH0', 'ATSP0']) {
        await _enviar(comando);
      }
      Sessao.ultimoDispositivo = endereco;
      conectado = true;
      _falhas = 0;
      _dtcsAnteriores = {};
      await _avisarApi(true);
      _timer = Timer.periodic(const Duration(seconds: 2), (_) => _ler());
    } catch (_) {
      await _fechar();
      aviso = 'Não foi possível conectar em $nome. Confira se o simulador ou o adaptador está ligado.';
    }
    conectando = false;
    notifyListeners();
    return conectado;
  }

  Future<void> desconectar() async {
    _manual = true;
    await _fechar();
    conectado = false;
    aviso = null;
    notifyListeners();
    await _avisarApi(false);
  }

  Future<void> _perdeu(String motivo) async {
    if (!conectado) return;
    await _fechar();
    conectado = false;
    aviso = '$motivo Tentando reconectar...';
    notifyListeners();
    await _avisarApi(false);
    for (var tentativa = 0; tentativa < 8 && !conectado && !_manual && _endereco != null; tentativa++) {
      await Future.delayed(const Duration(seconds: 6));
      if (_manual || conectando || conectado) continue;
      await conectar(_endereco!, dispositivo ?? 'veículo');
      if (!conectado && !_manual) aviso = '$motivo Tentando reconectar...';
    }
    if (!conectado && !_manual) {
      aviso = 'O adaptador não respondeu. Confira se ele está ligado e toque nele para conectar de novo.';
      notifyListeners();
    }
  }

  Future<void> _fechar() async {
    _timer?.cancel();
    _timer = null;
    await _entrada?.cancel();
    _entrada = null;
    try {
      await _conexao?.close();
    } catch (_) {}
    _conexao = null;
    _lendo = false;
  }

  Future<void> _avisarApi(bool ligado) async {
    final id = Sessao.veiculoId;
    if (id == null || Sessao.token == null) return;
    try {
      await apiCall('/vehicles/$id/${ligado ? 'connect' : 'disconnect'}', metodo: 'POST');
    } catch (_) {}
  }

  void _receber(Uint8List dados) {
    _buffer += ascii.decode(dados, allowInvalid: true);
    final fim = _buffer.indexOf('>');
    if (fim >= 0 && _resposta != null && !_resposta!.isCompleted) {
      final texto = _buffer.substring(0, fim);
      _buffer = _buffer.substring(fim + 1);
      _resposta!.complete(texto);
    }
  }

  Future<String> _enviar(String comando) {
    _buffer = '';
    _resposta = Completer<String>();
    _conexao!.writeString('$comando\r');
    return _resposta!.future.timeout(const Duration(seconds: 3));
  }

  List<String> _linhas(String texto) => texto
      .split(RegExp(r'[\r\n]+'))
      .map((linha) => linha.replaceAll(' ', '').trim().toUpperCase())
      .where((linha) => linha.isNotEmpty)
      .toList();

  List<int>? _bytes(String linha, int inicio) {
    final bytes = <int>[];
    for (var i = inicio; i + 2 <= linha.length; i += 2) {
      final valor = int.tryParse(linha.substring(i, i + 2), radix: 16);
      if (valor == null) return null;
      bytes.add(valor);
    }
    return bytes;
  }

  Future<List<int>?> _pid(String pid, int tamanho) async {
    for (final linha in _linhas(await _enviar('01$pid'))) {
      if (linha.startsWith('41$pid')) {
        final bytes = _bytes(linha, 4);
        if (bytes != null && bytes.length >= tamanho) return bytes;
      }
    }
    return null;
  }

  Future<List<String>> _codigos() async {
    final codigos = <String>[];
    for (final linha in _linhas(await _enviar('03'))) {
      if (!linha.startsWith('43')) continue;
      final bytes = _bytes(linha, 2) ?? [];
      for (var i = 0; i + 1 < bytes.length; i += 2) {
        final a = bytes[i];
        final b = bytes[i + 1];
        if (a == 0 && b == 0) continue;
        final codigo = 'PCBU'[a >> 6] +
            ((a >> 4) & 3).toString() +
            (a & 15).toRadixString(16) +
            b.toRadixString(16).padLeft(2, '0');
        codigos.add(codigo.toUpperCase());
      }
    }
    return codigos;
  }

  Future<void> _ler() async {
    if (_lendo || _conexao == null || !conectado) return;
    _lendo = true;
    try {
      final rpm = await _pid('0C', 2);
      final velocidade = await _pid('0D', 1);
      final liquido = await _pid('05', 1);
      final oleo = await _pid('5C', 1);
      final ar = await _pid('0F', 1);
      final tensao = await _pid('42', 2);
      final codigos = await _codigos();
      _falhas = 0;

      final leitura = <String, num>{
        if (rpm != null) 'rpm': ((rpm[0] * 256 + rpm[1]) / 4).round(),
        if (velocidade != null) 'velocidadeKmh': velocidade[0],
        if (liquido != null) 'tempArrefecimentoC': liquido[0] - 40,
        if (oleo != null) 'tempOleoC': oleo[0] - 40,
        if (ar != null) 'tempArC': ar[0] - 40,
        if (tensao != null) 'tensaoBateriaV': ((tensao[0] * 256 + tensao[1]) / 100).round() / 10,
      };
      final temperaturas = [leitura['tempArrefecimentoC'], leitura['tempOleoC']].whereType<num>().toList();
      if (temperaturas.isNotEmpty) {
        leitura['tempMotorC'] = (temperaturas.reduce((a, b) => a + b) / temperaturas.length * 10).round() / 10;
      }

      ultimaLeitura = leitura;
      dtcs = codigos;
      ultimaAtualizacao = DateTime.now();
      aviso = null;
      notifyListeners();
      await _enviarParaApi(leitura, codigos);
    } on TimeoutException {
      _falhas++;
      _lendo = false;
      if (_falhas >= 3) await _perdeu('O veículo parou de responder.');
    } on ApiErro catch (erro) {
      aviso = erro.mensagem;
      notifyListeners();
    } catch (_) {
      _falhas++;
    }
    _lendo = false;
  }

  Future<void> _enviarParaApi(Map<String, num> leitura, List<String> codigos) async {
    final id = Sessao.veiculoId;
    if (id == null || Sessao.token == null) return;
    if (leitura.isNotEmpty) {
      await apiCall('/vehicles/$id/readings', metodo: 'POST', corpo: leitura);
    }
    for (final codigo in codigos.toSet().difference(_dtcsAnteriores)) {
      await apiCall('/vehicles/$id/alerts', metodo: 'POST', corpo: {
        'origem': origemDoDtc(codigo),
        'titulo': 'Código de falha $codigo',
        'descricao': descricaoDtc[codigo] ?? 'Código de falha informado pelo veículo',
        'nivel': 'high',
      });
    }
    _dtcsAnteriores = codigos.toSet();
  }
}
