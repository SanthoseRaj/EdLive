import 'dart:convert';
import 'package:http/http.dart' as http;

class MessageService {
  static Future<bool> sendMessage({
    required String token,
    required int studentId,
    required String messageText,
    bool isAppreciation = true,
    bool isMeetingRequest = false,
    DateTime? meetingDate,
    required List<String> channels, // ['whatsapp','sms','email']
  }) async {
    final url = Uri.parse('https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api/messages');

    final body = {
      "student_id": studentId,
      "message_text": messageText,
      "is_appreciation": isAppreciation,
      "is_meeting_request": isMeetingRequest,
      "meeting_date": meetingDate?.toIso8601String() ?? DateTime.now().toIso8601String(),
      "channels": channels,
    };

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 201) {
      return true;
    } else {
      print('Error sending message: ${response.statusCode} - ${response.body}');
      return false;
    }
  }
}
