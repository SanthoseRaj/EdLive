import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart'; // For MediaType
import 'package:shared_preferences/shared_preferences.dart';

class TeacherProfileService {
  final String baseUrl =
      "https://schoolmanagement.canadacentral.cloudapp.azure.com:443";

  /// Uploads new profile image for the staff
  Future<String?> updateProfileImage({required int staffId, required File imageFile}) async {
    try {
      if (!imageFile.existsSync()) {
        throw Exception("Selected file does not exist");
      }

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) {
        throw Exception("No auth token found");
      }

      final url = Uri.parse("$baseUrl/api/staff/staff/$staffId/image");
      final request = http.MultipartRequest("PATCH", url);

      request.headers.addAll({
        "Authorization": "Bearer $token",
        "Accept": "application/json",
      });

      request.files.add(await http.MultipartFile.fromPath(
        'profileImage',
        imageFile.path,
        contentType: MediaType('image', 'jpeg'), // or 'png' if your image
      ));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print("Response status: ${response.statusCode}");
      print("Response body: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['profileImage'];
      } else if (response.statusCode == 400 || response.statusCode == 415) {
        throw Exception("Invalid file or file type");
      } else {
        throw Exception(
            "Failed to upload image (${response.statusCode}): ${response.body}");
      }
    } catch (e, st) {
      print("Error stack: $st");
      throw Exception("Error uploading profile image: $e");
    }
  }
}
