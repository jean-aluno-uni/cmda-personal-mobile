import 'package:flutter/material.dart';

import '../api.dart';
import '../obd.dart';
import '../widgets.dart';

String saudacao() {
  final hora = DateTime.now().hour;
  if (hora < 12) return 'Bom dia';
  if (hora < 18) return 'Boa tarde';
  return 'Boa noite';
}

class HomeTela extends StatefulWidget {
  const HomeTela({super.key});

  @override
  State<HomeTela> createState() => _HomeTelaState();
}

class _HomeTelaState extends State<HomeTela> with AtualizacaoPeriodica {
  Map? _usuario;
  Map? _veiculo;
  Map? _telemetria;
  Map? _alertas;
  bool _alterando = false;

  @override
  Future<void> buscar() async {
    final id = Sessao.veiculoId;
    final respostas = await Future.wait([
      apiCall('/users/me'),
      apiCall('/vehicles/$id'),
      apiCall('/vehicles/$id/telemetry/latest'),
      apiCall('/vehicles/$id/alerts/summary?period=24h'),
    ]);
    _usuario = respostas[0];
    _veiculo = respostas[1];
    _telemetria = respostas[2];
    _alertas = respostas[3];
  }

  Future<void> _alternarConexao(bool conectado) async {
    if (!conectado) {
      Navigator.pushNamed(context, '/conexao');
      return;
    }
    setState(() => _alterando = true);
    await Obd.instancia.desconectar();
    await carregar();
    if (mounted) setState(() => _alterando = false);
  }

  Widget _hero() {
    final conectado = _veiculo?['conectado'] == true;
    return SizedBox(
      height: 210,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: Colors.white),
          Image.asset(conectado ? 'assets/img/carro.png' : 'assets/img/carro-desativado.png', fit: BoxFit.cover),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0x8C000000), Colors.transparent], begin: Alignment.bottomCenter, end: Alignment.topCenter),
              ),
              child: Center(
                child: FilledButton.icon(
                  onPressed: _veiculo == null || _alterando ? null : () => _alternarConexao(conectado),
                  style: FilledButton.styleFrom(
                    backgroundColor: conectado ? const Color(0xBFC2182B) : const Color(0x1FFFFFFF),
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0x66FFFFFF), width: 1.5),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    textStyle: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  icon: const Icon(Icons.bluetooth, size: 18),
                  label: Text(_alterando ? 'Desconectando...' : conectado ? 'Desconectar' : 'Conectar ao veículo'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _temperatura(IconData icone, Color cor, num? valor, String rotulo, num limite) {
    final alto = valor != null && valor > limite;
    return Expanded(
      child: Column(
        children: [
          Icon(icone, color: valor == null ? const Color(0xFFD1D5DB) : (alto ? vermelho : cor), size: 22),
          const SizedBox(height: 4),
          Text('${grau(valor)}${alto ? ' ⚠' : ''}',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: valor == null ? cinzaClaro : (alto ? vermelho : textoEscuro))),
          Text(rotulo, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: cinza)),
        ],
      ),
    );
  }

  String _semDados() => _telemetria?['motivo'] == 'sem_leituras' ? 'Nenhuma leitura recebida' : 'Veículo não conectado';

  @override
  Widget build(BuildContext context) {
    final t = (_telemetria?['disponivel'] == true) ? _telemetria : null;
    final nome = (_usuario?['nome'] as String?) ?? '';
    final alertas = ((_alertas?['tabelaAlertas'] as List?) ?? []).take(3).toList();
    final restantes = ((_alertas?['total'] ?? 0) as int) - alertas.length;
    final rpm = t?['rpm'] as num?;
    final rpmForaDaFaixa = rpm != null && (rpm < rpmMinimo || rpm > rpmMaximo);

    return Pagina(
      ativo: '/home',
      cabecalho: Cabecalho(titulo: '${saudacao()}${nome.isEmpty ? '' : ', $nome'}'),
      topo: _hero(),
      filhos: [
        if (erro != null) Aviso(erro!, erro: true),
        const Secao('Overview'),
        Cartao(
          aoTocar: () => Navigator.pushNamed(context, '/condicoes'),
          child: Column(children: [
            const TituloCartao('Condições do motor', subtitulo: 'Temperaturas', seta: true),
            const SizedBox(height: 14),
            Row(children: [
              _temperatura(Icons.water_drop_outlined, azul, t?['tempLiquido'], 'Líquido de arrefecimento', limiteLiquido),
              _temperatura(Icons.opacity, amarelo, t?['tempOleo'], 'Óleo', limiteOleo),
              _temperatura(Icons.air, cinzaClaro, t?['tempAr'], 'Ar de admissão', limiteAr),
            ]),
          ]),
        ),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Cartao(
                  child: Column(children: [
                    const TituloCartao('Velocidade'),
                    const SizedBox(height: 18),
                    const Icon(Icons.speed, color: cinza, size: 30),
                    const SizedBox(height: 6),
                    if (t != null && t['velocidadeKmh'] != null)
                      Text.rich(TextSpan(children: [
                        TextSpan(text: '${(t['velocidadeKmh'] as num).round()} ', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                        const TextSpan(text: 'km/h', style: TextStyle(fontSize: 13, color: cinza)),
                      ]))
                    else ...[
                      const Text('—', style: TextStyle(fontSize: 26, color: cinzaClaro)),
                      if (!carregando) Text(_semDados(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: cinza)),
                    ],
                  ]),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Cartao(
                  aoTocar: () => Navigator.pushNamed(context, '/alertas'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const TituloCartao('Alertas', seta: true),
                      const SizedBox(height: 8),
                      if (alertas.isEmpty && !carregando) const Text('Nenhum alerta nas últimas 24h', style: TextStyle(fontSize: 12, color: cinza)),
                      for (final a in alertas)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(padding: const EdgeInsets.only(top: 4), child: CircleAvatar(radius: 4.5, backgroundColor: corDoNivel(a['nivel']))),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(a['titulo'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textoEscuro)),
                                  Text('${tempoRelativo(a['dataHora'])} · ${nomeDaOrigem(a['origem'])}', style: const TextStyle(fontSize: 11, color: cinza)),
                                ]),
                              ),
                            ],
                          ),
                        ),
                      if (restantes > 0) Text('+$restantes ${restantes == 1 ? 'alerta' : 'alertas'}', style: const TextStyle(fontSize: 12, color: cinza)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Cartao(
          aoTocar: () => Navigator.pushNamed(context, '/rpm'),
          child: Column(children: [
            const TituloCartao('RPM', seta: true),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.av_timer, color: vermelho, size: 28),
                const SizedBox(width: 8),
                Text(rpm == null ? '—' : milhar(rpm), style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: rpm == null ? cinzaClaro : textoEscuro)),
                if (rpmForaDaFaixa) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.warning_rounded, color: vermelho, size: 18)),
              ],
            ),
          ]),
        ),
      ],
    );
  }
}
