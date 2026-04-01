import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:school_app/config/config.dart';

class StudentProfileImageUploader {
  static const String _documentedFieldName = 'StudentprofileImage';
  static const String _legacyFieldName = 'profileImage';
  static const Map<String, String> _mimeTypeByExtension = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'gif': 'image/gif',
    'webp': 'image/webp',
    'bmp': 'image/bmp',
    'heic': 'image/heic',
    'heif': 'image/heif',
    'tif': 'image/tiff',
    'tiff': 'image/tiff',
    'avif': 'image/avif',
  };

  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;

  String? get selectedImageName => _selectedImage?.name;

  Future<bool> selectImage() async {
    try {
      _resetSelection();
      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
      );

      if (pickedFile == null) {
        return false;
      }

      final pickedBytes = await pickedFile.readAsBytes();
      final pickedPath = pickedFile.path.trim();

      if (pickedBytes.isEmpty && pickedPath.isEmpty) {
        throw Exception('Selected image could not be read');
      }

      _selectedImage = pickedFile;
      _selectedImageBytes = pickedBytes;
      return true;
    } catch (e) {
      _resetSelection();
      throw Exception('Image pick failed: $e');
    }
  }

  Future<String?> uploadImage(int studentId) async {
    if (_selectedImage == null) {
      return null;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    if (token.isEmpty) {
      _resetSelection();
      throw Exception('No auth token found');
    }

    final url = AppConfig.apiUri('/student/students/$studentId/image');
    final attempts = <({String method, String fieldName})>[
      (method: 'PATCH', fieldName: _documentedFieldName),
      (method: 'PATCH', fieldName: _legacyFieldName),
      (method: 'POST', fieldName: _documentedFieldName),
      (method: 'POST', fieldName: _legacyFieldName),
    ];
    final failures = <String>[];

    for (final attempt in attempts) {
      try {
        return await _sendUploadRequest(
          method: attempt.method,
          fieldName: attempt.fieldName,
          url: url,
          token: token,
        );
      } catch (error) {
        final normalizedError = error.toString().replaceFirst(
          'Exception: ',
          '',
        );
        failures.add(
          '${attempt.method} ${attempt.fieldName}: $normalizedError',
        );
        debugPrint(
          'Student image upload failed (${attempt.method} ${attempt.fieldName}): $error',
        );
      }
    }

    _resetSelection();
    throw Exception(failures.join(' | '));
  }

  MediaType? _resolveMediaType() {
    final fileName = _selectedImage?.name ?? 'image.jpg';
    final mimeType =
        lookupMimeType(
          fileName,
          headerBytes: _selectedImageBytes?.take(32).toList(),
        ) ??
        _mimeTypeByExtension[_fileExtension(fileName)];

    if (mimeType == null || !mimeType.contains('/')) {
      return null;
    }

    final parts = mimeType.split('/');
    return MediaType(parts[0], parts[1]);
  }

  Future<String?> _sendUploadRequest({
    required String method,
    required String fieldName,
    required Uri url,
    required String token,
  }) async {
    final request = http.MultipartRequest(method, url);
    request.headers.addAll({
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    });

    request.files.add(await _buildMultipartFile(fieldName));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    final statusCode = response.statusCode;

    if (statusCode == 200 ||
        statusCode == 201 ||
        statusCode == 202 ||
        statusCode == 204) {
      return _parseSuccessfulUploadResponse(response.body);
    }

    throw Exception(_extractErrorMessage(statusCode, response.body));
  }

  String? _extractProfilePath(dynamic decoded) {
    if (decoded is String) {
      final trimmedValue = decoded.trim();
      if (_looksLikeProfilePath(trimmedValue)) {
        return trimmedValue;
      }
      return null;
    }

    if (decoded is Map<String, dynamic>) {
      final directPath =
          decoded['profile_img'] ??
          decoded['profileImage'] ??
          decoded['profile_image'] ??
          decoded['image'];
      if (directPath != null && directPath.toString().trim().isNotEmpty) {
        return directPath.toString();
      }

      final data = decoded['data'];
      if (data is Map<String, dynamic>) {
        return _extractProfilePath(data);
      }
    }

    return null;
  }

  String? _parseSuccessfulUploadResponse(String body) {
    final trimmedBody = body.trim();
    if (trimmedBody.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(trimmedBody);
      return _extractProfilePath(decoded) ??
          _extractProfilePathFromPlainText(trimmedBody);
    } on FormatException {
      debugPrint(
        'Student profile image upload returned non-JSON success body: $trimmedBody',
      );
      return _extractProfilePathFromPlainText(trimmedBody);
    }
  }

  String? _extractProfilePathFromPlainText(String value) {
    final trimmedValue = value.trim();
    if (_looksLikeProfilePath(trimmedValue)) {
      return trimmedValue;
    }

    final pathMatch = RegExp(
      r'((?:https?:\/\/\S+)|(?:\/(?:content|uploads|data)\/\S+))',
      caseSensitive: false,
    ).firstMatch(trimmedValue);

    if (pathMatch == null) {
      return null;
    }

    final rawCandidate = pathMatch.group(0)?.trim();
    final candidate = rawCandidate == null
        ? null
        : _trimMatchedPathCandidate(rawCandidate);
    if (candidate == null || candidate.isEmpty) {
      return null;
    }

    return _looksLikeProfilePath(candidate) ? candidate : null;
  }

  bool _looksLikeProfilePath(String value) {
    if (value.isEmpty) {
      return false;
    }

    final normalized = value.toLowerCase();
    return normalized.startsWith('http://') ||
        normalized.startsWith('https://') ||
        normalized.startsWith('/') ||
        normalized.contains('/content/') ||
        normalized.contains('/uploads/') ||
        RegExp(
          r'\.(png|jpe?g|gif|webp|bmp|heic|heif|avif|tiff?)(\?.*)?$',
        ).hasMatch(normalized);
  }

  String _trimMatchedPathCandidate(String value) {
    var trimmedValue = value.trim();

    while (trimmedValue.isNotEmpty && "([{'\"".contains(trimmedValue[0])) {
      trimmedValue = trimmedValue.substring(1);
    }

    while (trimmedValue.isNotEmpty &&
        ")]}',\"".contains(trimmedValue[trimmedValue.length - 1])) {
      trimmedValue = trimmedValue.substring(0, trimmedValue.length - 1);
    }

    return trimmedValue;
  }

  String _extractErrorMessage(int statusCode, String body) {
    final trimmedBody = body.trim();
    if (trimmedBody.isEmpty) {
      return 'Image upload failed [$statusCode]';
    }

    try {
      final decoded = jsonDecode(trimmedBody);
      final message = _extractErrorText(decoded);
      if (message != null && message.isNotEmpty) {
        return 'Image upload failed [$statusCode]: $message';
      }
    } on FormatException {
      // Fall back to the raw response body.
    }

    return 'Image upload failed [$statusCode]: $trimmedBody';
  }

  String? _extractErrorText(dynamic decoded) {
    if (decoded is String) {
      return decoded.trim().isEmpty ? null : decoded.trim();
    }

    if (decoded is List) {
      for (final item in decoded) {
        final message = _extractErrorText(item);
        if (message != null && message.isNotEmpty) {
          return message;
        }
      }
      return null;
    }

    if (decoded is Map<String, dynamic>) {
      for (final key in const ['message', 'error', 'detail', 'title']) {
        final value = decoded[key];
        final message = _extractErrorText(value);
        if (message != null && message.isNotEmpty) {
          return message;
        }
      }
    }

    return null;
  }

  Future<http.MultipartFile> _buildMultipartFile(String fieldName) async {
    final contentType = _resolveMediaType();
    final selectedBytes = _selectedImageBytes;
    final fileName = _selectedImage?.name ?? 'student-profile-image.jpg';

    if (selectedBytes != null && selectedBytes.isNotEmpty) {
      return http.MultipartFile.fromBytes(
        fieldName,
        selectedBytes,
        filename: fileName,
        contentType: contentType,
      );
    }

    final selectedPath = _selectedImage?.path.trim();
    if (selectedPath == null || selectedPath.isEmpty) {
      throw Exception('Selected image path is unavailable');
    }

    return http.MultipartFile.fromPath(
      fieldName,
      selectedPath,
      filename: fileName,
      contentType: contentType,
    );
  }

  String _fileExtension(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == fileName.length - 1) {
      return '';
    }

    return fileName.substring(dotIndex + 1).toLowerCase();
  }

  void clearSelection() {
    _resetSelection();
  }

  void _resetSelection() {
    _selectedImage = null;
    _selectedImageBytes = null;
  }
}
