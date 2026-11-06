import 'package:flutter/material.dart';

import '../api.dart';
import '../widgets.dart';

class AlertasTela extends StatefulWidget {
  const AlertasTela({super.key});

  @override
  State<AlertasTela> createState() => _AlertasTelaState();
}

class _AlertasTelaState extends State<AlertasTela> with AtualizacaoPeriodica {
  static const periodos = {'24h': '24h', '7d': '7 dias', '30d': '30 dias'};

  String _periodo = '24h';
  int _quantidade = 20;
  Map? _resumo;
  Map? _lista;

  @override
  Future<void> buscar() async {
    final id = Sessao.veiculoId;
    _resumo = await apiCall('/vehicles/$id/alerts/summary?period=$_periodo');
    _lista = await apiCall('/vehicles/$id/alerts?period=$_periodo&page=1&pageSize=$_quantidade');
  }

  void _trocarPeriodo(String periodo) {
    setState(() {
      _periodo = periodo;
      _quantidade = 20;
      carregando = true;
    });
    carregar();
  }

  @override
  Widget build(BuildContext context) {
    final origens = (_resumo?['origemAlertas'] as List?) ?? [];
    final itens = (_lista?['items'] as List?) ?? [];
    final total = (_resumo?['total'] ?? 0) as int;
    return Pagina(
      indice: 1,
      cabecalho: const Cabecalho(titulo: 'Alertas', subtitulo: 'Ocorrências registradas no veículo', voltar: false),
      filhos: [
        Wrap(spacing: 8, children: [
          for (final entrada in periodos.entries)
            ChoiceChip(
              label: Text(entrada.value),
              selected: _periodo == entrada.key,
              selectedColor: vermelho.withValues(alpha: 0.15),
              onSelected: (_) => _trocarPeriodo(entrada.key),
            ),
        ]),
        const SizedBox(height: 12),
        if (carregando) const Carregando(),
        if (erro != null) Mensagem(erro!, erro: true),
        if (!carregando && _resumo != null) ...[
          Cartao(
            titulo: 'Origem dos alertas',
            child: total == 0
                ? const Text('Nenhum alerta no período. O veículo está sem ocorrências.', style: TextStyle(color: cinza))
                : Column(children: [
                    Anel(
                      tamanho: 150,
                      espessura: 20,
                      segmentos: [for (final o in origens) ((o['percentual'] as num) / 100, corDaOrigem(o['local']))],
                      centro: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text('$total', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                        const Text('alertas', style: TextStyle(color: cinza)),
                      ]),
                    ),
                    const SizedBox(height: 12),
                    Wrap(spacing: 14, children: [
                      for (final o in origens) Legenda('${nomeDaOrigem(o['local'])} ${numero(o['percentual'], casas: 1)}%', corDaOrigem(o['local'])),
                    ]),
                  ]),
          ),
          if (itens.isNotEmpty)
            Cartao(
              titulo: 'Todos os alertas',
              child: Column(children: [
                for (final alerta in itens)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.warning_amber, color: corDoNivel(alerta['nivel'])),
                    title: Text(alerta['titulo']),
                    subtitle: Text('${alerta['descricao'] ?? ''}\n${tempoRelativo(alerta['dataHora'])} · ${nomeDaOrigem(alerta['origem'])}'),
                    isThreeLine: true,
                  ),
                if (itens.length < (_lista?['total'] ?? 0))
                  TextButton(
                    onPressed: () {
                      setState(() => _quantidade += 20);
                      carregar();
                    },
                    child: const Text('Carregar mais', style: TextStyle(color: vermelho)),
                  ),
              ]),
            ),
        ],
      ],
    );
  }
}
