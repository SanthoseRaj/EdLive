import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/exam_type_model.dart';

class ExamTypeService {
  static const String baseUrl =
      "https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api/exams/types";

  Future<List<ExamType>> fetchExamTypes() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("auth_token") ?? '';

    final response = await http.get(
      Uri.parse(baseUrl),
      headers: {
        "Authorization": "Bearer $token",
        "Accept": "application/json",
      },
    );

    if (response.statusCode == 200) {
      final body = json.decode(response.body);
      if (body["success"] == true) {
        final data = body["data"] as List;
        return data.map((json) => ExamType.fromJson(json)).toList();
      }
    }
    throw Exception("Failed to fetch exam types");
  }
}
