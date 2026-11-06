import 'package:flutter/material.dart';

import '../api.dart';
import '../obd.dart';
import '../widgets.dart';

String saudacao() {
  final hora = DateTime.now().hour;
  if (hora < 12) return 'Bom dia';
  if (hora < 18) return 'Boa tarde';
  return 'Boa noite';
}

class StatusObd extends StatelessWidget {
  const StatusObd({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Obd.instancia,
      builder: (context, _) {
        final obd = Obd.instancia;
        final texto = obd.conectando
            ? 'Conectando...'
            : obd.conectado
                ? 'Bluetooth: ${obd.dispositivo}'
                : 'Bluetooth desconectado';
        return Padding(
          padding: const EdgeInsets.only(top: 14),
          child: OutlinedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/conexao'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            icon: Icon(obd.conectado ? Icons.bluetooth_connected : Icons.bluetooth_disabled),
            label: Text(texto),
          ),
        );
      },
    );
  }
}

class HomeTela extends StatefulWidget {
  const HomeTela({super.key});

  @override
  State<HomeTela> createState() => _HomeTelaState();
}

class _HomeTelaState extends State<HomeTela> with AtualizacaoPeriodica {
  Map? _usuario;
  Map? _veiculo;
  Map? _telemetria;
  Map? _alertas;

  @override
  Future<void> buscar() async {
    final id = Sessao.veiculoId;
    final respostas = await Future.wait([
      apiCall('/users/me'),
      apiCall('/vehicles/$id'),
      apiCall('/vehicles/$id/telemetry/latest'),
      apiCall('/vehicles/$id/alerts/summary?period=24h'),
    ]);
    _usuario = respostas[0];
    _veiculo = respostas[1];
    _telemetria = respostas[2];
    _alertas = respostas[3];
  }

  Widget _temperatura(IconData icone, num? valor, String rotulo, num limite) {
    final alto = valor != null && valor > limite;
    return Expanded(
      child: Column(
        children: [
          Icon(icone, color: alto ? vermelho : azul),
          Text('${numero(valor)} °C', style: TextStyle(fontWeight: FontWeight.bold, color: alto ? vermelho : textoEscuro)),
          Text(rotulo, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: cinza)),
        ],
      ),
    );
  }

  List<Widget> _conteudo() {
    if (carregando) return [const Carregando()];
    if (erro != null && _telemetria == null) return [Mensagem(erro!, erro: true)];
    final t = _telemetria!;
    final alertas = (_alertas?['tabelaAlertas'] as List?) ?? [];
    return [
      if (erro != null) Mensagem(erro!, erro: true),
      const Secao('Visão geral'),
      if (t['disponivel'] != true)
        const Mensagem('Veículo não conectado. Conecte pelo Bluetooth para receber as leituras.', icone: Icons.bluetooth_disabled)
      else ...[
        Cartao(
          titulo: 'Condições do motor',
          aoTocar: () => Navigator.pushNamed(context, '/condicoes'),
          child: Row(children: [
            _temperatura(Icons.water_drop_outlined, t['tempLiquido'], 'Líquido de arrefecimento', 105),
            _temperatura(Icons.oil_barrel_outlined, t['tempOleo'], 'Óleo', 120),
            _temperatura(Icons.air, t['tempAr'], 'Ar de admissão', 45),
          ]),
        ),
        Row(
          children: [
            Expanded(
              child: Cartao(
                titulo: 'Velocidade',
                child: Column(children: [
                  const Icon(Icons.speed, color: cinza, size: 32),
                  Text('${numero(t['velocidadeKmh'])} km/h', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                ]),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Cartao(
                titulo: 'RPM',
                aoTocar: () => Navigator.pushNamed(context, '/rpm'),
                child: Column(children: [
                  Icon(Icons.rotate_right, color: (t['rpm'] ?? 0) > 4000 ? vermelho : cinza, size: 32),
                  Text(numero(t['rpm']), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                ]),
              ),
            ),
          ],
        ),
        Cartao(
          titulo: 'Bateria',
          child: Row(children: [
            Icon(Icons.battery_charging_full,
                color: (t['tensaoBateriaV'] ?? 13) < 12 || (t['tensaoBateriaV'] ?? 13) > 15 ? vermelho : verde),
            const SizedBox(width: 8),
            Text('${numero(t['tensaoBateriaV'], casas: 1)} V', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Spacer(),
            Text('atualizado ${tempoRelativo(t['dataHora'])}', style: const TextStyle(fontSize: 12, color: cinza)),
          ]),
        ),
      ],
      Cartao(
        titulo: 'Alertas nas últimas 24 horas (${_alertas?['total'] ?? 0})',
        aoTocar: () => Navigator.pushNamedAndRemoveUntil(context, '/alertas', (_) => false),
        child: alertas.isEmpty
            ? const Text('Nenhum alerta no período.', style: TextStyle(color: cinza))
            : Column(
                children: [
                  for (final alerta in alertas)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(radius: 5, backgroundColor: corDaOrigem(alerta['origem'])),
                      title: Text(alerta['titulo']),
                      subtitle: Text('${tempoRelativo(alerta['dataHora'])} · ${nomeDaOrigem(alerta['origem'])}'),
                    ),
                ],
              ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final nome = (_usuario?['nome'] as String?)?.split(' ').first ?? '';
    return Pagina(
      indice: 0,
      cabecalho: Cabecalho(
        titulo: '${saudacao()}${nome.isEmpty ? '' : ', $nome'}',
        subtitulo: _veiculo == null ? null : '${_veiculo!['marca']} ${_veiculo!['modelo']} · ${_veiculo!['placa']}',
        voltar: false,
        extra: const StatusObd(),
      ),
      filhos: _conteudo(),
    );
  }
}
