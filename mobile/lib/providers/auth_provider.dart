import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../core/socket_service.dart';
import '../models/user.dart';

class AuthProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();
  final SocketService _socket = SocketService();

  User? user;
  String? token;
  bool isLoading = false;
  String? error;

  bool get isAuthenticated => user != null;

  SocketService get socket => _socket;

  Future<void> restoreSession() async {
    await _api.restoreToken();
    token = _api.token;
    if (token == null) return;
    try {
      final data = await _api.get('/api/auth/me');
      user = User.fromJson(data);
      await _socket.connect(token!);
      notifyListeners();
    } catch (e) {
      await _api.setToken(null);
      token = null;
      user = null;
    }
  }

  Future<bool> login(String email, String password) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final data = await _api.post(
        '/api/auth/login',
        body: {'email': email, 'password': password},
        auth: false,
      );
      user = User.fromJson(data['user']);
      token = data['token'] as String;
      await _api.setToken(token);
      await _socket.connect(token!);
      return true;
    } on ApiException catch (e) {
      error = e.message;
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required String role,
  }) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final data = await _api.post(
        '/api/auth/register',
        body: {
          'fullName': fullName,
          'email': email,
          'phone': phone,
          'password': password,
          'role': role,
        },
        auth: false,
      );
      user = User.fromJson(data['user']);
      token = data['token'] as String;
      await _api.setToken(token);
      await _socket.connect(token!);
      return true;
    } on ApiException catch (e) {
      error = e.message;
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshProfile() async {
    final data = await _api.get('/api/auth/me');
    user = User.fromJson(data);
    notifyListeners();
  }

  Future<void> logout() async {
    _socket.dispose();
    await _api.setToken(null);
    token = null;
    user = null;
    notifyListeners();
  }
}
