import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:school_app/models/student_notification_msg_view_model.dart';

class NotificationReplyService {
  final String baseUrl =
      "https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api";

  Future<List<NotificationReply>> fetchReplies({
    required int itemId,
    required String itemType,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("auth_token");
    final studentId = prefs.getInt("student_id");

    if (token == null || studentId == null) {
      throw Exception("Missing token or student ID.");
    }

    final url = Uri.parse(
        "$baseUrl/dashboard/messages/$itemId/replies?item_type=$itemType&studentId=$studentId");

    final response = await http.get(
      url,
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
        throw Exception(data['message'] ?? "Failed to load replies.");
      }
    } else {
      throw Exception(
          "Error ${response.statusCode}: ${response.reasonPhrase}");
    }
  }


Future<void> postReply({
  required int itemId,
  required String itemType,
  int? parentId,
  required String messageText,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString("auth_token");
  final studentId = prefs.getInt("student_id");

  if (token == null || studentId == null) {
    throw Exception("Missing token or student ID.");
  }

  final url = Uri.parse(
      "$baseUrl/dashboard/messages/$itemId/reply?studentId=$studentId");

  final body = {
    "item_type": itemType,        // ✅ include item_type
    "message_text": messageText,  // ✅ message text
    if (parentId != null) "parent_id": parentId, // ✅ optional parent
  };

  final response = await http.post(
    url,
    headers: {
      "Authorization": "Bearer $token",
      "Content-Type": "application/json",
    },
    body: json.encode(body),
  );

  if (response.statusCode != 200) {
    throw Exception(
        "Error ${response.statusCode}: ${response.reasonPhrase}");
  }
}



}