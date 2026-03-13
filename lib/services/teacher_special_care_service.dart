import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/teacher_special_care_model.dart';

class SpecialCareService {
  final String baseUrl =
      "https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api";

  Future<List<SpecialCareCategory>> fetchCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("auth_token"); // token saved at login

    final response = await http.get(
      Uri.parse("$baseUrl/special-care/categories"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token", // 🔑 Add token here
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((e) => SpecialCareCategory.fromJson(e)).toList();
    } else {
      throw Exception("Failed to fetch categories: ${response.statusCode}");
    }
  }
}
