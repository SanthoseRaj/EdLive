import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/teacher_library_book_copy.dart';

class LibraryCopyService {
  final String baseUrl = "https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api";

  Future<LibraryBookCopy?> addCopy(LibraryBookCopy copy) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    final url = Uri.parse("$baseUrl/library/books/copies");
    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(copy.toJson()),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body)['data'];
      return LibraryBookCopy.fromJson(data);
    } else {
      throw Exception("Failed to add copy: ${response.body}");
    }
  }
}
