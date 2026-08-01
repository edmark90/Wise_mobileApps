import 'package:shared_preferences/shared_preferences.dart';

import '../core/network/api_client.dart';
import '../core/network/network_exception.dart';
import '../models/auth_result.dart';

/// Handles authentication: login, signup, and persistent session storage.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const String _kTokenKey = 'auth_token';
  static const String _kUserFullnameKey = 'auth_user_fullname';
  static const String _kUserEmailKey = 'auth_user_email';
  static const String _kUserRoleKey = 'auth_user_role';

  Future<AuthResult> login(String email, String password) async {
    final response = await ApiClient.instance.post('/auth/login', body: {
      'email': email,
      'password': password,
    });
    final data = ApiClient.instance.decode(response);
    final token = data['access_token'] as String;
    ApiClient.instance.setToken(token);
    return AuthResult(token: token, user: (data['user'] as Map).cast<String, dynamic>());
  }

  Future<AuthResult> signup({
    required String fullname,
    required String email,
    required String password,
    String? phone,
  }) async {
    final body = <String, dynamic>{
      'fullname': fullname,
      'email': email,
      'password': password,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
    };
    final response = await ApiClient.instance.post('/auth/signup', body: body);
    final data = ApiClient.instance.decode(response, expectedStatus: 201);
    final token = data['access_token'] as String;
    ApiClient.instance.setToken(token);
    return AuthResult(token: token, user: (data['user'] as Map).cast<String, dynamic>());
  }

  /// Save the session so the user stays logged in after restarting the app.
  Future<void> saveSession(String token, Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    ApiClient.instance.setToken(token);
    await prefs.setString(_kTokenKey, token);
    await prefs.setString(_kUserFullnameKey, (user['fullname'] ?? '').toString());
    await prefs.setString(_kUserEmailKey, (user['email'] ?? '').toString());
    await prefs.setString(_kUserRoleKey, (user['role'] ?? 'citizen').toString());
  }

  /// Restore a previously saved session. Returns `null` when there is none.
  Future<Map<String, String>?> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_kTokenKey);
    if (token == null || token.isEmpty) return null;
    ApiClient.instance.setToken(token);
    return {
      'token': token,
      'fullname': prefs.getString(_kUserFullnameKey) ?? '',
      'email': prefs.getString(_kUserEmailKey) ?? '',
      'role': prefs.getString(_kUserRoleKey) ?? 'citizen',
    };
  }

  /// Forget the saved session on logout.
  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kTokenKey);
    await prefs.remove(_kUserFullnameKey);
    await prefs.remove(_kUserEmailKey);
    await prefs.remove(_kUserRoleKey);
    ApiClient.instance.setToken(null);
  }

  /// Throw if the account role is not allowed to use the citizen app.
  void assertCitizenRole(Map<String, dynamic> user) {
    final role = (user['role'] ?? 'citizen').toString().toLowerCase();
    if (role != 'citizen') {
      throw const ApiException('Admin accounts can only sign in on the web admin site.');
    }
  }

}
