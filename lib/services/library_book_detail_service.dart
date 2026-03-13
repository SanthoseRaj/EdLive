import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LibraryBookDetailService {
  final String baseUrl =
      "https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api/library";

  Future<Map<String, dynamic>?> getBookById(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("auth_token");

    final response = await http.get(
      Uri.parse("$baseUrl/books/$id"),
      headers: {
        "accept": "application/json",
        "Authorization": "Bearer $token", // 👈 attach token
      },
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return body["data"] as Map<String, dynamic>;
    } else {
      throw Exception("Failed to load book $id: ${response.statusCode}");
    }
  }
}
