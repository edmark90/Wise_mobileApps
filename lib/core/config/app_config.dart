/// App-wide configuration for API connections.
///
/// All builds talk to the single production backend on Render only. Local
/// ports / LAN probing were removed so the app never connects to anything
/// but the deployed server.
class AppConfig {
  AppConfig._();

  static const String _defaultProdUrl = 'https://wise-backend-9oze.onrender.com';

  static String? _overrideUrl;

  /// Set a custom base URL at runtime if needed.
  static void setCustomUrl(String? url) {
    _overrideUrl = url;
  }

  /// Returns active API base URL (without trailing slash or `/api`).
  static String get apiBaseUrl {
    if (_overrideUrl != null && _overrideUrl!.isNotEmpty) {
      return _overrideUrl!;
    }

    const envUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (envUrl.isNotEmpty) {
      return envUrl;
    }

    return _defaultProdUrl;
  }

  /// The app always targets the production Render backend.
  static Future<String> resolveAutoBaseUrl() async => _defaultProdUrl;
}

