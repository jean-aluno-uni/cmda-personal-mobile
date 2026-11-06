import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

final navegador = GlobalKey<NavigatorState>();

class ApiErro implements Exception {
  ApiErro(this.mensagem, this.status);

  final String mensagem;
  final int status;

  @override
  String toString() => mensagem;
}

class Sessao {
  static const padraoServidor = 'http://192.168.0.10:8000/api/v1';

  static late SharedPreferences _prefs;
  static String? mensagemLogin;

  static Future<void> iniciar() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static String get servidor => _prefs.getString('servidor') ?? padraoServidor;
  static set servidor(String valor) => _prefs.setString('servidor', valor.trim().replaceAll(RegExp(r'/+$'), ''));

  static String? get token => _prefs.getString('token');
  static set token(String? valor) => valor == null ? _prefs.remove('token') : _prefs.setString('token', valor);

  static int? get veiculoId => _prefs.getInt('veiculo');
  static set veiculoId(int? valor) => valor == null ? _prefs.remove('veiculo') : _prefs.setInt('veiculo', valor);

  static String? get ultimoDispositivo => _prefs.getString('dispositivo');
  static set ultimoDispositivo(String? valor) =>
      valor == null ? _prefs.remove('dispositivo') : _prefs.setString('dispositivo', valor);

  static void limpar() {
    token = null;
    veiculoId = null;
  }
}

String _mensagemErro(dynamic corpo, int status) {
  if (corpo is Map && corpo['error'] is String) return corpo['error'];
  if (corpo is Map && corpo['detail'] is String) return corpo['detail'];
  if (corpo is Map && corpo['detail'] is List && corpo['detail'].isNotEmpty) {
    return (corpo['detail'] as List)
        .map((d) => (d['msg'] ?? '').toString().replaceFirst('Value error, ', ''))
        .join('; ');
  }
  return 'Erro inesperado ($status)';
}

Future<dynamic> apiCall(String caminho, {String metodo = 'GET', Object? corpo}) async {
  final token = Sessao.token;
  final cabecalhos = {
    'Accept': 'application/json',
    if (corpo != null) 'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };
  http.Response resposta;
  try {
    final requisicao = http.Request(metodo, Uri.parse(Sessao.servidor + caminho))..headers.addAll(cabecalhos);
    if (corpo != null) requisicao.body = jsonEncode(corpo);
    resposta = await http.Response.fromStream(await requisicao.send().timeout(const Duration(seconds: 8)));
  } catch (_) {
    throw ApiErro('Não foi possível conectar ao servidor. Confira o endereço da API e a rede.', 0);
  }

  if (resposta.statusCode == 204) return null;
  dynamic dados;
  try {
    dados = jsonDecode(utf8.decode(resposta.bodyBytes));
  } catch (_) {
    dados = null;
  }

  if (resposta.statusCode >= 400) {
    final mensagem = _mensagemErro(dados, resposta.statusCode);
    if (resposta.statusCode == 401 && token != null) {
      Sessao.limpar();
      Sessao.mensagemLogin = mensagem;
      navegador.currentState?.pushNamedAndRemoveUntil('/login', (_) => false);
    }
    throw ApiErro(mensagem, resposta.statusCode);
  }
  return dados;
}
