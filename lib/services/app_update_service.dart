import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:wise/core/config/app_config.dart';
import 'package:wise/core/network/api_client.dart';

import '../models/app_update.dart';

class AppUpdateService {
  static Future<LatestUpdateResult> getLatestUpdate() async {
    try {
      final token = ApiClient.instance.token;
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/api/mobile-updates/latest'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return LatestUpdateResult.fromJson(data);
      }
      return LatestUpdateResult(updateAvailable: false);
    } catch (e) {
      return LatestUpdateResult(updateAvailable: false);
    }
  }
}