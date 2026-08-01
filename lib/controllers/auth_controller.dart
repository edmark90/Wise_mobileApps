import 'package:flutter/foundation.dart';

import '../core/cache/swr_cache.dart';
import '../models/auth_result.dart';
import '../services/auth_service.dart';

/// Controller for authentication flow and session state.
///
/// Views (Login, Signup, MainScreen) call [login]/[signup]/[logout] and
/// listen to this controller for the current session and busy state.
class AuthController extends ChangeNotifier {
  AuthController._();
  static final AuthController instance = AuthController._();

  Map<String, String>? _session;
  bool _restoring = true;
  bool _busy = false;

  Map<String, String>? get session => _session;
  bool get isRestoring => _restoring;
  bool get isBusy => _busy;
  bool get isLoggedIn => _session != null;

  String? get userName => _session?['fullname'];
  String? get userEmail => _session?['email'];

  /// Restore a previously saved session at app launch.
  ///
  /// Defensive: if the platform storage fails (e.g. in tests), fall back to
  /// a logged-out state instead of leaving the app stuck on the splash.
  Future<void> restoreSession() async {
    _restoring = true;
    notifyListeners();
    try {
      var session = await AuthService.instance.loadSession();
      final role = (session?['role'] ?? 'citizen').toLowerCase();
      if (role != 'citizen') {
        await AuthService.instance.clearSession();
        session = null;
      }
      _session = session;
    } catch (_) {
      _session = null;
    } finally {
      _restoring = false;
      notifyListeners();
    }
  }

  /// Log in and persist the session. Throws on failure (view shows the error).
  Future<AuthResult> login(String email, String password) async {
    _busy = true;
    notifyListeners();
    try {
      final result = await AuthService.instance.login(email, password);
      AuthService.instance.assertCitizenRole(result.user);
      await AuthService.instance.saveSession(result.token, result.user);
      _session = {
        'fullname': (result.user['fullname'] ?? '').toString(),
        'email': (result.user['email'] ?? '').toString(),
        'role': (result.user['role'] ?? 'citizen').toString(),
      };
      return result;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Sign up, persist the session, and return the created account.
  Future<AuthResult> signup({
    required String fullname,
    required String email,
    required String password,
    String? phone,
  }) async {
    _busy = true;
    notifyListeners();
    try {
      final result = await AuthService.instance.signup(
        fullname: fullname,
        email: email,
        password: password,
        phone: phone,
      );
      await AuthService.instance.saveSession(result.token, result.user);
      _session = {
        'fullname': (result.user['fullname'] ?? '').toString(),
        'email': (result.user['email'] ?? '').toString(),
        'role': (result.user['role'] ?? 'citizen').toString(),
      };
      return result;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Log out: clear the session and every cached resource.
  Future<void> logout() async {
    await AuthService.instance.clearSession();
    await SwrCache.instance.clearAll();
    _session = null;
    notifyListeners();
  }
}
