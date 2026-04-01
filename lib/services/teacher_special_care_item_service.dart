import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/teacher_special_care_item.dart';

class SpecialCareItemService {
  static const String baseUrl =
      "https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api/special-care";
  static const String _fileFieldName = 'specialCareFileUpload';

  Future<SpecialCareItem> createSpecialCareItem(
    SpecialCareItem item, {
    PlatformFile? attachment,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    if (attachment == null) {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(item.toJson()),
      );

      return _parseResponse(
        statusCode: response.statusCode,
        responseBody: response.body,
        fallbackItem: item,
      );
    }

    final request = http.MultipartRequest('POST', Uri.parse(baseUrl));
    request.headers.addAll({
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    });

    request.fields.addAll({
      'studentIds': jsonEncode(item.studentIds),
      'categoryId': item.categoryId.toString(),
      'title': item.title,
      'description': item.description,
      'careType': item.careType,
      'scheduleDetails': jsonEncode({'days': item.days, 'time': item.time}),
      'resources': jsonEncode({
        'materials': item.materials,
        'tools': item.tools,
      }),
      'assignedTo': item.assignedTo.toString(),
      'status': item.status,
      'startDate': item.startDate,
      'endDate': item.endDate,
      'visibility': item.visibility,
    });

    await _attachFile(request, attachment);

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();
    return _parseResponse(
      statusCode: response.statusCode,
      responseBody: responseBody,
      fallbackItem: item,
    );
  }

  Future<void> _attachFile(
    http.MultipartRequest request,
    PlatformFile attachment,
  ) async {
    final mimeType =
        lookupMimeType(attachment.path ?? attachment.name) ??
        'application/octet-stream';
    final typeParts = mimeType.split('/');
    final contentType = typeParts.length == 2
        ? MediaType(typeParts[0], typeParts[1])
        : MediaType('application', 'octet-stream');

    if (kIsWeb && attachment.bytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          _fileFieldName,
          attachment.bytes!,
          filename: attachment.name,
          contentType: contentType,
        ),
      );
      return;
    }

    final filePath = attachment.path;
    if (filePath == null || !File(filePath).existsSync()) {
      throw Exception('Selected file is not available anymore.');
    }

    request.files.add(
      await http.MultipartFile.fromPath(
        _fileFieldName,
        filePath,
        filename: attachment.name,
        contentType: contentType,
      ),
    );
  }

  SpecialCareItem _parseResponse({
    required int statusCode,
    required String responseBody,
    required SpecialCareItem fallbackItem,
  }) {
    if (statusCode == 201 || statusCode == 200) {
      final body = responseBody.trim();
      if (body.isEmpty) {
        return fallbackItem;
      }

      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return SpecialCareItem.fromJson(decoded);
      }
      if (decoded is Map) {
        return SpecialCareItem.fromJson(Map<String, dynamic>.from(decoded));
      }

      throw Exception('Unexpected special care response: $body');
    }

    throw Exception(
      'Failed to create special care item ($statusCode): $responseBody',
    );
  }
}
