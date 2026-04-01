// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import '../models/cocurricular_activity_model.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// class CoCurricularService {
//   static Future<List<CoCurricularActivity>> fetchActivities(int classId, String academicYear) async {
//     final prefs = await SharedPreferences.getInstance();
//     final token = prefs.getString('auth_token') ?? '';

//     final url = Uri.parse(
//       '${AppConfig.baseUrl}/co-curricular/stats?classId=$classId&academicYear=$academicYear',
//     );

//     final response = await http.get(url, headers: {
//       'Content-Type': 'application/json',
//       'Authorization': 'Bearer $token',
//     });

//     if (response.statusCode == 200) {
//       final List<dynamic> data = jsonDecode(response.body);
//       return data.map((json) => CoCurricularActivity.fromJson(json)).toList();
//     } else {
//       throw Exception('Failed to load activities: ${response.statusCode}');
//     }
//   }
// }
