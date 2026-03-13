import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/co_curricular_stat.dart';

class CoCurricularProvider extends ChangeNotifier {
  List<CoCurricularStat> stats = [];
  bool isLoading = false;
  String? error;

  Future<void> fetchStats({int? classId, String? academicYear}) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        throw Exception("No token found");
      }

      final uri = Uri.parse(
        "https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api/co-curricular/stats"
        "${classId != null ? "?classId=$classId" : ""}"
        "${academicYear != null ? "&academicYear=$academicYear" : ""}",
      );

      final response = await http.get(
        uri,
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        stats = data.map((e) => CoCurricularStat.fromJson(e)).toList();
      } else {
        error = "Failed to load stats (${response.statusCode})";
      }
    } catch (e) {
      error = e.toString();
    }

    isLoading = false;
    notifyListeners();
  }
}
