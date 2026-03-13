import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class CoCurricularCategory {
  final int id;
  final String name;

  CoCurricularCategory({required this.id, required this.name});

  factory CoCurricularCategory.fromJson(Map<String, dynamic> json) {
    return CoCurricularCategory(
      id: json['id'],
      name: json['name'],
    );
  }
}

class CoCurricularCategoryService {
  static Future<List<CoCurricularCategory>> fetchCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    final response = await http.get(
      Uri.parse('https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api/co-curricular/categories'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => CoCurricularCategory.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load categories');
    }
  }
}
