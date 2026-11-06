import 'package:flutter/material.dart';

import '../api.dart';
import '../widgets.dart';

class Campo extends StatelessWidget {
  const Campo({super.key, required this.rotulo, required this.controle, this.dica, this.senha = false, this.teclado, this.sufixo, this.aoMudar});

  final String rotulo;
  final TextEditingController controle;
  final String? dica;
  final bool senha;
  final TextInputType? teclado;
  final Widget? sufixo;
  final ValueChanged<String>? aoMudar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(rotulo, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textoEscuro)),
          const SizedBox(height: 6),
          TextField(
            controller: controle,
            obscureText: senha,
            keyboardType: teclado,
            onChanged: aoMudar,
            decoration: InputDecoration(
              hintText: dica,
              hintStyle: const TextStyle(color: cinzaClaro),
              suffixIcon: sufixo,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: vermelho, width: 1.5)),
            ),
          ),
        ],
      ),
    );
  }
}

class BotaoPrincipal extends StatelessWidget {
  const BotaoPrincipal({super.key, required this.texto, required this.aoTocar});

  final String texto;
  final VoidCallback? aoTocar;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: aoTocar,
      style: FilledButton.styleFrom(
        backgroundColor: vermelho,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
      ),
      child: Text(texto),
    );
  }
}

class PaginaAuth extends StatelessWidget {
  const PaginaAuth({super.key, required this.titulo, required this.descricao, required this.filhos, this.icone = Icons.person_outline});

  final String titulo;
  final String descricao;
  final IconData icone;
  final List<Widget> filhos;

  @override
  Widget build(BuildContext context) {
    final podeVoltar = Navigator.canPop(context);
    return Scaffold(
      backgroundColor: Colors.white,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [vermelhoEscuro, vermelho], begin: Alignment.topCenter, end: Alignment.bottomCenter),
            ),
            padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 40, 24, 56),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white12,
                    border: Border.all(color: Colors.white54, width: 1.5),
                  ),
                  child: Icon(icone, color: Colors.white, size: 38),
                ),
                const SizedBox(height: 16),
                Text(titulo, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(descricao, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -22),
            child: Container(
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (podeVoltar)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(foregroundColor: cinza, padding: EdgeInsets.zero),
                        icon: const Icon(Icons.chevron_left, size: 18),
                        label: const Text('Voltar'),
                      ),
                    ),
                  ...filhos,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LoginTela extends StatefulWidget {
  const LoginTela({super.key});

  @override
  State<LoginTela> createState() => _LoginTelaState();
}

class _LoginTelaState extends State<LoginTela> {
  final _servidor = TextEditingController(text: Sessao.servidor);
  final _email = TextEditingController();
  final _senha = TextEditingController();
  bool _ocultar = true;
  bool _enviando = false;
  String? _erro = Sessao.mensagemLogin;
  String? _sucesso;

  @override
  void initState() {
    super.initState();
    Sessao.mensagemLogin = null;
  }

  Future<void> _entrar() async {
    if (_email.text.trim().isEmpty || _senha.text.isEmpty) {
      setState(() => _erro = 'Preencha e-mail e senha.');
      return;
    }
    setState(() {
      _enviando = true;
      _erro = null;
      _sucesso = null;
    });
    Sessao.servidor = _servidor.text;
    try {
      final resposta = await apiCall('/auth/login', metodo: 'POST', corpo: {'email': _email.text.trim(), 'senha': _senha.text});
      Sessao.token = resposta['accessToken'];
      final veiculos = await apiCall('/vehicles') as List;
      if (veiculos.isEmpty) {
        Sessao.limpar();
        throw ApiErro('Nenhum veículo vinculado a esta conta.', 404);
      }
      Sessao.veiculoId = veiculos.first['id'];
      modeloVeiculo.value = veiculos.first['modelo'] ?? '';
      if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
    } on ApiErro catch (e) {
      setState(() => _erro = e.mensagem);
    }
    if (mounted) setState(() => _enviando = false);
  }

  Future<void> _recuperar() async {
    Sessao.servidor = _servidor.text;
    final mensagem = await Navigator.pushNamed(context, '/recuperar');
    if (mensagem is String) setState(() => _sucesso = mensagem);
  }

  @override
  Widget build(BuildContext context) {
    return PaginaAuth(
      titulo: 'Bem-vindo de volta',
      descricao: 'Entre com suas credenciais para acessar o sistema',
      filhos: [
        Campo(rotulo: 'E-mail', controle: _email, dica: 'seu@email.com', teclado: TextInputType.emailAddress),
        Campo(
          rotulo: 'Senha',
          controle: _senha,
          dica: '••••••••••',
          senha: _ocultar,
          sufixo: IconButton(
            icon: Icon(_ocultar ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: cinza),
            onPressed: () => setState(() => _ocultar = !_ocultar),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: GestureDetector(
            onTap: _recuperar,
            child: const Text('Esqueci minha senha',
                style: TextStyle(color: vermelho, fontSize: 13, fontWeight: FontWeight.w600, decoration: TextDecoration.underline, decorationColor: vermelho)),
          ),
        ),
        if (_erro != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_erro!, style: const TextStyle(color: vermelho, fontSize: 13))),
        if (_sucesso != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_sucesso!, style: const TextStyle(color: verde, fontSize: 13))),
        const SizedBox(height: 24),
        BotaoPrincipal(texto: _enviando ? 'Entrando...' : 'Entrar', aoTocar: _enviando ? null : _entrar),
        const SizedBox(height: 28),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Servidor da API', style: TextStyle(color: cinza, fontSize: 13)),
            children: [
              Campo(rotulo: 'Endereço', controle: _servidor, dica: Sessao.padraoServidor, teclado: TextInputType.url),
              const Text('Use o IP do notebook onde a API está rodando.', style: TextStyle(color: cinza, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}
