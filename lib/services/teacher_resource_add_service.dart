import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class TeacherResourceAddService {
  static const String baseUrl =
      "https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api/resources";

  static Future<bool> addResource({
    required String title,
    required String description,
    required List<String> webLinks,
    required int classId,
    required int subjectId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("auth_token");

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          "accept": "*/*",
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "title": title,
          "description": description,
          "webLinks": webLinks,
          "classId": classId,
          "subjectId": subjectId,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true; // ✅ success
      } else {
        throw Exception("Failed to add resource: ${response.body}");
      }
    } catch (e) {
      throw Exception("Error: $e");
    }
  }
}
