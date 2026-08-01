import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

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

  static const String baseUrl = 'http://192.168.1.34:8000/api';

  /// Base host used to build absolute URLs for static files (profile images).
  static String get staticBaseUrl => baseUrl.substring(0, baseUrl.length - 4);

  static const Duration _timeout = Duration(seconds: 20);

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

  Future<http.Response> get(String path, {Map<String, String>? query}) => _guard(
        () => http.get(_uri(path, query), headers: _headers).timeout(_timeout),
      );

  Future<http.Response> post(String path, {Object? body}) => _guard(
        () => http.post(_uri(path), headers: _headers, body: jsonEncode(body)).timeout(_timeout),
      );

  Future<http.Response> put(String path, {Object? body}) => _guard(
        () => http.put(_uri(path), headers: _headers, body: jsonEncode(body)).timeout(_timeout),
      );

  Future<http.Response> delete(String path) => _guard(
        () => http.delete(_uri(path), headers: _headers).timeout(_timeout),
      );

  /// Send a multipart file upload (used for profile photos).
  Future<http.Response> multipart(
    String path, {
    required String field,
    required List<int> bytes,
    required String filename,
  }) async {
    final request = http.MultipartRequest('POST', _uri(path))
      ..headers['Authorization'] = 'Bearer $_token'
      ..files.add(http.MultipartFile.fromBytes(field, bytes, filename: filename));

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
