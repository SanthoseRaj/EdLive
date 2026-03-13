// lib/services/library_api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '/models/student_library_book.dart';

class LibraryApiService {
  static const String baseUrl =
      "https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api/library";

  /// Search books and return model objects
  static Future<List<StudentLibraryBook>> searchBooks({
    String? title,
    String? author,
    String? isbn,
    String? genre,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    final queryParams = <String, String>{};
    if (title?.isNotEmpty ?? false) queryParams['title'] = title!;
    if (author?.isNotEmpty ?? false) queryParams['author'] = author!;
    if (isbn?.isNotEmpty ?? false) queryParams['isbn'] = isbn!;
    if (genre?.isNotEmpty ?? false) queryParams['genre'] = genre!;

    final uri = Uri.parse('$baseUrl/books/search')
        .replace(queryParameters: queryParams.isEmpty ? null : queryParams);

    final response = await http.get(uri, headers: {
      'accept': 'application/json',
      'Authorization': 'Bearer $token',
    });

    if (response.statusCode == 200) {
      final Map<String, dynamic> decoded = jsonDecode(response.body);
      final List data = decoded['data'] ?? [];
      return data.map((e) => StudentLibraryBook.fromJson(e)).toList();
    } else {
      throw Exception(
          'Failed to fetch books: ${response.statusCode} ${response.body}');
    }
  }

  /// (optional) other methods...
}
