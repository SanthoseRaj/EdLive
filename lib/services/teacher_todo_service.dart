import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import '../models/teacher_todo_model.dart';

class TodoService {
  final String baseUrl = 'https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api/todos';

  // PUT /api/todos/{id} with multipart/form-data
  Future<void> updateTodo(String id, {
    required String title,
    required String description,
    required String date,
    required int classId,
    required int subjectId,
    File? file,
    bool completed = true,
    String? authToken,
  }) async {
    final uri = Uri.parse('$baseUrl/$id');
    var request = http.MultipartRequest('PUT', uri);

    if (authToken != null) {
      request.headers['Authorization'] = 'Bearer $authToken';
    }

    request.fields['title'] = title;
    request.fields['description'] = description;
    request.fields['date'] = date;
    request.fields['classid'] = classId.toString();
    request.fields['subjectid'] = subjectId.toString();
    request.fields['completed'] = completed.toString();

    if (file != null) {
      final mimeType = lookupMimeType(file.path)?.split('/');
      if (mimeType != null && mimeType.length == 2) {
        request.files.add(await http.MultipartFile.fromPath(
          'todoFileUpload',
          file.path,
          contentType: MediaType(mimeType[0], mimeType[1]),
        ));
      }
    }

    final response = await request.send();

    if (response.statusCode != 200) {
      final respStr = await response.stream.bytesToString();
      throw Exception('Failed to update todo: $respStr');
    }
  }
}
