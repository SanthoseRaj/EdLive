import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/student_attendance_month.dart';

class StudentAttendanceService {
 Future<StudentAttendanceMonth> fetchMonthlyAttendance({
  required int studentId,
  required String startDate,
  required String endDate,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('auth_token');

  if (token == null) {
    throw Exception("Unauthorized: No token found");
  }

  final response = await http.get(
    Uri.parse(
        'https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api/attendance/studentMonthly?studentId=$studentId&startDate=$startDate&endDate=$endDate'),
    headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    },
  );

  if (response.statusCode == 200) {
    final Map<String, dynamic> jsonData = json.decode(response.body);
    return StudentAttendanceMonth.fromJson(jsonData);
  } else {
    throw Exception('Failed to load attendance');
  }
}
}
