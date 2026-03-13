import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class DashboardService {
  static const String baseUrl =
      "https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api";

  static Future<bool> markItemViewed(String itemType, int itemId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final response = await http.post(
        Uri.parse('$baseUrl/dashboard/viewed'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'accept': 'application/json',
        },
        body: jsonEncode({
          "item_type": itemType,
          "item_id": itemId,
        }),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        print('Failed to mark item viewed: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error in markItemViewed: $e');
      return false;
    }
  }
}
