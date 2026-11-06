import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'api.dart';

const vermelho = Color(0xFFC2182B);
const vermelhoEscuro = Color(0xFF7A0A14);
const fundo = Color(0xFFF4F5F7);
const textoEscuro = Color(0xFF1C1C1E);
const cinza = Color(0xFF6B7280);
const cinzaClaro = Color(0xFF9CA3AF);
const borda = Color(0xFFE5E7EB);
const verde = Color(0xFF10B981);
const azul = Color(0xFF3B82F6);
const amarelo = Color(0xFFF59E0B);

const limiteOleo = 120;
const limiteLiquido = 105;
const limiteAr = 45;
const rpmMinimo = 750;
const rpmMaximo = 3000;

final alertasCriticos = ValueNotifier<int>(0);
final modeloVeiculo = ValueNotifier<String>('');

Future<void> atualizarCabecalho() async {
  final id = Sessao.veiculoId;
  final respostas = await Future.wait([
    apiCall('/vehicles/$id'),
    apiCall('/vehicles/$id/alerts?period=24h&pageSize=100'),
  ]);
  modeloVeiculo.value = respostas[0]['modelo'] ?? '';
  alertasCriticos.value = (respostas[1]['items'] as List).where((a) => a['nivel'] == 'high').length;
}

DateTime dataDaApi(String texto) => DateTime.parse(texto.endsWith('Z') ? texto : '${texto}Z').toLocal();

String tempoRelativo(String texto) {
  final minutos = DateTime.now().difference(dataDaApi(texto)).inMinutes;
  if (minutos < 1) return 'agora';
  if (minutos < 60) return '$minutos min atrás';
  final horas = minutos ~/ 60;
  if (horas < 24) return '${horas}h atrás';
  final dias = horas ~/ 24;
  return dias == 1 ? '1 dia atrás' : '$dias dias atrás';
}

String doisDigitos(int n) => n.toString().padLeft(2, '0');

String formatarDataHora(String texto) {
  final d = dataDaApi(texto);
  return '${doisDigitos(d.day)}/${doisDigitos(d.month)} ${doisDigitos(d.hour)}:${doisDigitos(d.minute)}';
}

String milhar(num valor) {
  final texto = valor.round().toString();
  return texto.length > 3 ? '${texto.substring(0, texto.length - 3)}.${texto.substring(texto.length - 3)}' : texto;
}

String grau(num? valor) => valor == null ? '— °C' : '${valor.round()} °C';

String nomeDaOrigem(String origem) => origem == 'Transmissao' ? 'Transmissão' : origem;

Color corDoNivel(String nivel) {
  if (nivel == 'high') return vermelho;
  if (nivel == 'medium') return amarelo;
  return cinzaClaro;
}

class Cabecalho extends StatelessWidget {
  const Cabecalho({super.key, required this.titulo, this.voltar = false});

  final String titulo;
  final bool voltar;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [vermelhoEscuro, vermelho], begin: Alignment.topCenter, end: Alignment.bottomCenter),
      ),
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 12, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (voltar)
                InkWell(
                  onTap: () => Navigator.pop(context),
                  customBorder: const CircleBorder(),
                  child: const CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.chevron_left, color: Colors.white),
                  ),
                ),
              const Spacer(),
              InkWell(
                onTap: () => Navigator.pushNamed(context, '/alertas'),
                customBorder: const CircleBorder(),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: ValueListenableBuilder(
                    valueListenable: alertasCriticos,
                    builder: (context, quantidade, _) => Badge(
                      isLabelVisible: quantidade > 0,
                      backgroundColor: Colors.white,
                      textColor: vermelho,
                      label: Text(quantidade > 99 ? '99+' : '$quantidade', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                      child: const Icon(Icons.notifications_none, color: Colors.white, size: 26),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => Navigator.pushNamedAndRemoveUntil(context, '/perfil', (_) => false),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white54),
                  child: const CircleAvatar(radius: 16, backgroundImage: AssetImage('assets/img/foto-perfil.png')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(titulo, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.bold)),
          ValueListenableBuilder(
            valueListenable: modeloVeiculo,
            builder: (context, modelo, _) => modelo.isEmpty
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(modelo, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ),
          ),
        ],
      ),
    );
  }
}

class Cartao extends StatelessWidget {
  const Cartao({super.key, required this.child, this.aoTocar, this.padding = const EdgeInsets.all(16), this.margem = 12});

  final Widget child;
  final VoidCallback? aoTocar;
  final EdgeInsets padding;
  final double margem;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: margem),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x17000000), blurRadius: 14, offset: Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: aoTocar,
          borderRadius: BorderRadius.circular(18),
          child: ClipRRect(borderRadius: BorderRadius.circular(18), child: Padding(padding: padding, child: child)),
        ),
      ),
    );
  }
}

class TituloCartao extends StatelessWidget {
  const TituloCartao(this.texto, {super.key, this.subtitulo, this.seta = false});

  final String texto;
  final String? subtitulo;
  final bool seta;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(texto, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textoEscuro)),
              if (subtitulo != null) Text(subtitulo!, style: const TextStyle(fontSize: 12, color: cinza)),
            ],
          ),
        ),
        if (seta) const Icon(Icons.chevron_right, color: cinzaClaro),
      ],
    );
  }
}

class Secao extends StatelessWidget {
  const Secao(this.texto, {super.key, this.acao});

  final String texto;
  final Widget? acao;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Row(
        children: [
          Expanded(child: Text(texto, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textoEscuro))),
          ?acao,
        ],
      ),
    );
  }
}

enum TipoSelo { ok, medio, alto }

class Selo extends StatelessWidget {
  const Selo(this.texto, this.tipo, {super.key});

  final String texto;
  final TipoSelo tipo;

  @override
  Widget build(BuildContext context) {
    final (fundoSelo, cor) = switch (tipo) {
      TipoSelo.ok => (const Color(0x1F10B981), const Color(0xFF059669)),
      TipoSelo.medio => (const Color(0x1FF59E0B), const Color(0xFFD97706)),
      TipoSelo.alto => (const Color(0x1AC2182B), vermelho),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: fundoSelo, borderRadius: BorderRadius.circular(20)),
      child: Text(texto, style: TextStyle(color: cor, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
}

class Aviso extends StatelessWidget {
  const Aviso(this.texto, {super.key, this.erro = false});

  final String texto;
  final bool erro;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(texto, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: erro ? vermelho : cinza)),
    );
  }
}

class Tabela extends StatelessWidget {
  const Tabela({super.key, required this.colunas, required this.linhas, this.pesos, this.vazio = 'Sem dados'});

  final List<String> colunas;
  final List<List<Widget>> linhas;
  final List<int>? pesos;
  final String vazio;

  Widget _linha(List<Widget> celulas, Color cor) {
    return Container(
      color: cor,
      child: Row(
        children: [
          for (var i = 0; i < celulas.length; i++)
            Expanded(
              flex: pesos?[i] ?? 1,
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11), child: celulas[i]),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Cartao(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _linha([for (final c in colunas) Text(c, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cinza))], fundo),
          const Divider(height: 1, color: borda),
          if (linhas.isEmpty) Aviso(vazio),
          for (var i = 0; i < linhas.length; i++) ...[
            _linha(linhas[i], i.isOdd ? const Color(0xFFFAFAFA) : Colors.white),
            if (i < linhas.length - 1) const Divider(height: 1, color: borda),
          ],
        ],
      ),
    );
  }
}

Widget celula(String texto, {Color cor = textoEscuro, double tamanho = 13, bool negrito = false}) =>
    Text(texto, style: TextStyle(fontSize: tamanho, color: cor, fontWeight: negrito ? FontWeight.w600 : FontWeight.normal));

class _PintorAnel extends CustomPainter {
  _PintorAnel(this.segmentos, this.espessura, this.inicio, this.abertura, this.redondo);

  final List<(double, Color)> segmentos;
  final double espessura;
  final double inicio;
  final double abertura;
  final bool redondo;

  @override
  void paint(Canvas canvas, Size size) {
    final area = Rect.fromLTWH(espessura / 2, espessura / 2, size.width - espessura, size.height - espessura);
    final pincel = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = espessura
      ..strokeCap = redondo ? StrokeCap.round : StrokeCap.butt;
    canvas.drawArc(area, inicio, abertura, false, pincel..color = const Color(0xFFF0F0F0));
    var angulo = inicio;
    for (final (fracao, cor) in segmentos) {
      final varredura = abertura * fracao.clamp(0, 1);
      if (varredura > 0) canvas.drawArc(area, angulo, varredura, false, pincel..color = cor);
      angulo += varredura;
    }
  }

  @override
  bool shouldRepaint(covariant _PintorAnel antigo) => true;
}

class Anel extends StatelessWidget {
  const Anel({
    super.key,
    required this.segmentos,
    required this.centro,
    this.tamanho = 72,
    this.espessura = 8,
    this.medidor = false,
    this.redondo = true,
  });

  final List<(double, Color)> segmentos;
  final Widget centro;
  final double tamanho;
  final double espessura;
  final bool medidor;
  final bool redondo;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: tamanho,
      height: tamanho,
      child: CustomPaint(
        painter: _PintorAnel(segmentos, espessura, medidor ? 3 * pi / 4 : -pi / 2, medidor ? 3 * pi / 2 : 2 * pi, redondo),
        child: Center(child: centro),
      ),
    );
  }
}

class _PintorLinhas extends CustomPainter {
  _PintorLinhas(this.series, this.rotulos);

  final List<(List<double>, Color)> series;
  final List<String> rotulos;

  @override
  void paint(Canvas canvas, Size size) {
    final valores = series.expand((s) => s.$1).toList();
    if (valores.isEmpty) return;
    const esquerda = 30.0;
    const baixo = 20.0;
    final largura = size.width - esquerda - 6;
    final altura = size.height - baixo - 8;
    final minimo = (valores.reduce(min) / 10).floor() * 10 - 5.0;
    final maximo = (valores.reduce(max) / 10).ceil() * 10 + 5.0;
    final estiloEixo = const TextStyle(fontSize: 9, color: cinzaClaro);
    final grade = Paint()..color = borda;

    for (var i = 0; i <= 4; i++) {
      final y = 8 + altura * i / 4;
      canvas.drawLine(Offset(esquerda, y), Offset(esquerda + largura, y), grade);
      final rotulo = TextPainter(
        text: TextSpan(text: '${(maximo - (maximo - minimo) * i / 4).round()}', style: estiloEixo),
        textDirection: TextDirection.ltr,
      )..layout();
      rotulo.paint(canvas, Offset(esquerda - rotulo.width - 4, y - rotulo.height / 2));
    }

    final quantidade = series.first.$1.length;
    double x(int i) => esquerda + (quantidade == 1 ? 0 : largura * i / (quantidade - 1));
    double y(double v) => 8 + altura - altura * (v - minimo) / (maximo - minimo);

    for (var i = 0; i < rotulos.length; i++) {
      if (rotulos[i].isEmpty) continue;
      final rotulo = TextPainter(text: TextSpan(text: rotulos[i], style: estiloEixo), textDirection: TextDirection.ltr)..layout();
      rotulo.paint(canvas, Offset((x(i) - rotulo.width / 2).clamp(0, size.width - rotulo.width), size.height - rotulo.height));
    }

    for (final (pontos, cor) in series) {
      final caminho = Path();
      for (var i = 0; i < pontos.length; i++) {
        i == 0 ? caminho.moveTo(x(i), y(pontos[i])) : caminho.lineTo(x(i), y(pontos[i]));
      }
      canvas.drawPath(
        caminho,
        Paint()
          ..color = cor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PintorLinhas antigo) => true;
}

class GraficoLinhas extends StatelessWidget {
  const GraficoLinhas({super.key, required this.series, required this.rotulos});

  final List<(List<double>, Color)> series;
  final List<String> rotulos;

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: 185, width: double.infinity, child: CustomPaint(painter: _PintorLinhas(series, rotulos)));
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

class BarraInferior extends StatelessWidget {
  const BarraInferior({super.key, required this.ativo});

  final String? ativo;

  static const itens = [
    ('/home', 'Home', Icons.home_outlined),
    ('/diagnostico', 'Diagnóstico', Icons.description_outlined),
    ('/perfil', 'Perfil', Icons.person_outline),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: borda)),
        boxShadow: [BoxShadow(color: Color(0x12000000), blurRadius: 16, offset: Offset(0, -3))],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (final (rota, rotulo, icone) in itens)
                Expanded(
                  child: InkWell(
                    onTap: rota == ativo ? null : () => Navigator.pushNamedAndRemoveUntil(context, rota, (_) => false),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icone, color: rota == ativo ? vermelho : cinzaClaro, size: 22),
                        const SizedBox(height: 3),
                        Text(rotulo,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: rota == ativo ? vermelho : cinzaClaro)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
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
      await Future.wait([buscar(), atualizarCabecalho()]);
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
  const Pagina({super.key, required this.cabecalho, required this.filhos, this.ativo, this.topo});

  final Widget cabecalho;
  final Widget? topo;
  final List<Widget> filhos;
  final String? ativo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fundo,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          cabecalho,
          ?topo,
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: filhos),
          ),
        ],
      ),
      bottomNavigationBar: BarraInferior(ativo: ativo),
    );
  }
}
