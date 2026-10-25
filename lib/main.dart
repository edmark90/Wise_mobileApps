import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'controllers/auth_controller.dart';
import 'core/config/app_config.dart';
import 'screens/Login.dart';
import 'screens/MainScreen.dart';

import 'package:flutter/services.dart';

// Global navigator key for deep linking from push notifications
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Auto-pick the backend: local FastAPI server in debug when reachable,
  // otherwise the production Render URL.
  AppConfig.setCustomUrl(await AppConfig.resolveAutoBaseUrl());
  runApp(const WasteWiseApp());
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
  );
}

class WasteWiseApp extends StatelessWidget {
  const WasteWiseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
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
          return Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'asset/logowise.png',
                    width: 96,
                    height: 96,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 20),
                  const CircularProgressIndicator(color: AppColors.primary),
                ],
              ),
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
