import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/teacher_student_classsection.dart';
import 'package:shared_preferences/shared_preferences.dart';


class StudentService {
  Future<List<StudentClassSection>> fetchStudents() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null) {
      throw Exception("Auth token not found.");
    }

    final response = await http.get(
      Uri.parse('https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api/staff/staff/students/list'),
      headers: {
        'accept': '*/*',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => StudentClassSection.fromJson(json)).toList();
    } else {
      throw Exception('Failed to fetch students');
    }
  }
}

class AttendanceService {
  final String baseUrl = 'https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api';

  Future<void> toggleAttendance({
    required int studentId,
    required int classId,
    required String date,
    required String session, // "morning" or "afternoon"
    required bool isPresent,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    final url = Uri.parse('$baseUrl/attendance/toggle');

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "studentId": studentId,
        "classId": classId,
        "date": date,
        "session": session,
        "isPresent": isPresent,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception("Failed to toggle attendance");
    }
  }
}