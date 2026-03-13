import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/teacher_syllabus_subject_model.dart';

class SubjectService {
  Future<List<SubjectModel>> fetchSubjects() async {
    final url = Uri.parse(
        "https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api/master/subjects");

    final response = await http.get(
      url,
      headers: {
        "accept": "application/json",
      },
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => SubjectModel.fromJson(e)).toList();
    } else {
      throw Exception("Failed to load subjects: ${response.body}");
    }
  }
}