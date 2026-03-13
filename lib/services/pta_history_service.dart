import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:school_app/models/class_section.dart';
import 'package:school_app/services/class_section_service.dart';
import '../models/pta_history_model.dart';

class PTAHistoryService {
  static const String baseUrl = 'https://schoolmanagement.canadacentral.cloudapp.azure.com:443';

  Future<List<PTAHistory>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    // Fetch history
    final response = await http.get(
      Uri.parse('$baseUrl/api/pta/meetings/history'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch PTA history');
    }

    final List<dynamic> data = json.decode(response.body);
    List<PTAHistory> history = data.map((json) => PTAHistory.fromJson(json)).toList();

    // Fetch class sections
    List<ClassSection> classes = await ClassService().fetchClassSections();

    // Map class IDs to class names
    for (var meeting in history) {
      meeting.classNames = meeting.classIds
          .map((id) => classes.firstWhere(
                (c) => c.id == id,
                orElse: () => ClassSection(id: id, className: 'Unknown', section: ''),
              ).fullName)
          .toList();
    }

    return history;
  }
}
