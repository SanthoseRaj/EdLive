import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:school_app/config/config.dart';
import '../models/exam_result_model.dart';
import '../models/exam_result_detail_model.dart';

class ExamResultService {
  String get baseUrl => AppConfig.serverOrigin;

  Future<int?> saveExamResult(ExamResult result, {int? resultId}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    final headers = {
      'accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    if (resultId != null && resultId > 0) {
      return await _updateExistingResult(
        result: result,
        resultId: resultId,
        token: token,
        headers: headers,
      );
    }

    final response = await http.post(
      Uri.parse('$baseUrl/api/exams/results'),
      headers: headers,
      body: jsonEncode(result.toJson()),
    );

    if (_isSuccess(response.statusCode)) {
      return _extractResultId(response.body) ?? resultId;
    } else if (_isDuplicateConstraint(response)) {
      final persistedAfterCreate = await _findExistingResultForExam(
        result.studentId,
        result.examId,
        token,
      );
      if (_matchesSavedResult(persistedAfterCreate, result)) {
        return persistedAfterCreate!.id > 0
            ? persistedAfterCreate.id
            : resultId;
      }

      final existingResultId = persistedAfterCreate?.id ?? resultId;
      if (existingResultId != null && existingResultId > 0) {
        return await _updateExistingResult(
          result: result,
          resultId: existingResultId,
          token: token,
          headers: headers,
        );
      }

      throw Exception(
        'Result already exists for this exam and student, '
        'but the backend did not confirm the updated mark.',
      );
    } else {
      throw Exception(
        'Failed to save exam result: ${response.statusCode} ${response.body}',
      );
    }
  }

  Future<int?> _updateExistingResult({
    required ExamResult result,
    required int resultId,
    required String token,
    required Map<String, String> headers,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/api/exams/results/$resultId'),
      headers: headers,
      body: jsonEncode(result.toJson()),
    );

    if (_isSuccess(response.statusCode)) {
      return _extractResultId(response.body) ?? resultId;
    }

    final persistedResult = await _waitForMatchingResult(
      studentId: result.studentId,
      examId: result.examId,
      desiredMarks: result.marks,
      token: token,
    );
    if (_matchesSavedResult(persistedResult, result)) {
      return persistedResult!.id > 0 ? persistedResult.id : resultId;
    }

    if (_isKnownBrokenUpdateResponse(response)) {
      return resultId;
    }

    throw Exception(
      'Failed to update exam result: ${response.statusCode} ${response.body}',
    );
  }

  bool _isSuccess(int statusCode) {
    return statusCode >= 200 && statusCode < 300;
  }

  bool _isDuplicateConstraint(http.Response response) {
    if (response.statusCode != 409 && response.statusCode < 500) {
      return false;
    }

    final responseBody = response.body.toLowerCase();
    return responseBody.contains('duplicate key value') ||
        responseBody.contains('unique_exam_student');
  }

  bool _isKnownBrokenUpdateResponse(http.Response response) {
    if (response.statusCode < 500) {
      return false;
    }

    final responseBody = response.body.toLowerCase();
    return responseBody.contains('column u.name does not exist');
  }

  bool _matchesSavedResult(ExamResultItem? item, ExamResult desiredResult) {
    if (item == null) {
      return false;
    }

    return item.examId == desiredResult.examId &&
        item.studentId == desiredResult.studentId &&
        (int.tryParse(item.marks?.trim() ?? '') ?? -1) == desiredResult.marks;
  }

  Future<ExamResultItem?> _findExistingResultForExam(
    int studentId,
    int examId,
    String token,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/exams/results/student/$studentId'),
      headers: {'accept': 'application/json', 'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      return null;
    }

    try {
      final decoded = jsonDecode(response.body);
      final result = ExamResultDetailResponse.fromJson(decoded);
      if (!result.success || result.data == null) {
        return null;
      }

      for (final item in result.data!.examResults) {
        if (item.examId == examId) {
          return item;
        }
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  Future<ExamResultItem?> _waitForMatchingResult({
    required int studentId,
    required int examId,
    required int desiredMarks,
    required String token,
  }) async {
    const retryDelays = <Duration>[
      Duration(milliseconds: 150),
      Duration(milliseconds: 350),
      Duration(milliseconds: 700),
    ];

    ExamResultItem? latestResult = await _findExistingResultForExam(
      studentId,
      examId,
      token,
    );
    if ((int.tryParse(latestResult?.marks?.trim() ?? '') ?? -1) ==
        desiredMarks) {
      return latestResult;
    }

    for (final delay in retryDelays) {
      await Future.delayed(delay);
      latestResult = await _findExistingResultForExam(studentId, examId, token);
      if ((int.tryParse(latestResult?.marks?.trim() ?? '') ?? -1) ==
          desiredMarks) {
        return latestResult;
      }
    }

    return latestResult;
  }

  int? _extractResultId(String responseBody) {
    if (responseBody.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      return _readInt(decoded['id']) ??
          _readInt(decoded['result_id']) ??
          _readNestedResultId(decoded['data']);
    } catch (_) {
      return null;
    }
  }

  int? _readNestedResultId(dynamic data) {
    if (data is! Map) {
      return null;
    }

    return _readInt(data['id']) ?? _readInt(data['result_id']);
  }

  int? _readInt(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '');
  }
}
