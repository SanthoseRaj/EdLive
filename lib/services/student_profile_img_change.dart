import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class StudentProfileImageUploader {
  File? selectedImage;

  // Pick image from gallery
  Future<void> pickImage(int studentId, {required VoidCallback onSuccess, required VoidCallback onError}) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        selectedImage = File(pickedFile.path);
        await uploadImage(studentId, onSuccess: onSuccess, onError: onError);
      }
    } catch (e) {
      debugPrint('❌ Error picking image: $e');
      onError();
    }
  }

  // Upload image to API
  Future<void> uploadImage(int studentId, {required VoidCallback onSuccess, required VoidCallback onError}) async {
    if (selectedImage == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';

      final url = Uri.parse(
        'https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api/student/students/\$studentId/image',
      );

      final request = http.MultipartRequest('PATCH', url)
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(await http.MultipartFile.fromPath('profileImage', selectedImage!.path));

      final response = await request.send();

      if (response.statusCode == 200) {
        debugPrint('✅ Image updated successfully');
        onSuccess();
      } else {
        debugPrint('❌ Image upload failed: \${response.statusCode}');
        onError();
      }
    } catch (e) {
      debugPrint('❌ Error uploading image: \$e');
      onError();
    }
  }
}
