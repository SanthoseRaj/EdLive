import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:school_app/config/config.dart';
import '../models/student_syllabus_model.dart';

class SyllabusService {
  String get baseUrl => AppConfig.baseUrl;

  Future<List<SyllabusSubject>> fetchSyllabusSubjects(int classId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token'); // ✅ stored at login

    final response = await http.get(
      Uri.parse('$baseUrl/syllabus/subjects/$classId'),
      headers: {'accept': 'application/json', 'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => SyllabusSubject.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load syllabus subjects');
    }
  }
}
