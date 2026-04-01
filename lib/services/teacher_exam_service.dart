import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/teacher_exam_model.dart';
import 'package:school_app/config/config.dart';

class TeacherExamService {
  static Future<List<TeacherExam>> fetchExamsByClassId(String classId) async {
    final url = Uri.parse('${AppConfig.baseUrl}/exams/teacher/$classId');

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
