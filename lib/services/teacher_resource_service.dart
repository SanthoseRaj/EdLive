import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:school_app/config/config.dart';
import '../models/teacher_resource_model.dart';

class TeacherResourceMainService {
  static String get baseUrl => '${AppConfig.baseUrl}/resources';

  static Future<List<TeacherResourceModel>> fetchResources({
    int? classId,
    int? subjectId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("auth_token");

    final uri = Uri.parse(baseUrl).replace(
      queryParameters: {
        if (classId != null) "classId": classId.toString(),
        if (subjectId != null) "subjectId": subjectId.toString(),
      },
    );

    final response = await http.get(
      uri,
      headers: {"accept": "application/json", "Authorization": "Bearer $token"},
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((json) => TeacherResourceModel.fromJson(json)).toList();
    } else {
      throw Exception("Failed to load resources: ${response.body}");
    }
  }
}
