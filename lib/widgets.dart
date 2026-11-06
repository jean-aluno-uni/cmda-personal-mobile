import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'api.dart';

const vermelho = Color(0xFFC2182B);
const vermelhoEscuro = Color(0xFF7A0E1B);
const fundo = Color(0xFFF4F5F7);
const textoEscuro = Color(0xFF1F2937);
const cinza = Color(0xFF6B7280);
const verde = Color(0xFF10B981);
const azul = Color(0xFF3B82F6);
const amarelo = Color(0xFFF59E0B);

Color corDaOrigem(String origem) {
  if (origem == 'Motor') return vermelho;
  if (origem.startsWith('Transmiss')) return azul;
  if (origem == 'Bateria') return verde;
  return Colors.grey;
}

String nomeDaOrigem(String origem) => origem == 'Transmissao' ? 'Transmissão' : origem;

Color corDoNivel(String nivel) {
  if (nivel == 'high') return vermelho;
  if (nivel == 'medium') return amarelo;
  return Colors.grey;
}

DateTime dataDaApi(String texto) => DateTime.parse(texto.endsWith('Z') ? texto : '${texto}Z').toLocal();

String tempoRelativo(String texto) {
  final diferenca = DateTime.now().difference(dataDaApi(texto));
  if (diferenca.inSeconds < 60) return 'agora';
  if (diferenca.inMinutes < 60) return '${diferenca.inMinutes} min atrás';
  if (diferenca.inHours < 24) return '${diferenca.inHours} h atrás';
  return '${diferenca.inDays} dias atrás';
}

String formatarDataHora(String texto) {
  final data = dataDaApi(texto);
  String dois(int n) => n.toString().padLeft(2, '0');
  return '${dois(data.day)}/${dois(data.month)} ${dois(data.hour)}:${dois(data.minute)}:${dois(data.second)}';
}

String numero(num? valor, {int casas = 0}) {
  if (valor == null) return '--';
  return valor.toStringAsFixed(casas).replaceAll('.', ',');
}

class Cabecalho extends StatelessWidget {
  const Cabecalho({super.key, required this.titulo, this.subtitulo, this.voltar = true, this.extra, this.icone});

  final IconData? icone;
  final String titulo;
  final String? subtitulo;
  final bool voltar;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [vermelho, vermelhoEscuro], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 12, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (voltar)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(20),
                child: const CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.arrow_back, color: Colors.white, size: 20),
                ),
              ),
            ),
          if (icone != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Icon(icone, color: Colors.white, size: 40)),
          Text(titulo, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          if (subtitulo != null) Text(subtitulo!, style: const TextStyle(color: Colors.white70)),
          ?extra,
        ],
      ),
    );
  }
}

class Cartao extends StatelessWidget {
  const Cartao({super.key, required this.child, this.titulo, this.aoTocar});

  final Widget child;
  final String? titulo;
  final VoidCallback? aoTocar;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: aoTocar,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (titulo != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(titulo!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textoEscuro)),
                      ),
                      if (aoTocar != null) const Icon(Icons.chevron_right, color: cinza),
                    ],
                  ),
                ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class Selo extends StatelessWidget {
  const Selo(this.texto, this.cor, {super.key});

  final String texto;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: cor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(texto, style: TextStyle(color: cor, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}

class Mensagem extends StatelessWidget {
  const Mensagem(this.texto, {super.key, this.erro = false, this.icone});

  final String texto;
  final bool erro;
  final IconData? icone;

  @override
  Widget build(BuildContext context) {
    return Cartao(
      child: Row(
        children: [
          Icon(icone ?? (erro ? Icons.error_outline : Icons.info_outline), color: erro ? vermelho : cinza),
          const SizedBox(width: 12),
          Expanded(child: Text(texto, style: TextStyle(color: erro ? vermelho : cinza))),
        ],
      ),
    );
  }
}

class Carregando extends StatelessWidget {
  const Carregando({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(32),
      child: Center(child: CircularProgressIndicator(color: vermelho)),
    );
  }
}

class _PintorAneis extends CustomPainter {
  _PintorAneis(this.segmentos, this.espessura);

  final List<(double, Color)> segmentos;
  final double espessura;

  @override
  void paint(Canvas canvas, Size size) {
    final area = Rect.fromLTWH(espessura / 2, espessura / 2, size.width - espessura, size.height - espessura);
    final pincel = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = espessura;
    canvas.drawArc(area, 0, 2 * pi, false, pincel..color = const Color(0xFFE5E7EB));
    var inicio = -pi / 2;
    for (final (fracao, cor) in segmentos) {
      final angulo = 2 * pi * fracao.clamp(0, 1);
      canvas.drawArc(area, inicio, angulo, false, pincel..color = cor);
      inicio += angulo;
    }
  }

  @override
  bool shouldRepaint(covariant _PintorAneis antigo) => true;
}

class Anel extends StatelessWidget {
  const Anel({super.key, required this.segmentos, required this.centro, this.tamanho = 90, this.espessura = 10});

  final List<(double, Color)> segmentos;
  final Widget centro;
  final double tamanho;
  final double espessura;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: tamanho,
      height: tamanho,
      child: CustomPaint(painter: _PintorAneis(segmentos, espessura), child: Center(child: centro)),
    );
  }
}

class _PintorLinhas extends CustomPainter {
  _PintorLinhas(this.series);

  final List<(List<double>, Color)> series;

  @override
  void paint(Canvas canvas, Size size) {
    final valores = series.expand((s) => s.$1).toList();
    if (valores.isEmpty) return;
    final maximo = valores.reduce(max) + 10;
    final grade = Paint()..color = const Color(0xFFE5E7EB);
    for (var i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grade);
    }
    for (final (pontos, cor) in series) {
      if (pontos.length < 2) continue;
      final caminho = Path();
      for (var i = 0; i < pontos.length; i++) {
        final x = size.width * i / (pontos.length - 1);
        final y = size.height - size.height * pontos[i] / maximo;
        i == 0 ? caminho.moveTo(x, y) : caminho.lineTo(x, y);
      }
      canvas.drawPath(caminho, Paint()
        ..color = cor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5);
    }
  }

  @override
  bool shouldRepaint(covariant _PintorLinhas antigo) => true;
}

class GraficoLinhas extends StatelessWidget {
  const GraficoLinhas({super.key, required this.series});

  final List<(List<double>, Color)> series;

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: 160, width: double.infinity, child: CustomPaint(painter: _PintorLinhas(series)));
  }
}

class Legenda extends StatelessWidget {
  const Legenda(this.texto, this.cor, {super.key});

  final String texto;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(radius: 5, backgroundColor: cor),
        const SizedBox(width: 6),
        Text(texto, style: const TextStyle(fontSize: 12, color: cinza)),
      ],
    );
  }
}

class TabelaDiagnostico extends StatelessWidget {
  const TabelaDiagnostico({super.key, required this.itens});

  final List itens;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final item in itens)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['indicador'], style: const TextStyle(fontWeight: FontWeight.w600, color: textoEscuro)),
                      Text('ref. ${item['referencia'] ?? '--'}', style: const TextStyle(fontSize: 12, color: cinza)),
                    ],
                  ),
                ),
                Text(item['valor'], style: const TextStyle(color: textoEscuro)),
                const SizedBox(width: 10),
                Selo(item['observacao'] ?? (item['alerta'] ? 'Atenção' : 'Normal'), item['alerta'] ? vermelho : verde),
              ],
            ),
          ),
      ],
    );
  }
}

class BarraInferior extends StatelessWidget {
  const BarraInferior({super.key, required this.indice});

  final int indice;

  static const rotas = ['/home', '/alertas', '/diagnostico', '/perfil'];

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: indice,
      backgroundColor: Colors.white,
      indicatorColor: vermelho.withValues(alpha: 0.12),
      onDestinationSelected: (i) {
        if (i != indice) Navigator.pushNamedAndRemoveUntil(context, rotas[i], (_) => false);
      },
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home, color: vermelho), label: 'Início'),
        NavigationDestination(icon: Icon(Icons.notifications_outlined), selectedIcon: Icon(Icons.notifications, color: vermelho), label: 'Alertas'),
        NavigationDestination(icon: Icon(Icons.fact_check_outlined), selectedIcon: Icon(Icons.fact_check, color: vermelho), label: 'Diagnóstico'),
        NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person, color: vermelho), label: 'Perfil'),
      ],
    );
  }
}

mixin AtualizacaoPeriodica<T extends StatefulWidget> on State<T> {
  Timer? _timer;
  bool carregando = true;
  String? erro;

  Future<void> buscar();

  Future<void> carregar() async {
    try {
      await buscar();
      erro = null;
    } on ApiErro catch (e) {
      erro = e.mensagem;
    }
    if (mounted) setState(() => carregando = false);
  }

  @override
  void initState() {
    super.initState();
    carregar();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => carregar());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class Pagina extends StatelessWidget {
  const Pagina({super.key, required this.cabecalho, required this.filhos, this.indice});

  final Widget cabecalho;
  final List<Widget> filhos;
  final int? indice;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fundo,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          cabecalho,
          Padding(padding: const EdgeInsets.fromLTRB(16, 18, 16, 24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: filhos)),
        ],
      ),
      bottomNavigationBar: indice == null ? null : BarraInferior(indice: indice!),
    );
  }
}

class Secao extends StatelessWidget {
  const Secao(this.texto, {super.key});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Text(texto, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: textoEscuro)),
    );
  }
}
