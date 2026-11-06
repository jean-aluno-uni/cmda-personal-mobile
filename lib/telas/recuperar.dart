import 'package:flutter/material.dart';

import '../api.dart';
import '../widgets.dart';
import 'login.dart';

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
      final mensagem = await Navigator.push(context, MaterialPageRoute(builder: (_) => OtpTela(email: _email.text.trim())));
      if (mensagem != null && mounted) Navigator.pop(context, mensagem);
    } on ApiErro catch (e) {
      setState(() => _erro = e.mensagem);
    }
    if (mounted) setState(() => _enviando = false);
  }

  @override
  Widget build(BuildContext context) {
    return Pagina(
      cabecalho: const Cabecalho(titulo: 'Recuperar senha', subtitulo: 'Informe o e-mail cadastrado para receber o código'),
      filhos: [
        TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: campo('E-mail', dica: 'seu@email.com')),
        const SizedBox(height: 14),
        if (_erro != null) Mensagem(_erro!, erro: true),
        FilledButton(style: botaoPrincipal(), onPressed: _enviando ? null : _enviar, child: const Text('Enviar código')),
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
      final resposta = await apiCall('/auth/password/otp/verify',
          metodo: 'POST', corpo: {'email': widget.email, 'codigo': _codigo.text.trim()});
      if (!mounted) return;
      final mensagem = await Navigator.push(
          context, MaterialPageRoute(builder: (_) => NovaSenhaTela(resetToken: resposta['resetToken'])));
      if (mensagem != null && mounted) Navigator.pop(context, mensagem);
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
    return Pagina(
      cabecalho: Cabecalho(titulo: 'Código de verificação', subtitulo: 'Digite o código de 6 dígitos enviado para ${widget.email}'),
      filhos: [
        TextField(
          controller: _codigo,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 28, letterSpacing: 12),
          decoration: campo('Código'),
        ),
        if (_erro != null) Mensagem(_erro!, erro: true),
        if (_info != null) Mensagem(_info!),
        FilledButton(style: botaoPrincipal(), onPressed: _enviando ? null : _verificar, child: const Text('Verificar')),
        Center(child: TextButton(onPressed: _reenviar, child: const Text('Reenviar código', style: TextStyle(color: vermelho)))),
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
    return Pagina(
      cabecalho: const Cabecalho(titulo: 'Nova senha', subtitulo: 'Crie uma senha segura para a sua conta'),
      filhos: [
        TextField(controller: _senha, obscureText: true, onChanged: (_) => setState(() {}), decoration: campo('Nova senha')),
        const SizedBox(height: 14),
        TextField(controller: _confirmacao, obscureText: true, decoration: campo('Confirmar senha')),
        const SizedBox(height: 14),
        for (final (texto, regra) in _regras)
          Row(
            children: [
              Icon(regra.hasMatch(_senha.text) ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 18, color: regra.hasMatch(_senha.text) ? verde : cinza),
              const SizedBox(width: 8),
              Text(texto, style: const TextStyle(color: cinza)),
            ],
          ),
        const SizedBox(height: 14),
        if (_erro != null) Mensagem(_erro!, erro: true),
        FilledButton(style: botaoPrincipal(), onPressed: _enviando ? null : _salvar, child: const Text('Salvar nova senha')),
      ],
    );
  }
}
