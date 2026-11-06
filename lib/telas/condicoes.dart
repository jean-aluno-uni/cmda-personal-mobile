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
  List? _itens;
  String? _erroDiagnostico;

  @override
  Future<void> buscar() async {
    final id = Sessao.veiculoId;
    final respostas = await Future.wait([
      apiCall('/vehicles/$id/telemetry/latest'),
      apiCall('/vehicles/$id/temperature/history?range=24h'),
    ]);
    _telemetria = respostas[0];
    _historico = respostas[1];
    try {
      final diagnostico = await apiCall('/vehicles/$id/diagnostics');
      _itens = (diagnostico['itens'] as List).where((item) => (item['indicador'] as String).toLowerCase().contains('temp')).toList();
      _erroDiagnostico = null;
    } on ApiErro catch (e) {
      if (e.status != 404) rethrow;
      _itens = [];
      _erroDiagnostico = e.mensagem;
    }
  }

  Widget _cartaoTemperatura(IconData icone, Color cor, num? valor, String rotulo, num limite) {
    final alto = valor != null && valor > limite;
    return Expanded(
      child: Cartao(
        child: Row(children: [
          Icon(icone, size: 28, color: valor == null ? const Color(0xFFD1D5DB) : (alto ? vermelho : cor)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${grau(valor)}${alto ? ' ⚠' : ''}',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: valor == null ? cinzaClaro : (alto ? vermelho : textoEscuro))),
              Text(rotulo, style: const TextStyle(fontSize: 11, color: cinza)),
            ]),
          ),
        ]),
      ),
    );
  }

  List<double> _serie(String chave) {
    final valores = <double>[];
    for (final ponto in _historico) {
      final valor = ponto[chave] as num?;
      valores.add(valor?.toDouble() ?? (valores.isEmpty ? 0 : valores.last));
    }
    return valores;
  }

  List<String> _rotulos() {
    final passo = (_historico.length / 6).ceil();
    return [
      for (var i = 0; i < _historico.length; i++)
        if (i % passo == 0)
          () {
            final d = dataDaApi(_historico[i]['dataHora']);
            return '${doisDigitos(d.hour)}:${doisDigitos(d.minute)}';
          }()
        else
          '',
    ];
  }

  @override
  Widget build(BuildContext context) {
    final t = (_telemetria?['disponivel'] == true) ? _telemetria : null;
    return Pagina(
      cabecalho: const Cabecalho(titulo: 'Condições do motor', voltar: true),
      filhos: [
        if (erro != null) Aviso(erro!, erro: true),
        const Secao('Temperaturas atuais'),
        Row(children: [
          _cartaoTemperatura(Icons.opacity, amarelo, t?['tempOleo'], 'Óleo', limiteOleo),
          const SizedBox(width: 12),
          _cartaoTemperatura(Icons.water_drop_outlined, azul, t?['tempLiquido'], 'Líquido', limiteLiquido),
        ]),
        Row(children: [
          _cartaoTemperatura(Icons.air, cinzaClaro, t?['tempAr'], 'Ar de admissão', limiteAr),
          const SizedBox(width: 12),
          _cartaoTemperatura(Icons.thermostat, verde, t?['tempGeral'], 'Geral', 110),
        ]),
        const Secao('Histórico de temperatura'),
        Cartao(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
          child: _historico.length < 2
              ? Aviso(carregando ? 'Carregando...' : 'Ainda não há leituras suficientes para o histórico')
              : Column(children: [
                  GraficoLinhas(
                    rotulos: _rotulos(),
                    series: [(_serie('oleo'), vermelho), (_serie('liquido'), azul), (_serie('ar'), cinzaClaro), (_serie('geral'), verde)],
                  ),
                  const SizedBox(height: 12),
                  const Wrap(spacing: 14, runSpacing: 6, alignment: WrapAlignment.center, children: [
                    Legenda('Óleo', vermelho),
                    Legenda('Líquido', azul),
                    Legenda('Ar de adm.', cinzaClaro),
                    Legenda('Geral', verde),
                  ]),
                ]),
        ),
        const Secao('Diagnóstico'),
        Tabela(
          colunas: const ['Indicador', 'Valor', 'Referência', 'Status'],
          pesos: const [5, 3, 4, 4],
          vazio: _itens == null ? 'Carregando...' : (_erroDiagnostico ?? 'Sem itens de temperatura no diagnóstico'),
          linhas: [
            for (final d in _itens ?? [])
              [
                celula(d['indicador']),
                celula(d['valor'], cor: d['alerta'] ? vermelho : textoEscuro, negrito: d['alerta'], tamanho: 12),
                celula(d['referencia'] ?? '—', cor: cinza, tamanho: 11),
                celula(d['observacao'] ?? '—', cor: d['alerta'] ? vermelho : cinza, tamanho: 12),
              ],
          ],
        ),
      ],
    );
  }
}
