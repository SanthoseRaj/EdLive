// lib/providers/dashboard_provider.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/teacher_dashboard_counts.dart';

class DashboardProvider with ChangeNotifier {
  DashboardCounts? _counts;
  bool _isLoading = false;

  DashboardCounts? get counts => _counts;
  bool get isLoading => _isLoading;

  Future<void> fetchCounts() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token'); // ensure token is saved at login

      final response = await http.get(
        Uri.parse(
          'https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api/dashboard/counts',
        ),
        headers: {
          'accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _counts = DashboardCounts.fromJson(data);
      } else {
        _counts = null;
      }
    } catch (e) {
      _counts = null;
    }

    _isLoading = false;
    notifyListeners();
  }
Future<void> markDashboardItemViewed(int itemId) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null) return;

    final response = await http.post(
      Uri.parse('https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api/dashboard/viewed'),
      headers: {
        'accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        "item_type": "payments",
        "item_id": itemId, // 👈 dynamic from API
      }),
    );

    if (response.statusCode == 200) {
      print("Marked payment $itemId as viewed ✅");
    } else {
      print("Failed to mark payment $itemId viewed: ${response.body}");
    }
  } catch (e) {
    print("Error marking payment viewed: $e");
  }
}
}