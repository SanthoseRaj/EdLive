import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../models/transport_model.dart';
import '../config/config.dart'; // ✅ IMPORTANT

class TransportService {
  Future<Transport?> getTransportDetails(int staffId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    final academicYear = AppConfig.academicYear; // ✅ GLOBAL

    print("StaffId: $staffId");
    print("AcademicYear: $academicYear");

    final url = Uri.parse(
      '${AppConfig.baseUrl}/transport/staff/$staffId/$academicYear',
    );

    print("API URL: $url");

    final response = await http.get(
      url,
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );

    print("Status Code: ${response.statusCode}");
    print("Response: ${response.body}");

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return Transport.fromJson(data);
    } else if (response.statusCode == 404) {
      return null;
    } else {
      throw Exception('Failed to load transport details');
    }
  }
}
