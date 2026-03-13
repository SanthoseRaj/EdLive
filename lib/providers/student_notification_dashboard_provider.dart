import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class DashboardCountsProvider with ChangeNotifier {
  int notifications = 0;
  int todo = 0;
  int payments = 0;
  int messages = 0;
  int library = 0;
  int achievements = 0;

  bool isLoading = false;
  String? error;

  Future<void> fetchDashboardCounts(int studentId) async {
    try {
      isLoading = true;
      error = null;
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("auth_token");

      if (token == null) {
        error = "No auth token found";
        isLoading = false;
        notifyListeners();
        return;
      }

      final url =
          "https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api/dashboard/counts?studentId=$studentId";

      final response = await http.get(
        Uri.parse(url),
        headers: {
          "Authorization": "Bearer $token",
          "accept": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        notifications = data["notifications"] ?? 0;
        todo = data["todo"] ?? 0;
        payments = data["payments"] ?? 0;
        messages = data["messages"] ?? 0;
        library = data["library"] ?? 0;
        achievements = data["achievements"] ?? 0;
      } else {
        error = "Failed to load counts (${response.statusCode})";
      }
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
