import '../models/teacher_student_profileview.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:school_app/config/config.dart';

class StudentService {
  // ... your existing fetchStudents() here

  static Future<StudentDetail> fetchStudentDetail(int id, String token) async {
    final url = '${AppConfig.serverOrigin}/studentview/$id';
    final res = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      return StudentDetail.fromJson(jsonDecode(res.body));
    } else {
      throw Exception('Failed to load student detail (${res.statusCode})');
    }
  }
}
