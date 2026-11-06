import 'package:flutter/material.dart';

import '../api.dart';
import '../widgets.dart';

class RpmTela extends StatefulWidget {
  const RpmTela({super.key});

  @override
  State<RpmTela> createState() => _RpmTelaState();
}

class _RpmTelaState extends State<RpmTela> with AtualizacaoPeriodica {
  Map? _telemetria;
  List? _itens;
  String? _erroDiagnostico;

  @override
  Future<void> buscar() async {
    final id = Sessao.veiculoId;
    _telemetria = await apiCall('/vehicles/$id/telemetry/latest');
    try {
      final diagnostico = await apiCall('/vehicles/$id/diagnostics?indicadores=RPM,Velocidade');
      _itens = diagnostico['itens'];
      _erroDiagnostico = null;
    } on ApiErro catch (e) {
      if (e.status != 404) rethrow;
      _itens = [];
      _erroDiagnostico = e.mensagem;
    }
  }

  (String, TipoSelo, String) _status(num rpm) {
    if (rpm < rpmMinimo) return ('Baixo', TipoSelo.alto, 'RPM abaixo do mínimo esperado. Verifique o motor.');
    if (rpm < 1500) return ('Ocioso', TipoSelo.medio, 'Motor em marcha lenta.');
    if (rpm <= 2800) return ('Normal', TipoSelo.ok, 'Motor operando dentro da faixa esperada.');
    return ('Alto', TipoSelo.alto, 'RPM elevado. Reduza a aceleração.');
  }

  @override
  Widget build(BuildContext context) {
    final t = _telemetria;
    final rpm = (t?['disponivel'] == true) ? t!['rpm'] as num? : null;
    final semDados = carregando
        ? 'Carregando...'
        : (t?['motivo'] == 'sem_leituras' || t?['disponivel'] == true ? 'Nenhuma leitura recebida do veículo' : 'Veículo não conectado');
    final fracao = rpm == null ? 0.0 : (rpm / rpmMaximo).clamp(0, 1).toDouble();

    return Pagina(
      cabecalho: const Cabecalho(titulo: 'RPM do motor', voltar: true),
      filhos: [
        if (erro != null) Aviso(erro!, erro: true),
        const Secao('RPM atual'),
        Cartao(
          child: rpm == null
              ? Padding(padding: const EdgeInsets.symmetric(vertical: 32), child: Aviso(semDados))
              : Column(children: [
                  Anel(
                    tamanho: 200,
                    espessura: 18,
                    medidor: true,
                    segmentos: [(fracao, vermelho)],
                    centro: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('${(fracao * 100).round()}%', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: vermelho)),
                      Text('${milhar(rpm)} de ${milhar(rpmMaximo)}', style: const TextStyle(fontSize: 13, color: cinza)),
                    ]),
                  ),
                  const Text('* Desempenho esperado', style: TextStyle(fontSize: 11, color: cinza)),
                ]),
        ),
        const Secao('Status'),
        Cartao(
          child: rpm == null
              ? Text(semDados, style: const TextStyle(fontSize: 13, color: cinza))
              : Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Condição atual', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(_status(rpm).$3, style: const TextStyle(fontSize: 13, color: cinza)),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  Selo(_status(rpm).$1, _status(rpm).$2),
                ]),
        ),
        const Secao('Diagnóstico'),
        Tabela(
          colunas: const ['Indicador', 'Valor', 'Observação'],
          pesos: const [4, 4, 5],
          vazio: _itens == null ? 'Carregando...' : (_erroDiagnostico ?? 'Sem itens de RPM no diagnóstico'),
          linhas: [
            for (final d in _itens ?? [])
              [
                celula(d['indicador']),
                celula(d['valor'], cor: d['alerta'] ? vermelho : textoEscuro, negrito: d['alerta']),
                celula(d['observacao'] ?? '—', cor: d['alerta'] ? vermelho : cinza, tamanho: 12),
              ],
          ],
        ),
      ],
    );
  }
}
