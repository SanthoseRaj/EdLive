import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/class_section.dart';

class ClassService {
  final String baseUrl = 'https://schoolmanagement.canadacentral.cloudapp.azure.com:443';

  Future<List<ClassSection>> fetchClassSections() async {
    final url = Uri.parse('$baseUrl/api/master/classes');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => ClassSection.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load class sections');
    }
  }
}
