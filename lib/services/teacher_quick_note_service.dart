import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:school_app/config/config.dart';
import '../models/teacher_quick_note_model.dart';

class QuickNoteService {
  static String get baseUrl => '${AppConfig.baseUrl}/quicknotes';

  Future<List<QuickNote>> fetchQuickNotes({
    int? classId,
    int? studentId,
  }) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('auth_token');

    Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    // Build query parameters
    Map<String, String> queryParams = {};
    if (classId != null) queryParams['classId'] = classId.toString();
    if (studentId != null) queryParams['studentId'] = studentId.toString();

    Uri uri = Uri.parse(baseUrl).replace(queryParameters: queryParams);

    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      List jsonData = json.decode(response.body);
      return jsonData.map((e) => QuickNote.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load quick notes');
    }
  }
}
