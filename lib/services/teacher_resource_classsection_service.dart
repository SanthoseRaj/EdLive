import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/teacher_resource_class_model.dart';

class TeacherResourceService {
  static const String baseUrl =
      "https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api";

  /// 🔹 Fetch teacher classes
  static Future<List<TeacherClassModel>> fetchTeacherClasses() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('auth_token');

    if (token == null) {
      throw Exception("No token found. Please login again.");
    }

    final response = await http.get(
      Uri.parse("$baseUrl/resources/classes"),
      headers: {
        "Authorization": "Bearer $token",
        "accept": "application/json",
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((e) => TeacherClassModel.fromJson(e)).toList();
    } else {
      throw Exception("Failed to load classes (Code: ${response.statusCode})");
    }
  }
}
