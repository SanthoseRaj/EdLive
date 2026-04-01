import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/config.dart';
import '../models/dashboard_setting_item.dart';

class DashboardSettingsService {
  static const String _endpoint = '/setting/dashBoardUser';
  static const String _updateEndpoint = '/setting/updateDashBoard';

  Future<List<DashboardSettingItem>> fetchDashboardSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    final response = await http.get(
      AppConfig.apiUri(_endpoint),
      headers: {
        'accept': 'application/json',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load dashboard settings (${response.statusCode})',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw Exception('Invalid dashboard settings response');
    }

    final items =
        decoded
            .whereType<Map<String, dynamic>>()
            .map(DashboardSettingItem.fromJson)
            .toList()
          ..sort(
            (left, right) =>
                left.defaultPosition.compareTo(right.defaultPosition),
          );

    return items;
  }

  Future<void> updateDashboardSetting({
    required String elementKey,
    required bool isEnabled,
    required int position,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    final response = await http.put(
      AppConfig.apiUri(_updateEndpoint),
      headers: {
        'accept': 'application/json',
        'Content-Type': 'application/json',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'element_key': elementKey,
        'is_enabled': isEnabled,
        'position': position,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _extractMessage(
          response.body,
          fallback:
              'Failed to update dashboard setting (${response.statusCode})',
        ),
      );
    }
  }

  Future<Map<String, bool>> loadOverrides(String storageKey) async {
    final prefs = await SharedPreferences.getInstance();
    final rawValue = prefs.getString(storageKey);

    if (rawValue == null || rawValue.isEmpty) {
      return {};
    }

    final decoded = jsonDecode(rawValue);
    if (decoded is! Map) {
      return {};
    }

    return decoded.map<String, bool>((key, value) {
      return MapEntry(key.toString(), _asBool(value));
    });
  }

  Future<void> saveOverrides(
    String storageKey,
    Map<String, bool> values,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, jsonEncode(values));
  }

  bool _asBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }

    final normalized = value?.toString().toLowerCase();
    return normalized == 'true' || normalized == '1';
  }

  String _extractMessage(String body, {required String fallback}) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['message'] != null) {
        return decoded['message'].toString();
      }
    } catch (_) {
      // Ignore malformed response bodies and return the fallback below.
    }

    return fallback;
  }
}
