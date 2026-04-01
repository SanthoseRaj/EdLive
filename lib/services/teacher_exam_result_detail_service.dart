import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:school_app/config/config.dart';
import '../models/exam_result_detail_model.dart';

class TeacherExamResultDetailService {
  String get baseUrl => AppConfig.serverOrigin;

  Future<ExamResultData?> fetchStudentExamResults(
    int studentId, {
    int? examTypeId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    final queryParameters = <String, String>{};
    if (examTypeId != null && examTypeId > 0) {
      queryParameters['examTypeId'] = examTypeId.toString();
    }

    final url = Uri.parse('$baseUrl/api/exams/results/student/$studentId')
        .replace(
          queryParameters: queryParameters.isEmpty ? null : queryParameters,
        );

    final response = await http.get(
      url,
      headers: {'accept': 'application/json', 'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final result = ExamResultDetailResponse.fromJson(decoded);
      if (result.success && result.data != null) {
        return result.data!;
      } else {
        throw Exception("Failed to fetch exam results");
      }
    } else {
      throw Exception(
        "Error fetching results: ${response.statusCode} ${response.reasonPhrase}",
      );
    }
  }
}
