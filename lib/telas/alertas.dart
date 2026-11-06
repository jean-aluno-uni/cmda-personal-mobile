import 'package:flutter/material.dart';

import '../api.dart';
import '../widgets.dart';

const _periodos = {'24h': '24h', '7d': '7 dias', '30d': '30 dias'};
const _descricaoPeriodo = {'24h': 'nas últimas 24 horas', '7d': 'nos últimos 7 dias', '30d': 'nos últimos 30 dias'};

class AlertasTela extends StatefulWidget {
  const AlertasTela({super.key});

  @override
  State<AlertasTela> createState() => _AlertasTelaState();
}

class _AlertasTelaState extends State<AlertasTela> with AtualizacaoPeriodica {
  String _periodo = '24h';
  Map? _resumo;

  @override
  Future<void> buscar() async {
    _resumo = await apiCall('/vehicles/${Sessao.veiculoId}/alerts/summary?period=$_periodo');
  }

  void _trocarPeriodo(String periodo) {
    setState(() {
      _periodo = periodo;
      _resumo = null;
      carregando = true;
    });
    carregar();
  }

  void _verTodos() {
    final periodo = _periodo;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.82,
        child: FutureBuilder(
          future: apiCall('/vehicles/${Sessao.veiculoId}/alerts?period=$periodo&pageSize=100'),
          builder: (context, resposta) {
            final dados = resposta.data as Map?;
            final itens = (dados?['items'] as List?) ?? [];
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Expanded(child: Text('Todos os alertas', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ]),
                if (dados != null) Text('${dados['total']} alertas ${_descricaoPeriodo[periodo]}', style: const TextStyle(fontSize: 12, color: cinza)),
                if (resposta.hasError) Aviso(resposta.error.toString(), erro: true),
                if (!resposta.hasData && !resposta.hasError) const Aviso('Carregando...'),
                Expanded(
                  child: ListView.separated(
                    itemCount: itens.length,
                    separatorBuilder: (_, _) => const Divider(height: 1, color: borda),
                    itemBuilder: (context, i) {
                      final a = itens[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Padding(padding: const EdgeInsets.only(top: 4), child: CircleAvatar(radius: 4.5, backgroundColor: corDoNivel(a['nivel']))),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(a['titulo'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              if (a['descricao'] != null) Text(a['descricao'], style: const TextStyle(fontSize: 12, color: cinza)),
                              Text('${tempoRelativo(a['dataHora'])} · ${nomeDaOrigem(a['origem'])}', style: const TextStyle(fontSize: 11, color: cinza)),
                            ]),
                          ),
                        ]),
                      );
                    },
                  ),
                ),
              ]),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final origens = (_resumo?['origemAlertas'] as List?) ?? [];
    final tabela = (_resumo?['tabelaAlertas'] as List?) ?? [];
    final total = (_resumo?['total'] ?? 0) as int;

    return Pagina(
      cabecalho: const Cabecalho(titulo: 'Alertas', voltar: true),
      filhos: [
        Row(children: [
          for (final p in _periodos.entries)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(p.value),
                selected: _periodo == p.key,
                showCheckmark: false,
                selectedColor: vermelho,
                backgroundColor: Colors.white,
                side: BorderSide(color: _periodo == p.key ? vermelho : borda, width: 1.5),
                shape: const StadiumBorder(),
                labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: _periodo == p.key ? Colors.white : cinza),
                onSelected: (_) => _trocarPeriodo(p.key),
              ),
            ),
        ]),
        const SizedBox(height: 8),
        const Secao('Origem dos alertas'),
        Cartao(
          child: Column(children: [
            Anel(
              tamanho: 130,
              espessura: 17,
              redondo: false,
              segmentos: total == 0
                  ? [(1.0, borda)]
                  : [for (final o in origens) ((o['percentual'] as num) / 100, Color(int.parse('FF${(o['cor'] as String).substring(1)}', radix: 16)))],
              centro: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_resumo == null ? '…' : '$total', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                const Text('alertas', style: TextStyle(fontSize: 11, color: cinza)),
              ]),
            ),
            const SizedBox(height: 14),
            if (erro != null)
              Text(erro!, style: const TextStyle(fontSize: 12, color: vermelho))
            else if (_resumo == null)
              const Text('Carregando...', style: TextStyle(fontSize: 12, color: cinza))
            else if (total == 0)
              Text('Nenhum alerta ${_descricaoPeriodo[_periodo]}', style: const TextStyle(fontSize: 12, color: cinza))
            else
              Wrap(
                spacing: 20,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (final o in origens)
                    Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: CircleAvatar(radius: 5, backgroundColor: Color(int.parse('FF${(o['cor'] as String).substring(1)}', radix: 16))),
                      ),
                      const SizedBox(width: 6),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(nomeDaOrigem(o['local']), style: const TextStyle(fontSize: 11, color: cinza)),
                        Text('${(o['percentual'] as num).toStringAsFixed(1)}%', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      ]),
                    ]),
                ],
              ),
          ]),
        ),
        Secao(
          'Todos os alertas',
          acao: IconButton(onPressed: _verTodos, icon: const Icon(Icons.open_in_full, size: 18, color: cinza), tooltip: 'Ver todos os alertas'),
        ),
        Tabela(
          colunas: const ['Descrição', 'Tempo', 'Local'],
          pesos: const [6, 3, 3],
          vazio: _resumo == null ? 'Carregando...' : 'Nenhum alerta no período',
          linhas: [
            for (final a in tabela)
              [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(padding: const EdgeInsets.only(top: 4), child: CircleAvatar(radius: 4.5, backgroundColor: corDoNivel(a['nivel']))),
                  const SizedBox(width: 7),
                  Expanded(child: celula(a['titulo'])),
                ]),
                celula(tempoRelativo(a['dataHora']), cor: cinza, tamanho: 12),
                celula(nomeDaOrigem(a['origem']), cor: cinza, tamanho: 12),
              ],
          ],
        ),
      ],
    );
  }
}
