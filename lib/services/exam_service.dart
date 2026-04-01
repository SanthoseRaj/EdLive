// services/exam_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/student_exam_model.dart';
import 'package:school_app/config/config.dart';

class ExamService {
  static Future<List<StudentExam>> fetchExams(String studentId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    final url = Uri.parse('${AppConfig.baseUrl}/exams/student/$studentId');

    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );

    if (response.statusCode == 200) {
      final body = json.decode(response.body);
      final upcoming = body['data']['upcoming'] as List;
      final past = body['data']['past'] as List;
      final allExams = [...upcoming, ...past];
      return allExams.map((e) => StudentExam.fromJson(e)).toList();

      // return exams.map((e) => StudentExam.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load exams');
    }
  }
}
