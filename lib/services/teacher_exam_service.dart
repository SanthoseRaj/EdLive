import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/teacher_exam_model.dart';

class TeacherExamService {
  static Future<List<TeacherExam>> fetchExamsByClassId(String classId) async {
    final url = Uri.parse(
      'https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api/exams/teacher/$classId',
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final body = json.decode(response.body);
      final List data = body['data'];
      return data.map((item) => TeacherExam.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load exams');
    }
  }
}
