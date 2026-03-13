import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SyllabusItem {
  final int? id;
  final String? title;
  final String? description;
  final int? sequence;

  SyllabusItem({
    this.id,
    this.title,
    this.description,
    this.sequence,
  });

  factory SyllabusItem.fromJson(Map<String, dynamic> json) {
    return SyllabusItem(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      sequence: json['sequence'],
    );
  }
}

class SyllabusTerm {
  final int id;
  final String term;
  final String academicYear;
  final List<SyllabusItem> items;

  SyllabusTerm({
    required this.id,
    required this.term,
    required this.academicYear,
    required this.items,
  });

  factory SyllabusTerm.fromJson(Map<String, dynamic> json) {
    return SyllabusTerm(
      id: json['id'],
      term: json['term'],
      academicYear: json['academic_year'],
      items: (json['items'] as List)
          .map((item) => SyllabusItem.fromJson(item))
          .toList(),
    );
  }
}

class SyllabusService {
  final String baseUrl =
      'https://schoolmanagement.canadacentral.cloudapp.azure.com:443';

  Future<List<SyllabusTerm>> fetchSyllabus(
      int classId, int subjectId, String academicYear) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null) {
      throw Exception("No token found. Please log in again.");
    }

    final url =
        Uri.parse('$baseUrl/api/syllabus/$classId/$subjectId/$academicYear');

    final response = await http.get(
      url,
      headers: {
        "accept": "application/json",
        "Authorization": "Bearer $token", // 👈 attach token
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => SyllabusTerm.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load syllabus: ${response.statusCode}');
    }
  }
}



extension AddItem on SyllabusService {
  Future<void> addSyllabusItem({
    required int syllabusId,
    required String title,
    required String description,
    required int sequence,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null) {
      throw Exception("No token found. Please log in again.");
    }

    final url = Uri.parse('$baseUrl/api/syllabus/items');

    final body = jsonEncode({
      "syllabus_id": syllabusId,
      "title": title,
      "description": description,
      "sequence": sequence,
    });

    final response = await http.post(
      url,
      headers: {
        "accept": "application/json",
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: body,
    );

    if (response.statusCode != 201) {
      throw Exception("Failed to add syllabus item: ${response.body}");
    }
  }
}
