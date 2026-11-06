import 'package:flutter/material.dart';

import '../api.dart';
import '../obd.dart';
import '../widgets.dart';

class PerfilTela extends StatefulWidget {
  const PerfilTela({super.key});

  @override
  State<PerfilTela> createState() => _PerfilTelaState();
}

class _PerfilTelaState extends State<PerfilTela> with AtualizacaoPeriodica {
  Map? _usuario;
  Map? _veiculo;
  bool _saindo = false;

  @override
  Future<void> buscar() async {
    final id = Sessao.veiculoId;
    _usuario = await apiCall('/users/me');
    _veiculo = await apiCall('/vehicles/$id');
  }

  Future<void> _sair() async {
    setState(() => _saindo = true);
    await Obd.instancia.desconectar();
    try {
      await apiCall('/auth/logout', metodo: 'POST');
    } on ApiErro catch (_) {}
    Sessao.limpar();
    if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  Widget _linha(String rotulo, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(rotulo, style: const TextStyle(fontSize: 12, color: cinza)),
        Text(valor, style: const TextStyle(fontSize: 15, color: textoEscuro)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = _usuario;
    final v = _veiculo;
    final nome = (u?['nome'] ?? '') as String;
    final iniciais = nome.split(' ').where((p) => p.isNotEmpty).take(2).map((p) => p[0]).join();
    return Pagina(
      indice: 3,
      cabecalho: const Cabecalho(titulo: 'Perfil', subtitulo: 'Sua conta e seu veículo', voltar: false),
      filhos: [
        if (carregando) const Carregando(),
        if (erro != null) Mensagem(erro!, erro: true),
        if (u != null) ...[
          Center(
            child: Column(children: [
              CircleAvatar(radius: 36, backgroundColor: vermelho, child: Text(iniciais, style: const TextStyle(color: Colors.white, fontSize: 24))),
              const SizedBox(height: 8),
              Text(nome, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text(u['email'], style: const TextStyle(color: cinza)),
            ]),
          ),
          const SizedBox(height: 16),
          Cartao(
            titulo: 'Informações da conta',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _linha('Nome', nome),
              _linha('E-mail', u['email']),
              _linha('Servidor da API', Sessao.servidor),
            ]),
          ),
        ],
        if (v != null)
          Cartao(
            titulo: 'Veículo',
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${v['marca']} ${v['modelo']} ${v['ano'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('Placa ${v['placa']} · ${v['combustivel'] ?? ''}', style: const TextStyle(color: cinza)),
                ]),
              ),
              Selo(v['conectado'] ? 'Conectado' : 'Desconectado', v['conectado'] ? verde : cinza),
            ]),
          ),
        ListenableBuilder(
          listenable: Obd.instancia,
          builder: (context, _) => Cartao(
            titulo: 'Adaptador OBD2',
            aoTocar: () => Navigator.pushNamed(context, '/conexao'),
            child: Text(Obd.instancia.conectado ? 'Conectado em ${Obd.instancia.dispositivo}' : 'Nenhum adaptador conectado'),
          ),
        ),
        OutlinedButton(
          onPressed: _saindo ? null : _sair,
          style: OutlinedButton.styleFrom(
            foregroundColor: vermelho,
            side: const BorderSide(color: vermelho),
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(_saindo ? 'Saindo...' : 'Sair da conta'),
        ),
      ],
    );
  }
}
