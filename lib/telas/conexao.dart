import 'package:flutter/material.dart';
import 'package:flutter_blue_classic/flutter_blue_classic.dart';

import '../api.dart';
import '../obd.dart';
import '../widgets.dart';

class ConexaoTela extends StatefulWidget {
  const ConexaoTela({super.key});

  @override
  State<ConexaoTela> createState() => _ConexaoTelaState();
}

class _ConexaoTelaState extends State<ConexaoTela> {
  final _obd = Obd.instancia;
  List<BluetoothDevice>? _dispositivos;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _listar();
  }

  Future<void> _listar() async {
    try {
      final lista = await _obd.pareados();
      setState(() {
        _dispositivos = lista;
        _erro = lista.isEmpty ? 'Nenhum dispositivo pareado. Pareie o notebook ou o adaptador nas configurações do Android.' : null;
      });
    } catch (_) {
      setState(() {
        _dispositivos = [];
        _erro = 'Não foi possível acessar o Bluetooth. Ligue o Bluetooth e permita o acesso a dispositivos próximos.';
      });
    }
  }

  Widget _valor(String rotulo, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(child: Text(rotulo, style: const TextStyle(color: cinza))),
        Text(valor, style: const TextStyle(fontWeight: FontWeight.w600)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _obd,
      builder: (context, _) {
        final leitura = _obd.ultimaLeitura;
        return Pagina(
          cabecalho: const Cabecalho(titulo: 'Conexão com o veículo', subtitulo: 'Adaptador OBD2 ELM327 por Bluetooth'),
          filhos: [
            Cartao(
              titulo: 'Status',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(_obd.conectado ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                        color: _obd.conectado ? verde : cinza),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_obd.conectando
                        ? 'Conectando em ${_obd.dispositivo}...'
                        : _obd.conectado
                            ? 'Conectado em ${_obd.dispositivo}'
                            : 'Desconectado')),
                    if (_obd.conectado)
                      TextButton(onPressed: _obd.desconectar, child: const Text('Desconectar', style: TextStyle(color: vermelho))),
                  ]),
                  if (_obd.aviso != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_obd.aviso!, style: const TextStyle(color: vermelho))),
                ],
              ),
            ),
            if (_obd.conectado && leitura.isNotEmpty)
              Cartao(
                titulo: 'Última leitura do veículo',
                child: Column(children: [
                  _valor('RPM', numero(leitura['rpm'])),
                  _valor('Velocidade', '${numero(leitura['velocidadeKmh'])} km/h'),
                  _valor('Líquido de arrefecimento', '${numero(leitura['tempArrefecimentoC'])} °C'),
                  _valor('Óleo', '${numero(leitura['tempOleoC'])} °C'),
                  _valor('Ar de admissão', '${numero(leitura['tempArC'])} °C'),
                  _valor('Bateria', '${numero(leitura['tensaoBateriaV'], casas: 1)} V'),
                  _valor('Códigos de falha', _obd.dtcs.isEmpty ? 'nenhum' : _obd.dtcs.join(', ')),
                  const SizedBox(height: 6),
                  const Text('Cada leitura é enviada para a API a cada 2 segundos.', style: TextStyle(fontSize: 12, color: cinza)),
                ]),
              ),
            Row(children: [
              const Expanded(child: Secao('Dispositivos pareados')),
              IconButton(onPressed: _listar, icon: const Icon(Icons.refresh)),
            ]),
            if (_dispositivos == null) const Carregando(),
            if (_erro != null) Mensagem(_erro!, erro: true),
            for (final dispositivo in _dispositivos ?? <BluetoothDevice>[])
              Cartao(
                aoTocar: _obd.conectando || _obd.conectado
                    ? null
                    : () => _obd.conectar(dispositivo.address, dispositivo.name ?? dispositivo.address),
                child: Row(children: [
                  const Icon(Icons.devices, color: cinza),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(dispositivo.name ?? 'Sem nome', style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(dispositivo.address, style: const TextStyle(fontSize: 12, color: cinza)),
                    ]),
                  ),
                  if (dispositivo.address == Sessao.ultimoDispositivo) const Selo('último usado', azul),
                ]),
              ),
          ],
        );
      },
    );
  }
}
