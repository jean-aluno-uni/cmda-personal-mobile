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
    final respostas = await Future.wait([apiCall('/users/me'), apiCall('/vehicles/${Sessao.veiculoId}')]);
    _usuario = respostas[0];
    _veiculo = respostas[1];
  }

  Future<void> _sair() async {
    setState(() => _saindo = true);
    await Obd.instancia.desconectar();
    try {
      await apiCall('/auth/logout', metodo: 'POST');
    } on ApiErro catch (_) {}
    Sessao.limpar();
    modeloVeiculo.value = '';
    alertasCriticos.value = 0;
    if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  Future<void> _alternarConexao() async {
    if (_veiculo?['conectado'] != true) {
      Navigator.pushNamed(context, '/conexao');
      return;
    }
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desconectar veículo'),
        content: Text('Deseja desconectar o veículo ${_veiculo?['modelo'] ?? ''}? Os dados de telemetria não serão mais exibidos.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar', style: TextStyle(color: cinza))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: vermelho),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Desconectar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    await Obd.instancia.desconectar();
    await carregar();
  }

  Widget _campo(String rotulo, String valor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(rotulo, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: fundo, borderRadius: BorderRadius.circular(12), border: Border.all(color: borda)),
          child: Text(valor, style: const TextStyle(color: cinza)),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = _usuario;
    final v = _veiculo;
    final conectado = v?['conectado'] == true;

    return Pagina(
      ativo: '/perfil',
      cabecalho: const Cabecalho(titulo: 'Perfil'),
      filhos: [
        if (erro != null) Aviso(erro!, erro: true),
        Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 12),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(shape: BoxShape.circle, color: vermelho),
                child: const CircleAvatar(radius: 38, backgroundImage: AssetImage('assets/img/foto-perfil.png')),
              ),
              const SizedBox(height: 10),
              Text(u?['nome'] ?? (carregando ? 'Carregando...' : ''), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text(u?['email'] ?? '', style: const TextStyle(color: cinza, fontSize: 13)),
            ]),
          ),
        ),
        const Secao('Informações da conta'),
        Cartao(
          padding: EdgeInsets.zero,
          margem: 8,
          child: Column(children: [
            _campo('Nome', u?['nome'] ?? ''),
            const Divider(height: 1, color: borda),
            _campo('E-mail', u?['email'] ?? ''),
            const Divider(height: 1, color: borda),
            _campo('Senha', '••••••••'),
          ]),
        ),
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/recuperar'),
          child: const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 12),
            child: Text('Alterar senha', style: TextStyle(color: vermelho, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ),
        const Secao('Veículo conectado'),
        Cartao(
          child: v == null
              ? Text(carregando ? 'Carregando...' : '', style: const TextStyle(color: cinza))
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${v['marca']} ${v['modelo']}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        Text('Placa: ${v['placa']}', style: const TextStyle(fontSize: 13, color: cinza)),
                      ]),
                    ),
                    Selo(conectado ? 'Conectado' : 'Desconectado', conectado ? TipoSelo.ok : TipoSelo.alto),
                  ]),
                  ListenableBuilder(
                    listenable: Obd.instancia,
                    builder: (context, _) => Obd.instancia.conectado
                        ? Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text('Adaptador OBD2: ${Obd.instancia.dispositivo}', style: const TextStyle(fontSize: 12, color: cinza)),
                          )
                        : const SizedBox.shrink(),
                  ),
                ]),
        ),
        const Secao('Conta'),
        Cartao(
          child: Column(children: [
            OutlinedButton(
              onPressed: v == null ? null : _alternarConexao,
              style: OutlinedButton.styleFrom(
                foregroundColor: vermelho,
                side: const BorderSide(color: vermelho, width: 2),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(conectado ? 'Desconectar veículo' : 'Conectar veículo'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _saindo ? null : _sair,
              style: FilledButton.styleFrom(
                backgroundColor: vermelho,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(_saindo ? 'Saindo...' : 'Sair'),
            ),
          ]),
        ),
      ],
    );
  }
}
