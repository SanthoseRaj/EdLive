import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/config.dart';
import '../models/teacher_todo_model.dart';

const List<String> kTodoUploadExtensions = [
  'jpg',
  'jpeg',
  'png',
  'gif',
  'webp',
  'bmp',
  'pdf',
  'doc',
  'docx',
];

class TeacherTaskProvider with ChangeNotifier {
  static const Map<String, String> _mimeTypeByExtension = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'gif': 'image/gif',
    'webp': 'image/webp',
    'bmp': 'image/bmp',
    'pdf': 'application/pdf',
    'doc': 'application/msword',
    'docx':
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  };

  final String _baseUrl = '${AppConfig.baseUrl}/todos';

  List<Todo> _tasks = [];
  String? _authToken;

  void setAuthToken(String? token) {
    _authToken = token;
    notifyListeners();
  }

  List<Todo> get tasks => _tasks;

  Todo? getTaskById(String id) {
    try {
      return _tasks.firstWhere((task) => task.id == id);
    } catch (_) {
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

      debugPrint('GET /todos -> status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _tasks.clear();
        _tasks.addAll(data.map((item) => Todo.fromJson(item)).toList());

        // ✅ NEW → sort by latest date first
        _tasks.sort((a, b) {
          final dateA = DateTime.tryParse(a.createdAt ?? '') ?? DateTime(2000);
          final dateB = DateTime.tryParse(b.createdAt ?? '') ?? DateTime(2000);
          return dateB.compareTo(dateA);
        });

        notifyListeners();
        return;
      }

      throw Exception('Failed to load todos. Status: ${response.statusCode}');
    } catch (e) {
      debugPrint('Error in fetchTodos: $e');
      rethrow;
    }
  }

  String _resolveMimeType(PlatformFile pickedFile) {
    final headerBytes = pickedFile.bytes?.take(32).toList();
    final pathOrName = (pickedFile.path != null && pickedFile.path!.isNotEmpty)
        ? pickedFile.path!
        : pickedFile.name;

    return lookupMimeType(pathOrName, headerBytes: headerBytes) ??
        _mimeTypeByExtension[pickedFile.extension?.toLowerCase()] ??
        'application/octet-stream';
  }

  Future<http.MultipartFile?> _buildTodoMultipartFile(
    PlatformFile pickedFile,
  ) async {
    final mimeType = _resolveMimeType(pickedFile);
    final typeParts = mimeType.split('/');
    final mediaType = typeParts.length == 2
        ? MediaType(typeParts[0], typeParts[1])
        : null;

    if (pickedFile.bytes != null && pickedFile.bytes!.isNotEmpty) {
      return http.MultipartFile.fromBytes(
        'todoFileUpload',
        pickedFile.bytes!,
        filename: pickedFile.name,
        contentType: mediaType,
      );
    }

    if (pickedFile.path != null && pickedFile.path!.isNotEmpty) {
      return http.MultipartFile.fromPath(
        'todoFileUpload',
        pickedFile.path!,
        filename: pickedFile.name,
        contentType: mediaType,
      );
    }

    return null;
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

    final tempTodo = Todo(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      description: description,
      date: date,
      completed: false,
      classId: classId,
      subjectId: subjectId,
      className: '',
      fileUrl: null,
      userId: null,
      createdAt: DateTime.now().toString(),
      updatedAt: DateTime.now().toString(),
    );

    final newList = List<Todo>.from(_tasks);
    newList.insert(0, tempTodo);
    _tasks = newList;
    notifyListeners();

    final uri = Uri.parse(_baseUrl);
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['date'] = date;
    request.fields['title'] = title;
    request.fields['description'] = description;
    request.fields['classid'] = classId.toString();
    request.fields['subjectid'] = subjectId.toString();

    debugPrint('Sending fields: ${request.fields}');

    if (pickedFile != null) {
      try {
        final multipartFile = await _buildTodoMultipartFile(pickedFile);
        if (multipartFile == null) {
          throw Exception('Selected file could not be read for upload');
        }

        request.files.add(multipartFile);
        debugPrint(
          'Added file: ${pickedFile.name} (${_resolveMimeType(pickedFile)})',
        );
      } catch (e) {
        debugPrint('File attach error: $e');
        _tasks.removeWhere((task) => task.id == tempTodo.id);
        notifyListeners();
        rethrow;
      }
    }

    try {
      final response = await request.send();
      final responseString = await response.stream.bytesToString();

      debugPrint('POST /todos -> status: ${response.statusCode}');
      debugPrint('Response: $responseString');

      if (response.statusCode == 201 || response.statusCode == 200) {
        await fetchTodos();
        return;
      }

      _tasks.removeWhere((task) => task.id == tempTodo.id);
      notifyListeners();
      throw Exception('Failed to add todo: $responseString');
    } catch (e) {
      debugPrint('Error in addTodo: $e');
      _tasks.removeWhere((task) => task.id == tempTodo.id);
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
    final request = http.MultipartRequest('PUT', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['date'] = date;
    request.fields['title'] = title;
    request.fields['description'] = description;
    request.fields['classid'] = classId.toString();
    request.fields['subjectid'] = subjectId.toString();

    debugPrint('Updating todo $id with fields: ${request.fields}');

    if (pickedFile != null) {
      final multipartFile = await _buildTodoMultipartFile(pickedFile);
      if (multipartFile == null) {
        throw Exception('Selected file could not be read for upload');
      }

      request.files.add(multipartFile);
      debugPrint(
        'Added file while updating: ${pickedFile.name} (${_resolveMimeType(pickedFile)})',
      );
    }

    final response = await request.send();
    final responseString = await response.stream.bytesToString();

    debugPrint('PUT /todos/$id -> status: ${response.statusCode}');
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

      debugPrint('DELETE /todos/$id -> status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 204) {
        _tasks = _tasks.where((task) => task.id != id).toList();
        notifyListeners();
        return;
      }

      final errorBody = json.decode(response.body);
      throw Exception('Failed to delete todo: ${errorBody['error']}');
    } catch (e) {
      debugPrint('Error in deleteTodo: $e');
      rethrow;
    }
  }
}
