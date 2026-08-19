import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// URL del backend.
///  - Emulador Android: http://10.0.2.2:4000
///  - Simulador iOS / desktop / web: http://localhost:4000
///  - Dispositivo físico: usa la IP de tu máquina en la red local.
const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:4000',
);

const String kSocketUrl = String.fromEnvironment(
  'SOCKET_URL',
  defaultValue: 'http://10.0.2.2:4000',
);

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

class ApiClient {
  static const _tokenKey = 'auth_token';
  static String? _token;

  String? get token => _token;

  Future<void> setToken(String? token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    if (token == null) {
      await prefs.remove(_tokenKey);
    } else {
      await prefs.setString(_tokenKey, token);
    }
  }

  Future<void> restoreToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
  }

  Future<Map<String, dynamic>> get(
    String path, {
    bool auth = true,
  }) =>
      _send('GET', path, auth: auth);

  Future<Map<String, dynamic>> post(
    String path, {
    Object? body,
    bool auth = true,
  }) =>
      _send('POST', path, body: body, auth: auth);

  Future<Map<String, dynamic>> put(
    String path, {
    Object? body,
    bool auth = true,
  }) =>
      _send('PUT', path, body: body, auth: auth);

  Future<Map<String, dynamic>> delete(
    String path, {
    bool auth = true,
  }) =>
      _send('DELETE', path, auth: auth);

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Object? body,
    bool auth = true,
  }) async {
    final uri = Uri.parse('$kApiBaseUrl$path');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      HttpHeaders.acceptHeader: 'application/json',
    };
    if (auth && _token != null) {
      headers[HttpHeaders.authorizationHeader] = 'Bearer $_token';
    }

    final http.Response res;
    if (method == 'GET') {
      res = await http.get(uri, headers: headers);
    } else if (method == 'PUT') {
      res = await http.put(
        uri,
        headers: headers,
        body: body == null ? null : jsonEncode(body),
      );
    } else if (method == 'DELETE') {
      res = await http.delete(uri, headers: headers);
    } else {
      res = await http.post(
        uri,
        headers: headers,
        body: body == null ? null : jsonEncode(body),
      );
    }

    final decoded = res.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(res.body) as Map<String, dynamic>;

    if (res.statusCode >= 400) {
      throw ApiException(
        res.statusCode,
        decoded['error'] as String? ?? 'Error ${res.statusCode}',
      );
    }
    return decoded;
  }
}
