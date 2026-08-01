import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'api_service.dart';
import 'screen/Login.dart';
import 'screen/MainScreen.dart';

void main() {
  runApp(const WasteWiseApp());
}

class WasteWiseApp extends StatelessWidget {
  const WasteWiseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WasteWise',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: AppColors.primary,
        fontFamily: 'Roboto',
      ),
      home: const _AuthGate(),
    );
  }
}

/// Decides where the app opens: straight to the dashboard when a session is
/// saved, otherwise the login screen.
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  bool _checked = false;
  Map<String, String>? _session;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    var session = await ApiService.loadSession();
    final role = (session?['role'] ?? 'citizen').toLowerCase();
    if (role != 'citizen') {
      await ApiService.clearSession();
      session = null;
    }
    if (!mounted) return;
    setState(() {
      _session = session;
      _checked = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final s = _session;
    if (s != null) {
      return MainScreen(
        userName: s['fullname'] ?? '',
        userEmail: s['email'] ?? '',
      );
    }
    return const LoginScreen();
  }
}
