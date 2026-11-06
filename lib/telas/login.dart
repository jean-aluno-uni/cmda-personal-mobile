import 'package:flutter/material.dart';

import '../api.dart';
import '../widgets.dart';

InputDecoration campo(String rotulo, {String? dica, Widget? sufixo}) => InputDecoration(
      labelText: rotulo,
      hintText: dica,
      suffixIcon: sufixo,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );

ButtonStyle botaoPrincipal() => FilledButton.styleFrom(
      backgroundColor: vermelho,
      minimumSize: const Size.fromHeight(50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );

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
    return Pagina(
      cabecalho: const Cabecalho(
        titulo: 'Bem-vindo de volta',
        subtitulo: 'Entre com suas credenciais para acessar o sistema',
        voltar: false,
        icone: Icons.directions_car,
      ),
      filhos: [
        TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: campo('E-mail', dica: 'seu@email.com')),
        const SizedBox(height: 14),
        TextField(
          controller: _senha,
          obscureText: _ocultar,
          decoration: campo('Senha',
              sufixo: IconButton(
                icon: Icon(_ocultar ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _ocultar = !_ocultar),
              )),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(onPressed: _recuperar, child: const Text('Esqueci minha senha', style: TextStyle(color: vermelho))),
        ),
        if (_erro != null) Mensagem(_erro!, erro: true),
        if (_sucesso != null) Mensagem(_sucesso!, icone: Icons.check_circle_outline),
        FilledButton(
          style: botaoPrincipal(),
          onPressed: _enviando ? null : _entrar,
          child: Text(_enviando ? 'Entrando...' : 'Entrar'),
        ),
        const SizedBox(height: 20),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Servidor da API', style: TextStyle(color: cinza)),
          children: [
            TextField(controller: _servidor, keyboardType: TextInputType.url, decoration: campo('Endereço', dica: Sessao.padraoServidor)),
            const SizedBox(height: 8),
            const Text('Use o IP do notebook onde a API está rodando.', style: TextStyle(color: cinza, fontSize: 12)),
          ],
        ),
      ],
    );
  }
}
