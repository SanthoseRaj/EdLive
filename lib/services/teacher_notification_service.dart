import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import 'package:school_app/config/config.dart';
import 'package:school_app/models/teacher_notification_reply_model.dart';

class NotificationService {
  String get baseUrl => AppConfig.baseUrl;

  // Fetch replies for a specific notification
  Future<List<NotificationReply>> fetchReplies({
    required int itemId,
    required String itemType,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        throw Exception("No token found. Please login again.");
      }

      final url =
          "$baseUrl/dashboard/messages/$itemId/replies?item_type=$itemType";

      final response = await http.get(
        Uri.parse(url),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final List list = data['replies'] ?? [];
          return list.map((e) => NotificationReply.fromJson(e)).toList();
        } else {
          throw Exception("Failed to load replies.");
        }
      } else {
        throw Exception(
          "Error ${response.statusCode}: ${response.reasonPhrase}",
        );
      }
    } catch (e) {
      throw Exception("Something went wrong: $e");
    }
  }

  // Send a reply for a specific notification
  Future<NotificationReply> sendReply({
    required int itemId,
    required String itemType,
    required String message,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        throw Exception("No token found. Please login again.");
      }

      final url = "$baseUrl/dashboard/messages/$itemId/reply";

      final response = await http.post(
        Uri.parse(url),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: json.encode({"item_type": itemType, "message_text": message}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['reply'] != null) {
          return NotificationReply.fromJson(data['reply']);
        } else {
          throw Exception("Failed to send reply.");
        }
      } else {
        throw Exception(
          "Error ${response.statusCode}: ${response.reasonPhrase}",
        );
      }
    } catch (e) {
      throw Exception("Something went wrong: $e");
    }
  }
}
