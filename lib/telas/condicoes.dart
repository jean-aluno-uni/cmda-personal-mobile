import 'package:flutter/material.dart';

import '../api.dart';
import '../widgets.dart';

class CondicoesTela extends StatefulWidget {
  const CondicoesTela({super.key});

  @override
  State<CondicoesTela> createState() => _CondicoesTelaState();
}

class _CondicoesTelaState extends State<CondicoesTela> with AtualizacaoPeriodica {
  Map? _telemetria;
  List _historico = [];
  List _itens = [];

  @override
  Future<void> buscar() async {
    final id = Sessao.veiculoId;
    _telemetria = await apiCall('/vehicles/$id/telemetry/latest');
    _historico = await apiCall('/vehicles/$id/temperature/history?range=24h');
    try {
      final diagnostico = await apiCall('/vehicles/$id/diagnostics');
      _itens = (diagnostico['itens'] as List).where((item) => (item['indicador'] as String).startsWith('Temp')).toList();
    } on ApiErro catch (e) {
      if (e.status != 404) rethrow;
      _itens = [];
    }
  }

  Widget _temperatura(IconData icone, num? valor, String rotulo, num limite) {
    final alto = valor != null && valor > limite;
    return Expanded(
      child: Cartao(
        child: Row(children: [
          Icon(icone, color: alto ? vermelho : azul),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('${numero(valor)} °C', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: alto ? vermelho : textoEscuro)),
                if (alto) const Icon(Icons.warning_amber, color: vermelho, size: 18),
              ]),
              Text(rotulo, style: const TextStyle(fontSize: 11, color: cinza)),
            ]),
          ),
        ]),
      ),
    );
  }

  List<double> _serie(String chave) => _historico.map((p) => ((p[chave] ?? 0) as num).toDouble()).toList();

  @override
  Widget build(BuildContext context) {
    final t = _telemetria;
    return Pagina(
      cabecalho: const Cabecalho(titulo: 'Condições do motor', subtitulo: 'Temperaturas e diagnóstico'),
      filhos: [
        if (carregando) const Carregando(),
        if (erro != null) Mensagem(erro!, erro: true),
        if (t != null && t['disponivel'] != true)
          const Mensagem('Veículo não conectado, sem temperaturas atuais.', icone: Icons.bluetooth_disabled),
        if (t != null && t['disponivel'] == true) ...[
          const Secao('Temperaturas atuais'),
          Row(children: [
            _temperatura(Icons.oil_barrel_outlined, t['tempOleo'], 'Óleo', 120),
            const SizedBox(width: 12),
            _temperatura(Icons.water_drop_outlined, t['tempLiquido'], 'Líquido', 105),
          ]),
          Row(children: [
            _temperatura(Icons.air, t['tempAr'], 'Ar de admissão', 45),
            const SizedBox(width: 12),
            _temperatura(Icons.thermostat, t['tempGeral'], 'Geral', 110),
          ]),
        ],
        if (_historico.isNotEmpty)
          Cartao(
            titulo: 'Histórico de temperatura, últimas leituras',
            child: Column(children: [
              GraficoLinhas(series: [
                (_serie('oleo'), vermelho),
                (_serie('liquido'), azul),
                (_serie('ar'), cinza),
                (_serie('geral'), verde),
              ]),
              const SizedBox(height: 10),
              const Wrap(spacing: 12, children: [
                Legenda('Óleo', vermelho),
                Legenda('Líquido', azul),
                Legenda('Ar de admissão', cinza),
                Legenda('Geral', verde),
              ]),
            ]),
          ),
        if (_itens.isNotEmpty) Cartao(titulo: 'Diagnóstico', child: TabelaDiagnostico(itens: _itens)),
      ],
    );
  }
}
