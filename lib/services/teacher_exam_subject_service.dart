import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/teacher_exam_subject.dart';

class TeacherExamService {
  final String baseUrl = "https://schoolmanagement.canadacentral.cloudapp.azure.com:443";

  Future<List<TeacherExam>> fetchTeacherExams() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("auth_token") ?? "";

    final response = await http.get(
      Uri.parse("$baseUrl/api/exams/teacher"),
      headers: {
        "accept": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      final body = json.decode(response.body);
      final List examsJson = body['data'];
      return examsJson.map((e) => TeacherExam.fromJson(e)).toList();
    } else {
      throw Exception("Failed to load exams");
    }
  }
}
