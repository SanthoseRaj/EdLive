import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/student_syllabus_model.dart';
import '../models/student_syllabus_detail_model.dart';

class SyllabusService {
  final String baseUrl =
      "https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api";

  Future<List<SyllabusSubject>> fetchSyllabusSubjects(int classId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    final response = await http.get(
      Uri.parse('$baseUrl/syllabus/subjects/$classId'),
      headers: {
        'accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => SyllabusSubject.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load subjects');
    }
  }

  Future<List<SyllabusDetail>> fetchSyllabusDetail(
      int classId, int subjectId, String academicYear) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    final response = await http.get(
      Uri.parse('$baseUrl/syllabus/$classId/$subjectId/$academicYear'),
      headers: {
        'accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => SyllabusDetail.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load syllabus details');
    }
  }
}
