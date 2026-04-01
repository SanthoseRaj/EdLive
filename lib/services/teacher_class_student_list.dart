import '../models/teacher_student_profileview.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/teacher_class_student.dart';
import 'package:school_app/config/config.dart';

class StudentService {
  static Future<List<Student>> fetchStudents(String token) async {
    final url = Uri.parse('${AppConfig.baseUrl}/staff/staff/students/list');

    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Student.fromJson(json)).toList();
    } else {
      throw Exception(
        'Failed to load students. Status: ${response.statusCode}',
      );
    }
  }

  static Future<StudentDetail> fetchStudentDetail(int id, String token) async {
    final url = '${AppConfig.serverOrigin}/studentview/$id';
    final response = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return StudentDetail.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(
        'Failed to load student detail. Status: ${response.statusCode}',
      );
    }
  }
}
