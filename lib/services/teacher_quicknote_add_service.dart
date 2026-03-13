import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class TokenStorage {
  static const _key = "auth_token";

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

class QuickNoteService {
  final String baseUrl =
      "https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api/quicknotes";

  /// Create a quick note
  Future<Map<String, dynamic>> createQuickNote({
    required String title,
    required String description,
    required List<String> webLinks,
    required List<int> studentIds,
    required int classId,
  }) async {
    final token = await TokenStorage.getToken();
    if (token == null) throw Exception("Auth token not found");

    final url = Uri.parse(baseUrl);

    final response = await http.post(
      url,
      headers: {
        "accept": "*/*",
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "title": title,
        "description": description,
        "webLinks": webLinks,
        "studentIds": studentIds,
        "classId": classId,
      }),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Failed to create quick note: ${response.body}");
    }
  }

  /// Fetch students by class ID
  Future<List<Map<String, dynamic>>> getStudentsByClass(int classId) async {
    final token = await TokenStorage.getToken();
    if (token == null) throw Exception("Auth token not found");

    final url = Uri.parse(
        "https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api/quicknotes/classes/$classId/students");

    final response = await http.get(
      url,
      headers: {
        "accept": "*/*",
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception("Failed to fetch students: ${response.body}");
    }
  }
}
