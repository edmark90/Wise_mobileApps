/// Thrown when the device cannot reach the server (offline, timeout,
/// connection refused, DNS failure, ...). These are the errors the SWR cache
/// treats as "network unavailable" and never discards valid cache for.
class NetworkException implements Exception {
  final String message;
  const NetworkException(this.message);

  @override
  String toString() => message;
}

/// Thrown when the server responds with an HTTP error status or an
/// application-level error payload (e.g. `{"detail": "..."}`).
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}
