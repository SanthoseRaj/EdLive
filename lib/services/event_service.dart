// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import '../models/event_model.dart';

// class EventService {
//   final String baseUrl = "${AppConfig.baseUrl}";

//   Future<List<Event>> fetchEvents(String token) async {
//     final response = await http.get(
//       Uri.parse('$baseUrl/events'),
//       headers: {
//         'Authorization': 'Bearer $token',
//         'Content-Type': 'application/json',
//       },
//     );

//     if (response.statusCode == 200) {
//       final List<dynamic> data = jsonDecode(response.body);
//       return data.map((e) => Event.fromJson(e)).toList();
//     } else {
//       throw Exception('Failed to load events');
//     }
//   }
// }
