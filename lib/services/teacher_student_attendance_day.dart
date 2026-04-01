import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:school_app/config/config.dart';
import '../models/teacher_student_attendance_day.dart';

class TeacherAttendanceService {
  static String get baseUrl => AppConfig.serverOrigin;

  static Future<List<AttendanceStudent>> fetchAttendanceStudents() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';

    final response = await http.get(
      Uri.parse('$baseUrl/api/students'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data
          .map(
            (json) =>
                AttendanceStudent(id: json['id'], name: json['student_name']),
          )
          .toList();
    } else {
      throw Exception('Failed to load students');
    }
  }

  static Future<void> toggleAttendance({
    required int studentId,
    required int classId,
    required String date,
    required String session,
    required bool isPresent,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    final response = await http.post(
      Uri.parse('$baseUrl/api/attendance/toggle'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'studentId': studentId,
        'classId': classId,
        'date': date,
        'session': session,
        'isPresent': isPresent,
      }),
    );

    if (response.statusCode != 200) {
      print("Attendance toggle failed: \${response.body}");
      throw Exception('Failed to toggle attendance');
    }
  }
}
