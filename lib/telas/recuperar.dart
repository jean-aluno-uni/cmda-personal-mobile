import 'package:flutter/material.dart';

import '../api.dart';
import '../widgets.dart';
import 'login.dart';

Widget mensagem(String? texto, {bool erro = true}) => texto == null
    ? const SizedBox.shrink()
    : Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(texto, style: TextStyle(color: erro ? vermelho : verde, fontSize: 13)));

class RecuperarSenhaTela extends StatefulWidget {
  const RecuperarSenhaTela({super.key});

  @override
  State<RecuperarSenhaTela> createState() => _RecuperarSenhaTelaState();
}

class _RecuperarSenhaTelaState extends State<RecuperarSenhaTela> {
  final _email = TextEditingController();
  bool _enviando = false;
  String? _erro;

  Future<void> _enviar() async {
    setState(() {
      _enviando = true;
      _erro = null;
    });
    try {
      await apiCall('/auth/password/forgot', metodo: 'POST', corpo: {'email': _email.text.trim()});
      if (!mounted) return;
      final resultado = await Navigator.push(context, MaterialPageRoute(builder: (_) => OtpTela(email: _email.text.trim())));
      if (resultado != null && mounted) Navigator.pop(context, resultado);
    } on ApiErro catch (e) {
      setState(() => _erro = e.mensagem);
    }
    if (mounted) setState(() => _enviando = false);
  }

  @override
  Widget build(BuildContext context) {
    return PaginaAuth(
      titulo: 'Recuperar senha',
      descricao: 'Informe o e-mail cadastrado para receber o código de verificação',
      icone: Icons.lock_outline,
      filhos: [
        Campo(rotulo: 'E-mail', controle: _email, dica: 'seu@email.com', teclado: TextInputType.emailAddress),
        mensagem(_erro),
        const SizedBox(height: 8),
        BotaoPrincipal(texto: _enviando ? 'Enviando...' : 'Enviar código', aoTocar: _enviando ? null : _enviar),
      ],
    );
  }
}

class OtpTela extends StatefulWidget {
  const OtpTela({super.key, required this.email});

  final String email;

  @override
  State<OtpTela> createState() => _OtpTelaState();
}

class _OtpTelaState extends State<OtpTela> {
  final _codigo = TextEditingController();
  bool _enviando = false;
  String? _erro;
  String? _info;

  Future<void> _verificar() async {
    setState(() {
      _enviando = true;
      _erro = null;
    });
    try {
      final resposta = await apiCall('/auth/password/otp/verify', metodo: 'POST', corpo: {'email': widget.email, 'codigo': _codigo.text.trim()});
      if (!mounted) return;
      final resultado = await Navigator.push(context, MaterialPageRoute(builder: (_) => NovaSenhaTela(resetToken: resposta['resetToken'])));
      if (resultado != null && mounted) Navigator.pop(context, resultado);
    } on ApiErro catch (e) {
      setState(() => _erro = e.mensagem);
    }
    if (mounted) setState(() => _enviando = false);
  }

  Future<void> _reenviar() async {
    try {
      await apiCall('/auth/password/otp/resend', metodo: 'POST', corpo: {'email': widget.email});
      setState(() {
        _info = 'Um novo código foi gerado.';
        _erro = null;
      });
    } on ApiErro catch (e) {
      setState(() => _erro = e.mensagem);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PaginaAuth(
      titulo: 'Verificação',
      descricao: 'Digite o código de 6 dígitos enviado para ${widget.email}',
      icone: Icons.mark_email_read_outlined,
      filhos: [
        TextField(
          controller: _codigo,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 28, letterSpacing: 14, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            counterText: '',
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: vermelho, width: 1.5)),
          ),
        ),
        const SizedBox(height: 16),
        mensagem(_erro),
        mensagem(_info, erro: false),
        BotaoPrincipal(texto: _enviando ? 'Verificando...' : 'Verificar', aoTocar: _enviando ? null : _verificar),
        TextButton(onPressed: _reenviar, child: const Text('Reenviar código', style: TextStyle(color: vermelho))),
      ],
    );
  }
}

class NovaSenhaTela extends StatefulWidget {
  const NovaSenhaTela({super.key, required this.resetToken});

  final String resetToken;

  @override
  State<NovaSenhaTela> createState() => _NovaSenhaTelaState();
}

class _NovaSenhaTelaState extends State<NovaSenhaTela> {
  final _senha = TextEditingController();
  final _confirmacao = TextEditingController();
  bool _enviando = false;
  String? _erro;

  static final _regras = <(String, RegExp)>[
    ('Mínimo de 8 caracteres', RegExp(r'.{8,}')),
    ('Uma letra minúscula', RegExp(r'[a-z]')),
    ('Uma letra maiúscula', RegExp(r'[A-Z]')),
    ('Um número', RegExp(r'[0-9]')),
    ('Um caractere especial', RegExp(r'[!@#$%^&*(),.?":{}|<>]')),
  ];

  Future<void> _salvar() async {
    if (_senha.text != _confirmacao.text) {
      setState(() => _erro = 'As senhas não conferem.');
      return;
    }
    setState(() {
      _enviando = true;
      _erro = null;
    });
    try {
      await apiCall('/auth/password/reset', metodo: 'POST', corpo: {'resetToken': widget.resetToken, 'novaSenha': _senha.text});
      if (mounted) Navigator.pop(context, 'Senha alterada. Entre com a nova senha.');
    } on ApiErro catch (e) {
      setState(() => _erro = e.mensagem);
    }
    if (mounted) setState(() => _enviando = false);
  }

  @override
  Widget build(BuildContext context) {
    return PaginaAuth(
      titulo: 'Nova senha',
      descricao: 'Crie uma senha segura para a sua conta',
      icone: Icons.key_outlined,
      filhos: [
        Campo(rotulo: 'Nova senha', controle: _senha, senha: true, aoMudar: (_) => setState(() {})),
        Campo(rotulo: 'Confirmar senha', controle: _confirmacao, senha: true),
        for (final (texto, regra) in _regras)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(children: [
              Icon(regra.hasMatch(_senha.text) ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 18, color: regra.hasMatch(_senha.text) ? verde : cinzaClaro),
              const SizedBox(width: 8),
              Text(texto, style: const TextStyle(color: cinza, fontSize: 13)),
            ]),
          ),
        const SizedBox(height: 16),
        mensagem(_erro),
        BotaoPrincipal(texto: _enviando ? 'Salvando...' : 'Salvar nova senha', aoTocar: _enviando ? null : _salvar),
      ],
    );
  }
}
