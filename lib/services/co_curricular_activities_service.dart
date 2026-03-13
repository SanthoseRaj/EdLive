import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class CoCurricularActivity {
  final int id;
  final int categoryId;
  final String name;
  final String description;

  CoCurricularActivity({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.description,
  });

  factory CoCurricularActivity.fromJson(Map<String, dynamic> json) {
    return CoCurricularActivity(
      id: json['id'],
      categoryId: json['category_id'],
      name: json['name'],
      description: json['description']?.toString() ?? '',
    );
  }
}

class CoCurricularService {
  static Future<List<CoCurricularActivity>> fetchActivitiesByCategory(
      int categoryId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    if (token.isEmpty) {
      throw Exception("Auth token not found");
    }

    final url = Uri.parse(
        'https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api/co-curricular/activities?categoryId=$categoryId');

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body is List) {
        return body
            .map((e) => CoCurricularActivity.fromJson(e))
            .toList();
      } else {
        throw Exception('Invalid response format: expected a list');
      }
    } else {
      throw Exception('Failed to load activities: ${response.statusCode}');
    }
  }
}
