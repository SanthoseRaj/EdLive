import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/teacher_syllabus_model.dart';

class SyllabusService {
  final String baseUrl =
      'https://schoolmanagement.canadacentral.cloudapp.azure.com:443';

  Future<List<Subject>> fetchSubjects(int classId) async {
    final url = Uri.parse('$baseUrl/api/syllabus/subjects/$classId');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Subject.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load subjects');
    }
  }
}
