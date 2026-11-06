import 'package:flutter/material.dart';

import '../api.dart';
import '../widgets.dart';

class DiagnosticoTela extends StatefulWidget {
  const DiagnosticoTela({super.key});

  @override
  State<DiagnosticoTela> createState() => _DiagnosticoTelaState();
}

class _DiagnosticoTelaState extends State<DiagnosticoTela> with AtualizacaoPeriodica {
  Map? _diagnostico;
  Map? _telemetria;
  String? _erroDiagnostico;

  @override
  Future<void> buscar() async {
    final id = Sessao.veiculoId;
    _telemetria = await apiCall('/vehicles/$id/telemetry/latest');
    try {
      _diagnostico = await apiCall('/vehicles/$id/diagnostics');
      _erroDiagnostico = null;
    } on ApiErro catch (e) {
      if (e.status != 404) rethrow;
      _diagnostico = null;
      _erroDiagnostico = e.mensagem;
    }
  }

  Widget _indicador(String rotulo, num? valor, num maximo, String referencia, String Function(num) formato, Color cor) {
    final fracao = valor == null ? 0.0 : (valor / maximo).clamp(0, 1).toDouble();
    return Cartao(
      margem: 0,
      child: Column(children: [
        Anel(
          segmentos: [(fracao, valor == null ? borda : cor)],
          centro: Text('${(fracao * 100).round()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 6),
        Text(rotulo, style: const TextStyle(fontSize: 12, color: cinza)),
        Text(valor == null ? '—' : formato(valor), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        Text('ref: $referencia', style: const TextStyle(fontSize: 10, color: cinza)),
      ]),
    );
  }

  List<Widget> _indicadores() {
    final t = _telemetria;
    if (t == null) return [Cartao(child: Aviso(carregando ? 'Carregando...' : (erro ?? '')))];
    if (t['disponivel'] != true) {
      return [Cartao(child: Aviso(t['motivo'] == 'sem_leituras' ? 'Nenhuma leitura recebida do veículo' : 'Veículo não conectado'))];
    }
    Color limite(num? v, num max) => v != null && v > max ? vermelho : verde;
    final aneis = [
      _indicador('RPM', t['rpm'], rpmMaximo, '750–3.000', milhar, vermelho),
      _indicador('Velocidade', t['velocidadeKmh'], 200, '0–200 km/h', (v) => '${v.round()} km/h', azul),
      _indicador('Temp. Óleo', t['tempOleo'], limiteOleo, 'até $limiteOleo °C', (v) => '${v.round()} °C', limite(t['tempOleo'], limiteOleo)),
      _indicador('Temp. Líq.', t['tempLiquido'], limiteLiquido, 'até $limiteLiquido °C', (v) => '${v.round()} °C', limite(t['tempLiquido'], limiteLiquido)),
    ];
    return [
      Row(children: [Expanded(child: aneis[0]), const SizedBox(width: 12), Expanded(child: aneis[1])]),
      const SizedBox(height: 12),
      Row(children: [Expanded(child: aneis[2]), const SizedBox(width: 12), Expanded(child: aneis[3])]),
      const SizedBox(height: 12),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final d = _diagnostico;
    final itens = (d?['itens'] as List?) ?? [];
    final atencao = d?['statusGeral'] == true;

    return Pagina(
      ativo: '/diagnostico',
      cabecalho: const Cabecalho(titulo: 'Diagnóstico'),
      filhos: [
        const Secao('Status geral'),
        Cartao(
          child: d == null
              ? Aviso(carregando ? 'Carregando...' : (_erroDiagnostico ?? erro ?? ''), erro: erro != null)
              : Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Diagnóstico do veículo', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        atencao ? 'Há indicadores fora da faixa normal. Verifique os detalhes abaixo.' : 'Todos os indicadores dentro dos parâmetros normais.',
                        style: const TextStyle(fontSize: 13, color: cinza),
                      ),
                      const SizedBox(height: 4),
                      Text('Realizado em ${formatarDataHora(d['dataHora'])}', style: const TextStyle(fontSize: 11, color: cinza)),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  Selo(atencao ? 'Atenção' : 'Normal', atencao ? TipoSelo.medio : TipoSelo.ok),
                ]),
        ),
        const Secao('Indicadores'),
        ..._indicadores(),
        const Secao('Detalhes'),
        Tabela(
          colunas: const ['Indicador', 'Valor', 'Referência', 'Status'],
          pesos: const [5, 3, 4, 4],
          vazio: d == null ? 'Sem dados de diagnóstico' : 'Sem itens',
          linhas: [
            for (final item in itens)
              [
                celula(item['indicador']),
                celula(item['valor'], cor: item['alerta'] ? vermelho : textoEscuro, negrito: item['alerta'], tamanho: 12),
                celula(item['referencia'] ?? '—', cor: cinza, tamanho: 11),
                celula(item['observacao'] ?? '—', cor: item['alerta'] ? vermelho : cinza, tamanho: 12),
              ],
          ],
        ),
      ],
    );
  }
}
