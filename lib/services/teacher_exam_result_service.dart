import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/exam_result_model.dart';

class ExamResultService {
  final String baseUrl =
      "https://schoolmanagement.canadacentral.cloudapp.azure.com:443";

  Future<bool> saveExamResult(ExamResult result) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    final response = await http.post(
      Uri.parse('$baseUrl/api/exams/results'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(result.toJson()),
    );

    if (response.statusCode == 201) {
      return true;
    } else {
      throw Exception(
          'Failed to save exam result: ${response.statusCode} ${response.body}');
    }
  }
}
