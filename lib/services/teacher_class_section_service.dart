import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class TeacherClass {
  final int id;
  final String className;
  final String section;
  final String fullName;

  TeacherClass({
    required this.id,
    required this.className,
    required this.section,
    required this.fullName,
  });

  factory TeacherClass.fromJson(Map<String, dynamic> json) {
    return TeacherClass(
      id: json['class_id'],
      className: json['class'] ?? '',
      section: json['section'] ?? '',
      fullName: json['class_name'] ?? '',
    );
  }
}

class TeacherClassService {
  Future<List<TeacherClass>> fetchTeacherClasses() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null) {
      throw Exception("No auth token found");
    }

    final url = Uri.parse(
        "https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api/staff/staff/teacher/class");

    final response = await http.get(
      url,
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => TeacherClass.fromJson(e)).toList();
    } else {
      throw Exception("Failed to load teacher classes: ${response.body}");
    }
  }
}
