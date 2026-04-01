import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:school_app/config/config.dart';
import '../models/student_schoolbus.dart';

class TransportService {
  static String get baseUrl => AppConfig.baseUrl;

  static Future<Transport?> fetchStudentTransport(
    int studentId, {
    String? academicYear,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token'); // saved during login
    final effectiveAcademicYear = academicYear?.trim().isNotEmpty == true
        ? academicYear!.trim()
        : AppConfig.academicYear;

    final url = Uri.parse(
      "$baseUrl/transport/students/$studentId/$effectiveAcademicYear",
    );

    final response = await http.get(
      url,
      headers: {"accept": "application/json", "Authorization": "Bearer $token"},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return Transport.fromJson(data);
    } else {
      throw Exception("Failed to load transport data");
    }
  }
}
