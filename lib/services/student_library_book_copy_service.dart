import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:school_app/config/config.dart';
import '../models/student_library_book.dart';
import '../models/student_library_copy.dart';

class StudentLibraryService {
  String get baseUrl => '${AppConfig.baseUrl}/library';

  Future<List<StudentLibraryBook>> fetchAllBooks() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token") ?? "";

    final response = await http.get(
      Uri.parse("$baseUrl/books"),
      headers: {"Authorization": "Bearer $token", "accept": "application/json"},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List booksJson = data["data"];
      return booksJson.map((e) => StudentLibraryBook.fromJson(e)).toList();
    } else {
      throw Exception("Failed to load books: ${response.body}");
    }
  }

  Future<Map<String, dynamic>> fetchBookDetails(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("auth_token") ?? "";

    final response = await http.get(
      Uri.parse("$baseUrl/books/$id"),
      headers: {"Authorization": "Bearer $token", "accept": "application/json"},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final book = StudentLibraryBook.fromJson(data["data"]);
      final copiesJson = data["data"]["copies"] as List;
      final copies = copiesJson
          .map((e) => StudentLibraryCopy.fromJson(e))
          .toList();
      return {"book": book, "copies": copies};
    } else {
      throw Exception("Failed to load book details: ${response.body}");
    }
  }
}
