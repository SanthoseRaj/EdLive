import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:school_app/config/config.dart';
import 'package:school_app/models/teacher_quicknote_class_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QuickNoteClassService {
  String get baseUrl => AppConfig.baseUrl;

  Future<List<QuickNoteClass>> fetchClasses() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token'); // 🔑 stored during login

    final response = await http.get(
      Uri.parse('$baseUrl/quicknotes/classes'),
      headers: {"accept": "application/json", "Authorization": "Bearer $token"},
    );

    if (response.statusCode == 200) {
      List data = jsonDecode(response.body);
      return data.map((json) => QuickNoteClass.fromJson(json)).toList();
    } else {
      throw Exception("Failed to load classes");
    }
  }
}
