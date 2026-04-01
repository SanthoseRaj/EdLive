import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:school_app/models/student_payment_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:school_app/config/config.dart';

class StudentPaymentService {
  String get baseUrl => AppConfig.baseUrl;

  Future<List<StudentPayment>> fetchStudentPayments(String studentId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    final response = await http.get(
      Uri.parse('$baseUrl/payments/student/$studentId'),
      headers: {'accept': 'application/json', 'Authorization': 'Bearer $token'},
    );

    print("Status Code: ${response.statusCode}");
    print("Response Body: ${response.body}");

    if (response.statusCode == 200) {
      final jsonBody = jsonDecode(response.body);
      final List data = jsonBody['data'];
      return data.map((e) => StudentPayment.fromJson(e)).toList();
    } else {
      throw Exception("Failed to fetch payments: ${response.statusCode}");
    }
  }
}
