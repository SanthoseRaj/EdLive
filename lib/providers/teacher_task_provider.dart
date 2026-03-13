import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/teacher_todo_model.dart';

class TeacherTaskProvider with ChangeNotifier {
  List<Todo> _tasks = [];
  final String _baseUrl = 'https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api/todos';
  String? _authToken;

  void setAuthToken(String? token) {
    _authToken = token;
    notifyListeners();
  }

  List<Todo> get tasks => _tasks;

  Todo? getTaskById(String id) {
    try {
      return _tasks.firstWhere((task) => task.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<void> fetchTodos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? _authToken ?? '';
      
      final response = await http.get(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      debugPrint('GET /todos → status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _tasks = data.map((item) => Todo.fromJson(item)).toList();
        notifyListeners();
      } else {
        throw Exception('Failed to load todos. Status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error in fetchTodos: $e');
      rethrow;
    }
  }

Future<void> addTodo({
  required String title,
  required String date,
  required String description,
  required int classId,
  required int subjectId,
  PlatformFile? pickedFile,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('auth_token') ?? _authToken ?? '';

  if (token.isEmpty) {
    throw Exception('No authentication token available');
  }

  // ✅ 1. Create a temporary todo for instant UI update
  final tempTodo = Todo(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    title: title,
    description: description,
    date: date,
    completed: false, // required field
    classId: classId,
    subjectId: subjectId,
    className: '', // optional placeholder
    fileUrl: null,
    userId: null,
    createdAt: DateTime.now().toString(),
    updatedAt: DateTime.now().toString(),
  );

  _tasks.insert(0, tempTodo);
  notifyListeners(); // instant UI update

  final uri = Uri.parse(_baseUrl);
  var request = http.MultipartRequest('POST', uri);
  request.headers['Authorization'] = 'Bearer $token';

  // ✅ Add form fields
  request.fields['date'] = date;
  request.fields['title'] = title;
  request.fields['description'] = description;
  request.fields['classid'] = classId.toString();
  request.fields['subjectid'] = subjectId.toString();

  debugPrint('Sending fields: ${request.fields}');

  // ✅ Add file if exists
  if (pickedFile != null) {
    try {
      if (kIsWeb && pickedFile.bytes != null) {
        final mimeType = lookupMimeType(pickedFile.name) ?? 'application/octet-stream';
        final typeParts = mimeType.split('/');
        request.files.add(http.MultipartFile.fromBytes(
          'todoFileUpload',
          pickedFile.bytes!,
          filename: pickedFile.name,
          contentType: MediaType(typeParts[0], typeParts[1]),
        ));
      } else if (pickedFile.path != null && File(pickedFile.path!).existsSync()) {
        final mimeType = lookupMimeType(pickedFile.path!) ?? 'application/octet-stream';
        final typeParts = mimeType.split('/');
        request.files.add(await http.MultipartFile.fromPath(
          'todoFileUpload',
          pickedFile.path!,
          filename: pickedFile.name,
          contentType: MediaType(typeParts[0], typeParts[1]),
        ));
      }
      debugPrint('Added file: ${pickedFile.name}');
    } catch (e) {
      debugPrint('File attach error: $e');
    }
  }

  try {
    // ✅ 2. Upload to server
    final response = await request.send();
    final responseString = await response.stream.bytesToString();

    debugPrint('POST /todos → status: ${response.statusCode}');
    debugPrint('Response: $responseString');

    if (response.statusCode == 201 || response.statusCode == 200) {
      // ✅ 3. Sync with latest server data
      await fetchTodos();
    } else {
      // If failed → remove temp todo
      _tasks.removeWhere((t) => t.id == tempTodo.id);
      notifyListeners();
      throw Exception('Failed to add todo: $responseString');
    }
  } catch (e) {
    debugPrint('Error in addTodo: $e');
    _tasks.removeWhere((t) => t.id == tempTodo.id); // rollback
    notifyListeners();
    rethrow;
  }
}

  Future<void> updateTodo({
    required String id,
    required String title,
    required String date,
    required String description,
    required int classId,
    required int subjectId,
    PlatformFile? pickedFile,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? _authToken ?? '';

    if (token.isEmpty) {
      throw Exception('No authentication token available');
    }

    final uri = Uri.parse('$_baseUrl/$id');
    var request = http.MultipartRequest('PUT', uri);
    request.headers['Authorization'] = 'Bearer $token';

    // Add form fields
    request.fields['date'] = date;
    request.fields['title'] = title;
    request.fields['description'] = description;
    request.fields['classid'] = classId.toString();
    request.fields['subjectid'] = subjectId.toString();

    debugPrint('Updating todo $id with fields: ${request.fields}');

    // Add file if exists
    if (pickedFile != null) {
      if (kIsWeb && pickedFile.bytes != null) {
        final mimeType = lookupMimeType(pickedFile.name) ?? 'application/octet-stream';
        final typeParts = mimeType.split('/');
        
        request.files.add(
          http.MultipartFile.fromBytes(
            'todoFileUpload',
            pickedFile.bytes!,
            filename: pickedFile.name,
            contentType: MediaType(typeParts[0], typeParts[1]),
          ),
        );
      } else if (pickedFile.path != null && File(pickedFile.path!).existsSync()) {
        final file = File(pickedFile.path!);
        final mimeType = lookupMimeType(pickedFile.path!) ?? 'application/octet-stream';
        final typeParts = mimeType.split('/');
        
        request.files.add(
          await http.MultipartFile.fromPath(
            'todoFileUpload',
            pickedFile.path!,
            filename: pickedFile.name,
            contentType: MediaType(typeParts[0], typeParts[1]),
          ),
        );
      }
    }

    final response = await request.send();
    final responseString = await response.stream.bytesToString();
    
    debugPrint('PUT /todos/$id → status: ${response.statusCode}');
    debugPrint('Response: $responseString');

    if (response.statusCode != 200) {
      throw Exception('Failed to update todo: $responseString');
    }

    await fetchTodos();
  }

  Future<void> deleteTodo({required String id}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? _authToken ?? '';

    if (token.isEmpty) {
      throw Exception('No authentication token available');
    }

    final url = '$_baseUrl/$id';
    try {
      final response = await http.delete(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      debugPrint('DELETE /todos/$id → status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 204) {
        _tasks.removeWhere((task) => task.id == id);
        notifyListeners();
      } else {
        final errorBody = json.decode(response.body);
        throw Exception('Failed to delete todo: ${errorBody['error']}');
      }
    } catch (e) {
      debugPrint('Error in deleteTodo: $e');
      rethrow;
    }
  }
}