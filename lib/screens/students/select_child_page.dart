import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:school_app/widgets/student_app_bar.dart';
import 'student_menu_drawer.dart';
import 'student_dashboard.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;




class SelectChildPage extends StatefulWidget {
  const SelectChildPage({super.key});

  @override
  State<SelectChildPage> createState() => _SelectChildPageState();
}

class _SelectChildPageState extends State<SelectChildPage> {
  List<Map<String, dynamic>> children = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchChildren();
  }

  Future<void> fetchChildren() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token'); // ⚠️ Ensure token is saved at login

    final response = await http.get(
      Uri.parse('https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api/student/parents/children'),
      headers: {
        'accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      setState(() {
children = data.map<Map<String, dynamic>>((child) {
  return {
    'id': child['id'],
    'user_id': child['user_id'],
    'name': child['full_name'],
    'image': child['profile_img'] != null
        ? 'https://schoolmanagement.canadacentral.cloudapp.azure.com:443${child['profile_img']}'
        : '',
    'class': child['class_name'] ?? '',  // 👈 show class name instead of student_id
    'class_id': child['class_id'],
    'notification': 0,
  };
}).toList();
  isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
      debugPrint('Failed to fetch children: ${response.body}');
    }
  }

 @override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.white,
    appBar:  StudentAppBar(),
    drawer: const StudentMenuDrawer(),
    body: isLoading
        ? const Center(child: CircularProgressIndicator())
        : children.isEmpty
            ? const Center(child: Text("No children found"))
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: children.map((child) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: GestureDetector(
                        onTap: () async {
                          SharedPreferences prefs = await SharedPreferences.getInstance();
                          await prefs.setString('selected_child', jsonEncode(child));
                          await prefs.setInt('student_id', child['id']);
                          await prefs.setInt('class_id', child['class_id']);

                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => StudentDashboardPage(childData: child),
                            ),
                          );
                        },
                        child: Stack(
                          alignment: Alignment.topRight,
                          children: [
                            Center(
                              child: Column(
                                children: [
                                  Stack(
                                    children: [
                                      ClipOval(
                                        child: child['image'] != null && child['image'] != ''
                                            ? Image.network(
                                                child['image'],
                                                width: 160,
                                                height: 160,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) {
                                                  return Container(
                                                    width: 160,
                                                    height: 160,
                                                    color: Colors.grey.shade300,
                                                    child: const Icon(Icons.person, size: 50, color: Colors.white),
                                                  );
                                                },
                                              )
                                            : Container(
                                                width: 160,
                                                height: 160,
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade300,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(Icons.person, size: 50, color: Colors.white),
                                              ),
                                      ),
                                      if (child['notification'] > 0)
                                        Positioned(
                                          right: 4,
                                          top: 4,
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: const BoxDecoration(
                                              color: Colors.purple,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Text(
                                              child['notification'].toString(),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    child['name'],
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E266D),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'ID No. ${child['id']}   |   Class: ${child['class']}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
  );
}
}
