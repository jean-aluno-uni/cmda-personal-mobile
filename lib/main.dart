import 'package:flutter/material.dart';

import 'api.dart';
import 'telas/alertas.dart';
import 'telas/condicoes.dart';
import 'telas/conexao.dart';
import 'telas/diagnostico.dart';
import 'telas/home.dart';
import 'telas/login.dart';
import 'telas/perfil.dart';
import 'telas/recuperar.dart';
import 'telas/rpm.dart';
import 'widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Sessao.iniciar();
  runApp(const CmdaApp());
}

class CmdaApp extends StatelessWidget {
  const CmdaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CMDA Personal',
      debugShowCheckedModeBanner: false,
      navigatorKey: navegador,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: vermelho, primary: vermelho), scaffoldBackgroundColor: fundo),
      initialRoute: Sessao.token != null && Sessao.veiculoId != null ? '/home' : '/login',
      routes: {
        '/login': (_) => const LoginTela(),
        '/recuperar': (_) => const RecuperarSenhaTela(),
        '/home': (_) => const HomeTela(),
        '/conexao': (_) => const ConexaoTela(),
        '/condicoes': (_) => const CondicoesTela(),
        '/rpm': (_) => const RpmTela(),
        '/alertas': (_) => const AlertasTela(),
        '/diagnostico': (_) => const DiagnosticoTela(),
        '/perfil': (_) => const PerfilTela(),
      },
    );
  }
}
