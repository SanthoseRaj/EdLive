import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../models/transport_model.dart';

class TransportService {
  static const String baseUrl =
      'https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api';

  Future<Transport?> getTransportDetails(int staffId, String academicYear) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    final url = Uri.parse('$baseUrl/transport/staff/$staffId/$academicYear');

    final response = await http.get(
      url,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return Transport.fromJson(data);
    } else {
      throw Exception('Failed to load transport details');
    }
  }
}
