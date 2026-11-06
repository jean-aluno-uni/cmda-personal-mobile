import 'package:flutter/material.dart';

import '../api.dart';
import '../widgets.dart';

const limitesAnel = {
  'RPM': 4000,
  'Velocidade': 120,
  'Temp. óleo': 120,
  'Temp. líquido arrefecimento': 105,
  'Tensão da bateria': 15,
};

class DiagnosticoTela extends StatefulWidget {
  const DiagnosticoTela({super.key});

  @override
  State<DiagnosticoTela> createState() => _DiagnosticoTelaState();
}

class _DiagnosticoTelaState extends State<DiagnosticoTela> with AtualizacaoPeriodica {
  Map? _diagnostico;
  Map? _telemetria;

  @override
  Future<void> buscar() async {
    final id = Sessao.veiculoId;
    _telemetria = await apiCall('/vehicles/$id/telemetry/latest');
    try {
      _diagnostico = await apiCall('/vehicles/$id/diagnostics');
    } on ApiErro catch (e) {
      if (e.status != 404) rethrow;
      _diagnostico = null;
    }
  }

  Widget _indicador(Map item) {
    final limite = limitesAnel[item['indicador']]!;
    final valor = double.tryParse((item['valor'] as String).split(' ').first.replaceAll(',', '.')) ?? 0;
    final fracao = valor / limite;
    final cor = item['alerta'] ? vermelho : (fracao > 0.8 ? amarelo : verde);
    return Cartao(
      child: Column(children: [
        Anel(
          tamanho: 76,
          espessura: 8,
          segmentos: [(fracao, cor)],
          centro: Text('${(fracao * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 8),
        Text(item['indicador'], textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: cinza)),
        Text(item['valor'], style: const TextStyle(fontWeight: FontWeight.bold)),
        Text('ref. ${item['referencia']}', style: const TextStyle(fontSize: 11, color: cinza)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = _diagnostico;
    final itens = (d?['itens'] as List?) ?? [];
    final anel = itens.where((item) => limitesAnel.containsKey(item['indicador'])).toList();
    final atencao = d?['statusGeral'] == true;
    return Pagina(
      indice: 2,
      cabecalho: const Cabecalho(titulo: 'Diagnóstico', subtitulo: 'Situação geral do veículo', voltar: false),
      filhos: [
        if (carregando) const Carregando(),
        if (erro != null) Mensagem(erro!, erro: true),
        if (_telemetria != null && _telemetria!['disponivel'] != true)
          const Mensagem('Veículo não conectado. O diagnóstico abaixo é o último registrado.', icone: Icons.bluetooth_disabled),
        if (!carregando && d == null && erro == null) const Mensagem('Nenhum diagnóstico registrado para este veículo.'),
        if (d != null) ...[
          const Secao('Status geral'),
          Cartao(
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Diagnóstico do veículo', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(atencao
                      ? 'Há indicadores fora da faixa normal. Verifique os detalhes abaixo.'
                      : 'Todos os indicadores estão dentro da faixa normal.'),
                  Text('Realizado em ${formatarDataHora(d['dataHora'])}', style: const TextStyle(fontSize: 12, color: cinza)),
                ]),
              ),
              Selo(atencao ? 'Atenção' : 'Normal', atencao ? amarelo : verde),
            ]),
          ),
          if (anel.isNotEmpty) ...[
            const Secao('Indicadores'),
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              childAspectRatio: 0.95,
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [for (final item in anel) _indicador(item)],
            ),
          ],
          Cartao(titulo: 'Detalhes', child: TabelaDiagnostico(itens: itens)),
        ],
      ],
    );
  }
}
