import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/student_library_book.dart';
import '../models/student_library_copy.dart';

class StudentLibraryCheckoutService {
  final String baseUrl =
      'https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api/library';

  Future<List<StudentLibraryBook>> fetchAllBooks() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    final response = await http.get(
      Uri.parse('$baseUrl/books'),
      headers: {'Authorization': 'Bearer $token', 'accept': 'application/json'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List booksJson = data['data'];
      return booksJson.map((e) => StudentLibraryBook.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load books: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> fetchBookDetails(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    final response = await http.get(
      Uri.parse('$baseUrl/books/$id'),
      headers: {'Authorization': 'Bearer $token', 'accept': 'application/json'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final book = StudentLibraryBook.fromJson(data['data']);
      final copiesJson = data['data']['copies'] as List;
      final copies = copiesJson
          .map((e) => StudentLibraryCopy.fromJson(e))
          .toList();
      return {'book': book, 'copies': copies};
    } else {
      throw Exception('Failed to load book details: ${response.body}');
    }
  }

  Future<void> checkoutBook({
    required int bookCopyId,
    required int userId,
    required String checkoutDate,
    required String dueDate,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    if (token.isEmpty) {
      throw Exception('Login session expired. Please login again.');
    }

    final memberId = await _resolveActiveMemberId(userId: userId, token: token);

    final response = await http.post(
      Uri.parse('$baseUrl/checkouts'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'accept': 'application/json',
      },
      body: json.encode({
        'book_copy_id': bookCopyId,
        'member_id': memberId,
        'checkout_date': checkoutDate,
        'due_date': dueDate,
      }),
    );

    final responseBody = _decodeBody(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final success = responseBody is Map<String, dynamic>
          ? responseBody['success']
          : null;
      if (success == false) {
        throw Exception(
          _extractMessage(responseBody) ?? 'Checkout failed. Please try again.',
        );
      }
      return;
    }

    throw Exception(
      _extractMessage(responseBody) ??
          'Checkout failed (${response.statusCode}). Please try again.',
    );
  }

  Future<int> _resolveActiveMemberId({
    required int userId,
    required String token,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/members'),
      headers: {'Authorization': 'Bearer $token', 'accept': 'application/json'},
    );

    if (response.statusCode != 200) {
      throw Exception('Unable to verify library membership.');
    }

    final responseBody = _decodeBody(response.body);
    final members = _extractMembers(responseBody);

    Map<String, dynamic>? member;
    for (final item in members) {
      final itemUserId = _asInt(item['user_id']);
      final isActive = _asBool(item['is_active']) ?? true;
      if (itemUserId == userId && isActive) {
        member = item;
        break;
      }
    }

    final memberId = _asInt(member?['id']);
    if (memberId == null || memberId <= 0) {
      throw Exception('No active library membership found for this student.');
    }

    return memberId;
  }

  dynamic _decodeBody(String body) {
    if (body.isEmpty) {
      return null;
    }

    try {
      return json.decode(body);
    } catch (_) {
      return null;
    }
  }

  List<Map<String, dynamic>> _extractMembers(dynamic body) {
    final rawData = body is Map<String, dynamic> ? body['data'] : body;
    if (rawData is! List) {
      return const [];
    }

    return rawData
        .whereType<Map>()
        .map(
          (item) => item.map<String, dynamic>((key, value) {
            return MapEntry(key.toString(), value);
          }),
        )
        .toList();
  }

  String? _extractMessage(dynamic body) {
    if (body is Map<String, dynamic>) {
      final message = body['message'] ?? body['error'];
      if (message != null && message.toString().trim().isNotEmpty) {
        return message.toString();
      }
    }
    return null;
  }

  int? _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '');
  }

  bool? _asBool(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }

    final normalized = value.toString().trim().toLowerCase();
    if (normalized == 'true' || normalized == '1') {
      return true;
    }
    if (normalized == 'false' || normalized == '0') {
      return false;
    }
    return null;
  }
}
