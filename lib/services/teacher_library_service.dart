import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/teacher_library_book.dart';

class LibraryService {
  static const String baseUrl =
      "https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api/library/books";

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("auth_token");
  }

  Future<LibraryBook?> addBook(LibraryBook book) async {
    final token = await _getToken();
    if (token == null) throw Exception("No token found");

    final response = await http.post(
      Uri.parse(baseUrl),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(book.toJson()),
    );

    if (response.statusCode == 201) {
      final json = jsonDecode(response.body);
      return LibraryBook.fromJson(json["data"]);
    } else {
      throw Exception("Failed to add book: ${response.body}");
    }
  }

  Future<List<LibraryBook>> fetchBooks() async {
    final token = await _getToken();
    if (token == null) throw Exception("No token found");

    final response = await http.get(
      Uri.parse(baseUrl),
      headers: {"Authorization": "Bearer $token"},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List booksJson = data["data"];
      return booksJson.map((e) => LibraryBook.fromJson(e)).toList();
    } else {
      throw Exception("Failed to fetch books: ${response.body}");
    }
  }
}
