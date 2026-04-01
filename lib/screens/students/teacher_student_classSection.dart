// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import 'package:school_app/models/teacher_student_classsection.dart';

// class StudentService {
//   Future<List<StudentClassSection>> fetchStudents() async {
//     final url = Uri.parse('${AppConfig.baseUrl}/staff/staff/students/list');

//     final response = await http.get(
//       url,
//       headers: {'accept': '*/*'},
//     );

//     if (response.statusCode == 200) {
//       List<dynamic> data = jsonDecode(response.body);
//       return data.map((json) => StudentClassSection.fromJson(json)).toList();
//     } else {
//       throw Exception('Failed to load students');
//     }
//   }
// }
