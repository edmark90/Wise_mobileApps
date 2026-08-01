import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'controllers/auth_controller.dart';
import 'screens/Login.dart';
import 'screens/MainScreen.dart';

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
      routes: {
        '/home': (_) => const _HomeScreen(),
        '/login': (_) => const LoginScreen(),
      },
      home: const _AuthGate(),
    );
  }
}

/// Builds [MainScreen] from the session held by [AuthController].
class _HomeScreen extends StatelessWidget {
  const _HomeScreen();

  @override
  Widget build(BuildContext context) {
    final session = AuthController.instance.session;
    return MainScreen(
      userName: session?['fullname'] ?? '',
      userEmail: session?['email'] ?? '',
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
  final AuthController _auth = AuthController.instance;

  @override
  void initState() {
    super.initState();
    _auth.restoreSession();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _auth,
      builder: (context, _) {
        if (_auth.isRestoring) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }
        if (_auth.isLoggedIn) {
          return const _HomeScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
