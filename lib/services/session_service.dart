import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:school_app/config/config.dart';

class SessionService {
  const SessionService._();

  static Future<String> prepareLogout() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token')?.trim() ?? '';

    await clearStoredSession();

    return token;
  }

  static Future<void> notifyServerLogout([String? token]) async {
    final headers = <String, String>{'accept': 'application/json'};
    final normalizedToken = token?.trim() ?? '';
    if (normalizedToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $normalizedToken';
    }

    try {
      final response = await http
          .post(AppConfig.apiUri('/auth/logout'), headers: headers, body: '')
          .timeout(const Duration(seconds: 20));

      if (response.statusCode >= 400) {
        debugPrint(
          'Logout request failed with status ${response.statusCode}: ${response.body}',
        );
      }
    } on TimeoutException catch (error) {
      debugPrint('Logout request timed out: $error');
    } on SocketException catch (error) {
      debugPrint('Logout request failed: $error');
    } on http.ClientException catch (error) {
      debugPrint('Logout request failed: $error');
    } catch (error) {
      debugPrint('Unexpected logout error: $error');
    }
  }

  static Future<void> clearStoredSession() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().toList(growable: false);

    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}
