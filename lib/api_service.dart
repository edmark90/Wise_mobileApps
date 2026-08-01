import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Color;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthResult {
  final String token;
  final Map<String, dynamic> user;

  AuthResult({required this.token, required this.user});
}

class CollectionSchedule {
  final int id;
  final String barangay;
  final String zone;
  final String collectionDate;
  final String collectionTime;
  final String assignedPersonnel;
  final String status;
  final String? remarks;

  CollectionSchedule({
    required this.id,
    required this.barangay,
    required this.zone,
    required this.collectionDate,
    required this.collectionTime,
    required this.assignedPersonnel,
    required this.status,
    this.remarks,
  });

  factory CollectionSchedule.fromJson(Map<String, dynamic> json) {
    return CollectionSchedule(
      id: json['id'] ?? 0,
      barangay: json['barangay'] ?? '',
      zone: json['zone'] ?? '',
      collectionDate: json['collection_date'] ?? '',
      collectionTime: json['collection_time'] ?? '',
      assignedPersonnel: json['assigned_personnel'] ?? '',
      status: json['status'] ?? 'Upcoming',
      remarks: json['remarks'],
    );
  }

  String get formattedTime {
    if (collectionTime.isEmpty) return '';
    final parts = collectionTime.split(':');
    if (parts.length < 2) return collectionTime;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = parts[1];
    final ampm = h >= 12 ? 'PM' : 'AM';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:$m $ampm';
  }

  String get formattedDate {
    if (collectionDate.isEmpty) return '';
    try {
      final dt = DateTime.parse(collectionDate);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
      return '${days[dt.weekday % 7]}, ${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return collectionDate;
    }
  }

  Color get statusColor {
    switch (status) {
      case 'Upcoming': return const Color(0xFF1E40AF);
      case 'Arriving': return const Color(0xFF92400E);
      case 'Arrived': return const Color(0xFF166534);
      case 'Delayed': return const Color(0xFF991B1B);
      case 'Completed': return const Color(0xFF15803D);
      case 'Cancelled': return const Color(0xFF4B5563);
      default: return const Color(0xFF6B7280);
    }
  }

  Color get statusBgColor {
    switch (status) {
      case 'Upcoming': return const Color(0xFFEFF6FF);
      case 'Arriving': return const Color(0xFFFEF3C7);
      case 'Arrived': return const Color(0xFFF0FDF4);
      case 'Delayed': return const Color(0xFFFEF2F2);
      case 'Completed': return const Color(0xFFF0FDF4);
      case 'Cancelled': return const Color(0xFFF3F4F6);
      default: return const Color(0xFFF3F4F6);
    }
  }
}

class ApiService {
  static const String baseUrl = 'http://10.0.2.2:8000/api';

  /// Base host used to build absolute URLs for static files (profile images).
  static String get staticBaseUrl => baseUrl.substring(0, baseUrl.length - 4);

  static String profileImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    return '$staticBaseUrl/$path';
  }

  static String? _token;

  static const String _kTokenKey = 'auth_token';
  static const String _kUserFullnameKey = 'auth_user_fullname';
  static const String _kUserEmailKey = 'auth_user_email';
  static const String _kUserRoleKey = 'auth_user_role';

  static void setToken(String token) {
    _token = token;
  }

  /// Save the session so the user stays logged in after restarting the app.
  static Future<void> saveSession(String token, Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    _token = token;
    await prefs.setString(_kTokenKey, token);
    await prefs.setString(_kUserFullnameKey, (user['fullname'] ?? '').toString());
    await prefs.setString(_kUserEmailKey, (user['email'] ?? '').toString());
    await prefs.setString(_kUserRoleKey, (user['role'] ?? 'citizen').toString());
  }

  /// Restore a previously saved session. Returns null when there is none.
  static Future<Map<String, String>?> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_kTokenKey);
    if (token == null || token.isEmpty) return null;
    _token = token;
    return {
      'token': token,
      'fullname': prefs.getString(_kUserFullnameKey) ?? '',
      'email': prefs.getString(_kUserEmailKey) ?? '',
      'role': prefs.getString(_kUserRoleKey) ?? 'citizen',
    };
  }

  /// Forget the saved session on logout.
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kTokenKey);
    await prefs.remove(_kUserFullnameKey);
    await prefs.remove(_kUserEmailKey);
    await prefs.remove(_kUserRoleKey);
    _token = null;
  }

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  static Future<AuthResult> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final token = data['access_token'] as String;
      setToken(token);
      return AuthResult(
        token: token,
        user: data['user'],
      );
    }

    final error = jsonDecode(response.body);
    throw Exception(error['detail'] ?? 'Login failed');
  }

  static Future<AuthResult> signup({
    required String fullname,
    required String email,
    required String password,
    String? phone,
  }) async {
    final body = <String, dynamic>{
      'fullname': fullname,
      'email': email,
      'password': password,
    };
    if (phone != null && phone.isNotEmpty) {
      body['phone'] = phone;
    }

    final response = await http.post(
      Uri.parse('$baseUrl/auth/signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      final token = data['access_token'] as String;
      setToken(token);
      return AuthResult(
        token: token,
        user: data['user'],
      );
    }

    final error = jsonDecode(response.body);
    throw Exception(error['detail'] ?? 'Signup failed');
  }

  static Future<List<CollectionSchedule>> getUpcomingSchedules(String startDate, String endDate) async {
    final response = await http.get(
      Uri.parse('$baseUrl/collection-schedules/mobile/upcoming/?start_date=$startDate&end_date=$endDate'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => CollectionSchedule.fromJson(json)).toList();
    }

    if (response.statusCode == 401) {
      throw Exception('Unauthorized');
    }

    throw Exception('Failed to load schedules');
  }

  // ---------------------------------------------------------------------
  // Profile
  // ---------------------------------------------------------------------

  static Exception _errorFor(http.Response response, String fallback) {
    try {
      final data = jsonDecode(response.body);
      if (data is Map && data['detail'] != null) {
        return Exception(data['detail'].toString());
      }
    } catch (_) {}
    return Exception(fallback);
  }

  static Future<Map<String, dynamic>> getProfile() async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/profile'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw _errorFor(response, 'Failed to load profile');
  }

  static Future<Map<String, dynamic>> updateProfile({
    String? fullname,
    String? phone,
    String? barangay,
    String? zone,
  }) async {
    final body = <String, dynamic>{
      'fullname': ?fullname,
      'phone': ?phone,
      'barangay': ?barangay,
      'zone': ?zone,
    };
    final response = await http.put(
      Uri.parse('$baseUrl/users/profile'),
      headers: _headers,
      body: jsonEncode(body),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw _errorFor(response, 'Failed to update profile');
  }

  /// Upload a profile picture with real byte-level progress (0.0 - 1.0).
  static Future<String> uploadProfilePhoto(
    Uint8List bytes, {
    required String filename,
  }) async {
    final uri = Uri.parse('$baseUrl/users/profile/upload-photo');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $_token'
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
      ));

    final response = await request.send().timeout(const Duration(seconds: 30));
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      final data = jsonDecode(responseBody) as Map<String, dynamic>;
      return (data['profile_image'] ?? '').toString();
    }
    throw _errorFor(http.Response(responseBody, response.statusCode), 'Upload failed');
  }

  static Future<void> removeProfilePhoto() async {
    final response = await http.delete(
      Uri.parse('$baseUrl/users/profile/remove-photo'),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      throw _errorFor(response, 'Failed to remove photo');
    }
  }

  static Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/users/profile/change-password'),
      headers: _headers,
      body: jsonEncode({
        'current_password': currentPassword,
        'new_password': newPassword,
        'confirm_password': confirmPassword,
      }),
    );
    if (response.statusCode != 200) {
      throw _errorFor(response, 'Failed to change password');
    }
  }
}
