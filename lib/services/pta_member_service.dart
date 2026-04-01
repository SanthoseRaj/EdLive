import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:school_app/config/config.dart';
import '../models/pta_member_model.dart';

class PTAMemberService {
  static String get baseUrl => AppConfig.serverOrigin;

  Future<List<PTAMember>> getMembers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    final response = await http.get(
      Uri.parse('$baseUrl/api/pta/members'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch PTA members');
    }

    final List<dynamic> data = json.decode(response.body);
    return data.map((json) => PTAMember.fromJson(json)).toList();
  }
}
