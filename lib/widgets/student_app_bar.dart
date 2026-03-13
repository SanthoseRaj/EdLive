import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:school_app/screens/students/student_profile_page.dart';
import 'package:school_app/screens/students/student_notifiction_page.dart';

// ---------------- SERVICE ----------------
class StudentService {
  static const baseUrl = "https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api";

  static Future<String?> getProfileImage(int studentId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("auth_token");

      final response = await http.get(
        Uri.parse("$baseUrl/student/students/$studentId"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['profile_img'] != null) {
          return "http://schoolmanagement.canadacentral.cloudapp.azure.com${data['profile_img']}";
        }
      }
    } catch (_) {}
    return null; // fallback
  }

  static Future<int?> getLoggedInStudentId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt("student_id"); // make sure you save this during login
  }
}

// ---------------- WIDGET ----------------
class StudentAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onMenuPressed;
  final VoidCallback? onProfileTap;

  StudentAppBar({super.key, this.onMenuPressed, this.onProfileTap});

  @override
  Widget build(BuildContext context) {
    return PreferredSize(
      preferredSize: preferredSize,
      child: FutureBuilder<Map<String, dynamic>?>(
        future: _getSelectedChildData(),
        builder: (context, snapshot) {
          final childData = snapshot.data;
          final studentId = childData?['id'];
          final profileImgUrl = childData?['image'];

          return AppBar(
            backgroundColor: Colors.white,
            automaticallyImplyLeading: false,
            leading: Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu, color: Colors.black),
                onPressed:
                    onMenuPressed ?? () => Scaffold.of(context).openDrawer(),
              ),
            ),
          title: Row(
  children: [
    const Text('Ed',
        style: TextStyle(
            color: Colors.indigo,
            fontWeight: FontWeight.bold,
            fontSize: 24)),
    const Text('Live',
        style: TextStyle(
            color: Colors.lightBlue,
            fontWeight: FontWeight.bold,
            fontSize: 24)),
    const Spacer(),

    // 🔹 Notification icon navigates to StudentNotificationPage
    GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const StudentNotificationPage(),
          ),
        );
      },
      child: SvgPicture.asset(
        'assets/icons/notification.svg',
        height: 24,
        width: 24,
        color: Colors.black,
      ),
    ),

    const SizedBox(width: 16),

    // 🔹 Profile avatar
    GestureDetector(
      onTap: onProfileTap ??
          () {
            if (studentId == null) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => StudentProfilePage(studentId: studentId),
              ),
            );
          },
      child: CircleAvatar(
        radius: 18,
        backgroundColor: const Color(0xFF2E99EF),
        backgroundImage: profileImgUrl != null && profileImgUrl != ''
            ? NetworkImage(profileImgUrl)
            : null,
        child: profileImgUrl == null || profileImgUrl == ''
            ? const Icon(Icons.person, color: Colors.white, size: 20)
            : null,
      ),
    ),
  ],
),
  );
        },
      ),
    );
  }

  Future<Map<String, dynamic>?> _getSelectedChildData() async {
    final prefs = await SharedPreferences.getInstance();
    final childString = prefs.getString('selected_child');
    if (childString != null) {
      return jsonDecode(childString);
    }
    return null;
  }

  @override
  Size get preferredSize => const Size.fromHeight(63);
}
