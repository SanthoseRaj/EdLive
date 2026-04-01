import 'package:flutter/material.dart';
import '../models/exam_result_model.dart';
import '../services/teacher_exam_result_service.dart';

class ExamResultProvider extends ChangeNotifier {
  final ExamResultService _service = ExamResultService();

  bool isSaving = false;

  Future<int?> saveResult(ExamResult result, {int? resultId}) async {
    isSaving = true;
    notifyListeners();

    try {
      return await _service.saveExamResult(result, resultId: resultId);
    } catch (e) {
      rethrow;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }
}
