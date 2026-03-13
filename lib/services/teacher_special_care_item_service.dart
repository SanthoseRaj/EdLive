import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/teacher_special_care_item.dart';

class SpecialCareItemService {
  static const String baseUrl =
      "https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api/special-care";

  // Create special care item
  Future<SpecialCareItem> createSpecialCareItem(SpecialCareItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    final response = await http.post(
      Uri.parse(baseUrl),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(item.toJson()),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return SpecialCareItem.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to create special care item: ${response.body}');
    }
  }
}
