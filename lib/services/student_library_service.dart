import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:school_app/config/config.dart';
import '../models/student_overdue_book.dart';

class StudentLibraryService {
  String get baseUrl => '${AppConfig.baseUrl}/library';

  Future<List<StudentOverdueBook>> fetchOverdueBooks() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    final url = Uri.parse("$baseUrl/checkouts/overdue");

    final response = await http.get(
      url,
      headers: {'accept': 'application/json', 'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final body = json.decode(response.body);
      if (body["success"] == true && body["data"] != null) {
        return (body["data"] as List)
            .map((json) => StudentOverdueBook.fromJson(json))
            .toList();
      }
    }
    throw Exception("Failed to load overdue books");
  }
}
