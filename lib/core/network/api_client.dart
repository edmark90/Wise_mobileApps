import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/app_config.dart';
import 'network_exception.dart';

/// Thin HTTP wrapper around `package:http`.
///
/// Owns the auth token, base URL, timeouts, and unified error handling so
/// services never deal with raw `http.Response` plumbing:
///  - network-level failures become [NetworkException]
///  - HTTP errors / `{"detail": ...}` payloads become [ApiException]
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  /// API base URL (includes the `/api` prefix). Derives from [AppConfig] so
  /// the backend URL is centralized in exactly one place.
  static String get baseUrl => '${AppConfig.apiBaseUrl}/api';

  /// Base host used to build absolute URLs for static files (profile images).
  static String get staticBaseUrl => AppConfig.apiBaseUrl;

  static const Duration _timeout = Duration(seconds: 20);
  /// Health/model-info endpoints hit Render cold starts (30-60 s).
  static const Duration _rootTimeout = Duration(seconds: 60);

  String? _token;
  String? get token => _token;

  void setToken(String? token) => _token = token;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Uri _uri(String path, [Map<String, String>? query]) {
    final uri = Uri.parse('$baseUrl$path');
    return (query == null || query.isEmpty) ? uri : uri.replace(queryParameters: query);
  }

  // ---------------------------------------------------------------------
  // HTTP verbs
  // ---------------------------------------------------------------------

  Future<http.Response> get(
    String path, {
    Map<String, String>? query,
    Duration? timeout,
  }) =>
      _guard(
        () => http
            .get(_uri(path, query), headers: _headers)
            .timeout(timeout ?? _timeout),
      );

  /// Send a GET to a path on the API *root* (outside the `/api` namespace).
  ///
  /// Used by infrastructure endpoints such as `/health` and `/model/info`
  /// that the backend exposes at the root rather than under `/api`.
  Future<http.Response> getRoot(String path, {Map<String, String>? query}) => _guard(
        () async {
          var uri = Uri.parse('${AppConfig.apiBaseUrl}$path');
          if (query != null && query.isNotEmpty) {
            uri = uri.replace(queryParameters: query);
          }
          return http.get(uri, headers: _headers).timeout(_rootTimeout);
        },
      );

  Future<http.Response> post(String path, {Object? body, Duration? timeout}) =>
      _guard(
        () => http
            .post(_uri(path), headers: _headers, body: jsonEncode(body))
            .timeout(timeout ?? _timeout),
      );

  Future<http.Response> put(String path, {Object? body}) => _guard(
        () => http.put(_uri(path), headers: _headers, body: jsonEncode(body)).timeout(_timeout),
      );

  Future<http.Response> delete(String path) => _guard(
        () => http.delete(_uri(path), headers: _headers).timeout(_timeout),
      );

  /// Send a multipart file upload (used for profile photos and AI prediction).
  ///
  /// Always attaches an explicit [MediaType] so the backend never sees
  /// `application/octet-stream`. Defaults to `image/jpeg`; pass [contentType]
  /// to override (e.g. `image/png`).
  Future<http.Response> multipart(
    String path, {
    required String field,
    required List<int> bytes,
    required String filename,
    MediaType? contentType,
  }) async {
    // Infer MIME from file extension when not provided explicitly
    final resolved = contentType ?? _mimeForFilename(filename);
    final request = http.MultipartRequest('POST', _uri(path))
      ..headers['Authorization'] = 'Bearer $_token'
      ..files.add(
        http.MultipartFile.fromBytes(
          field,
          bytes,
          filename: filename,
          contentType: resolved,
        ),
      );

    try {
      final streamed = await request.send().timeout(_timeout);
      final body = await streamed.stream.bytesToString();
      return http.Response(body, streamed.statusCode);
    } on TimeoutException {
      throw const NetworkException('The connection timed out.');
    } on SocketException {
      throw const NetworkException('No internet connection.');
    } on http.ClientException {
      throw const NetworkException('Could not reach the server.');
    }
  }

  /// Infer a proper image [MediaType] from a file extension.
  /// Falls back to `image/jpeg` for anything unrecognised.
  static MediaType _mimeForFilename(String filename) {
    final ext = filename.toLowerCase().split('.').last;
    return switch (ext) {
      'png'  => MediaType('image', 'png'),
      'webp' => MediaType('image', 'webp'),
      'gif'  => MediaType('image', 'gif'),
      'heic' => MediaType('image', 'heic'),
      _      => MediaType('image', 'jpeg'), // jpg / jpeg / everything else
    };
  }

  // ---------------------------------------------------------------------
  // Response handling
  // ---------------------------------------------------------------------

  /// Decode a successful response body, or throw a friendly [ApiException].
  dynamic decode(http.Response response, {int expectedStatus = 200, String fallback = 'Something went wrong'}) {
    final decoded = _tryDecode(response);
    if (response.statusCode != expectedStatus) {
      throw ApiException(_detail(decoded, fallback), statusCode: response.statusCode);
    }
    return decoded;
  }

  dynamic _tryDecode(http.Response response) {
    if (response.body.isEmpty) return null;
    try {
      return jsonDecode(response.body);
    } catch (_) {
      return null;
    }
  }

  String _detail(dynamic decoded, String fallback) {
    if (decoded is Map && decoded['detail'] != null) return decoded['detail'].toString();
    return fallback;
  }

  Future<http.Response> _guard(Future<http.Response> Function() request) async {
    try {
      return await request();
    } on TimeoutException {
      throw const NetworkException('The connection timed out.');
    } on SocketException {
      throw const NetworkException('No internet connection.');
    } on http.ClientException {
      throw const NetworkException('Could not reach the server.');
    }
  }
}
