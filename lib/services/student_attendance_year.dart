import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:school_app/models/student_attendance_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:school_app/config/config.dart';

class StudentYearlyAttendanceService {
  Future<StudentAttendanceYearly?> fetchYearlyAttendance(int studentId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      print('Token is null');
      return null;
    }

    final String url =
        '${AppConfig.baseUrl}/studentattendance/yearly/$studentId';

    print('URL: $url');
    print('Token: $token');

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    print('Status Code: ${response.statusCode}');
    print('Response Body: ${response.body}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return StudentAttendanceYearly.fromJson(data);
    } else {
      print('Error fetching yearly attendance: ${response.statusCode}');
      return null;
    }
  }
}
