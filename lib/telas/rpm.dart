import 'package:flutter/material.dart';

import '../api.dart';
import '../widgets.dart';

const rpmMaximo = 4000;

class RpmTela extends StatefulWidget {
  const RpmTela({super.key});

  @override
  State<RpmTela> createState() => _RpmTelaState();
}

class _RpmTelaState extends State<RpmTela> with AtualizacaoPeriodica {
  Map? _telemetria;
  List _itens = [];

  @override
  Future<void> buscar() async {
    final id = Sessao.veiculoId;
    _telemetria = await apiCall('/vehicles/$id/telemetry/latest');
    try {
      final diagnostico = await apiCall('/vehicles/$id/diagnostics?indicadores=RPM,Velocidade');
      _itens = diagnostico['itens'];
    } on ApiErro catch (e) {
      if (e.status != 404) rethrow;
      _itens = [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _telemetria;
    final rpm = (t?['rpm'] ?? 0) as num;
    final fracao = rpm / rpmMaximo;
    final acima = rpm > rpmMaximo;
    final abaixo = rpm > 0 && rpm < 600;
    return Pagina(
      cabecalho: const Cabecalho(titulo: 'RPM do motor', subtitulo: 'Rotação atual e diagnóstico'),
      filhos: [
        if (carregando) const Carregando(),
        if (erro != null) Mensagem(erro!, erro: true),
        if (t != null && t['disponivel'] != true)
          const Mensagem('Veículo não conectado, sem leitura de RPM.', icone: Icons.bluetooth_disabled),
        if (t != null && t['disponivel'] == true) ...[
          Cartao(
            titulo: 'RPM atual',
            child: Center(
              child: Anel(
                tamanho: 190,
                espessura: 18,
                segmentos: [(fracao, acima ? vermelho : vermelho.withValues(alpha: 0.75))],
                centro: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('${(fracao * 100).round()}%', style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: acima ? vermelho : textoEscuro)),
                  Text('${numero(rpm)} de $rpmMaximo', style: const TextStyle(color: cinza)),
                ]),
              ),
            ),
          ),
          Cartao(
            titulo: 'Status',
            child: Row(children: [
              Expanded(
                child: Text(acima
                    ? 'Rotação acima da faixa recomendada. Reduza a aceleração.'
                    : abaixo
                        ? 'Rotação abaixo da faixa, o motor pode estar falhando.'
                        : 'Motor operando dentro da faixa esperada.'),
              ),
              Selo(acima || abaixo ? 'Atenção' : 'Normal', acima || abaixo ? vermelho : verde),
            ]),
          ),
        ],
        if (_itens.isNotEmpty) Cartao(titulo: 'Diagnóstico', child: TabelaDiagnostico(itens: _itens)),
      ],
    );
  }
}
