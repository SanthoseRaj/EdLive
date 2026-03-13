// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:school_app/models/student_timetable_model.dart';

// class TimetableService {
//   static const _base =
//       'https://schoolmanagement.canadacentral.cloudapp.azure.com:443';
//   static const _endpoint = '/api/student/students/timetable';

//   Future<List<TimetableDay>> fetchTimetable(int academicYear) async {
//     final prefs = await SharedPreferences.getInstance();
//     final token = prefs.getString('token'); // 👈 your login token key

//     final uri = Uri.parse('$_base$_endpoint/$academicYear');
//     final res = await http.get(
//       uri,
//       headers: {'Authorization': 'Bearer $token'},
//     );

//     if (res.statusCode != 200) {
//       throw Exception('Timetable load failed: ${res.body}');
//     }

//     final List data = jsonDecode(res.body);
//     return data.map((e) => TimetableDay.fromJson(e)).toList();
//   }
// }
