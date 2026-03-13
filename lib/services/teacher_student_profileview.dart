import '../models/teacher_student_profileview.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class StudentService {
  // ... your existing fetchStudents() here

  static Future<StudentDetail> fetchStudentDetail(int id, String token) async {
    final url = 'https://schoolmanagement.canadacentral.cloudapp.azure.com:443/studentview/$id';
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
