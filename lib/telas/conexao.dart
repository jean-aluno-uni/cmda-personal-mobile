import 'package:flutter/material.dart';
import 'package:flutter_blue_classic/flutter_blue_classic.dart';

import '../api.dart';
import '../obd.dart';
import '../widgets.dart';

String nomeDoDispositivo(BluetoothDevice dispositivo) {
  final alias = dispositivo.alias;
  if (alias != null && alias.isNotEmpty) return alias;
  return dispositivo.name ?? dispositivo.address;
}

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
        _erro = lista.isEmpty ? 'Nenhum dispositivo pareado. Pareie o adaptador OBD2 nas configurações de Bluetooth do Android.' : null;
      });
    } catch (_) {
      setState(() {
        _dispositivos = [];
        _erro = 'Não foi possível acessar o Bluetooth. Ligue o Bluetooth e permita o acesso a dispositivos próximos.';
      });
    }
  }

  Future<void> _conectar(BluetoothDevice dispositivo) async {
    final conectou = await _obd.conectar(dispositivo.address, nomeDoDispositivo(dispositivo));
    if (conectou && mounted) Navigator.pop(context);
  }

  Widget _valor(String rotulo, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(child: Text(rotulo, style: const TextStyle(fontSize: 13, color: cinza))),
        Text(valor, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
          cabecalho: const Cabecalho(titulo: 'Conectar ao veículo', voltar: true),
          filhos: [
            const Secao('Adaptador OBD2'),
            Cartao(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(_obd.conectado ? Icons.bluetooth_connected : Icons.bluetooth, color: _obd.conectado ? verde : cinzaClaro),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _obd.conectando
                          ? 'Conectando em ${_obd.dispositivo}...'
                          : _obd.conectado
                              ? 'Conectado em ${_obd.dispositivo}'
                              : 'Nenhum adaptador conectado',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Selo(_obd.conectado ? 'Conectado' : 'Desconectado', _obd.conectado ? TipoSelo.ok : TipoSelo.alto),
                ]),
                if (_obd.aviso != null)
                  Padding(padding: const EdgeInsets.only(top: 10), child: Text(_obd.aviso!, style: const TextStyle(fontSize: 12, color: vermelho))),
                if (_obd.conectado && leitura.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Divider(color: borda),
                  _valor('RPM', leitura['rpm'] == null ? '—' : milhar(leitura['rpm']!)),
                  _valor('Velocidade', '${leitura['velocidadeKmh'] ?? '—'} km/h'),
                  _valor('Líquido de arrefecimento', grau(leitura['tempArrefecimentoC'])),
                  _valor('Óleo', grau(leitura['tempOleoC'])),
                  _valor('Ar de admissão', grau(leitura['tempArC'])),
                  _valor('Códigos de falha', _obd.dtcs.isEmpty ? 'nenhum' : _obd.dtcs.join(', ')),
                ],
              ]),
            ),
            if (_obd.conectado)
              OutlinedButton(
                onPressed: _obd.desconectar,
                style: OutlinedButton.styleFrom(
                  foregroundColor: vermelho,
                  side: const BorderSide(color: vermelho, width: 2),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Desconectar'),
              ),
            if (!_obd.conectado) ...[
              Secao('Dispositivos pareados', acao: IconButton(onPressed: _listar, icon: const Icon(Icons.refresh, color: cinza))),
              if (_dispositivos == null) const Aviso('Carregando...'),
              if (_erro != null) Cartao(child: Aviso(_erro!, erro: true)),
              for (final dispositivo in _dispositivos ?? <BluetoothDevice>[])
                Cartao(
                  aoTocar: _obd.conectando ? null : () => _conectar(dispositivo),
                  child: Row(children: [
                    const Icon(Icons.settings_input_component, color: vermelho),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(nomeDoDispositivo(dispositivo), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        Text(dispositivo.address, style: const TextStyle(fontSize: 11, color: cinza)),
                      ]),
                    ),
                    if (dispositivo.address == Sessao.ultimoDispositivo) const Selo('Último usado', TipoSelo.ok),
                  ]),
                ),
            ],
          ],
        );
      },
    );
  }
}
