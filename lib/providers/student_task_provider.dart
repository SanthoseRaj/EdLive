import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/student_todo_model.dart';

class StudentTaskProvider with ChangeNotifier {
  List<StudentTodo> _tasks = [];
  String? _authToken;
  bool _isLoading = false;

  Set<String> _seenTaskIds = {}; // Track seen task IDs

  final String _baseUrl =
      'https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api/todos/student';

  void setAuthToken(String? token) {
    _authToken = token;
  }

  List<StudentTodo> get tasks => _tasks;
  bool get isLoading => _isLoading;

  Set<String> get seenTaskIds => _seenTaskIds;

  int get newTaskCount =>
      _tasks.where((task) => !_seenTaskIds.contains(task.id)).length;

  Future<void> markTasksAsSeen(List<String> seenIds) async {
    final prefs = await SharedPreferences.getInstance();
    _seenTaskIds.addAll(seenIds);
    await prefs.setStringList('seen_task_ids', _seenTaskIds.toList());
    notifyListeners();
  }

  Future<void> fetchStudentTodos() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      _seenTaskIds = prefs.getStringList('seen_task_ids')?.toSet() ?? {};

      final response = await http.get(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          if (_authToken != null) 'Authorization': 'Bearer $_authToken',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _tasks = data.map((json) => StudentTodo.fromJson(json)).toList();
      } else {
        _tasks = [];
      }
    } catch (e) {
      print('Error fetching student todos: $e');
      _tasks = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}