import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/pta_next_meeting_model.dart';
import 'package:school_app/models/class_section.dart';
import 'package:school_app/services/class_section_service.dart';

class PTAService {
  static const String baseUrl = 'https://schoolmanagement.canadacentral.cloudapp.azure.com:443';

  Future<List<PTAMeeting>> getUpcomingMeetings() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    // Fetch meetings
    final response = await http.get(
      Uri.parse('$baseUrl/api/pta/meetings/upcoming'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch upcoming meetings');
    }

    final List<dynamic> data = json.decode(response.body);
    List<PTAMeeting> meetings = data.map((json) => PTAMeeting.fromJson(json)).toList();

    // Fetch class sections from existing service
    List<ClassSection> classes = await ClassService().fetchClassSections();

    // Map class IDs to class names
// Map class IDs to class names
for (var meeting in meetings) {
  meeting.classNames = meeting.classIds
      .map((id) => classes.firstWhere(
            (c) => c.id == id,  // <-- use 'id' instead of 'classId'
            orElse: () => ClassSection(id: id, className: 'Unknown', section: ''),
          ).fullName)
      .toList();
}


    return meetings;
  }
}
