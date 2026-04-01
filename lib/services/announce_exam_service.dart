import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:school_app/config/config.dart';

class AnnounceExamService {
  static Future<bool> createExam({
    required String title,
    required String subject,
    required String dateTimeISO,
    required String classId,
    required String description,
    required int examTypeId,
  }) async {
    final url = Uri.parse('${AppConfig.baseUrl}/exams');

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "title": title,
        "subject": subject,
        "exam_date": dateTimeISO,
        "class_id": classId,
        "description": description,
        "exam_type_id": examTypeId, // You can pass 1 for "class test"
      }),
    );

    return response.statusCode == 201 || response.statusCode == 200;
  }
}
