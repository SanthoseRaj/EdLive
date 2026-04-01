import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:school_app/config/config.dart';
import '../models/student_message_model.dart';

class MessageService {
  static String get baseUrl => '${AppConfig.baseUrl}/messages';

  static Future<List<StudentMessage>> fetchMessages(int studentId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("auth_token") ?? "";

    final response = await http.get(
      Uri.parse("$baseUrl/$studentId"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((e) => StudentMessage.fromJson(e)).toList();
    } else {
      throw Exception("Failed to load messages");
    }
  }
}
