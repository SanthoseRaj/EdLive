import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:school_app/widgets/teacher_app_bar.dart';
import 'teacher_menu_drawer.dart';

  

class StudentDetailPage extends StatefulWidget {
  final int studentId;

  const StudentDetailPage({super.key, required this.studentId});

  @override
  State<StudentDetailPage> createState() => _StudentDetailPageState();
}

class _StudentDetailPageState extends State<StudentDetailPage> {
  Map<String, dynamic>? student;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchStudentData();
  }

  Future<void> fetchStudentData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    final url = Uri.parse(
        'https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api/student/students/${widget.studentId}');

    final response = await http.get(url, headers: {
      'Authorization': 'Bearer $token',
      'accept': '*/*',
    });

    if (response.statusCode == 200) {
      setState(() {
        student = jsonDecode(response.body);
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
          drawer:const MenuDrawer(), 
  appBar: const TeacherAppBar(),
// Optional if you have a drawer
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : student == null
                ? const Center(child: Text("Failed to load student"))
                : Column(
                    children: [
                      // Top Section
                      Container(
                        width: double.infinity,
                        color: const Color(0xFF2E99EF),
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: const Text(
                                '< Back',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Center(
                              child: Column(
                                children: [
                                  CircleAvatar(
                                    radius: 60,
                                    backgroundImage: NetworkImage(
                                        'https://schoolmanagement.canadacentral.cloudapp.azure.com:443${student!['profile_img'] ?? ''}'),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    student!['full_name'] ?? '',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Tabs
                      const TabBar(
                        labelColor: Color(0xFF29ABE2),
                        unselectedLabelColor: Colors.black54,
                        indicatorColor: Color(0xFF29ABE2),
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        tabs: [
                          Tab(text: 'Basic Info'),
                          Tab(text: 'Parent/Guardian'),
                          Tab(text: 'Documents'),
                        ],
                      ),

                      // Tab Views
                      Expanded(
                        child: TabBarView(
                          children: [
                            _buildBasicInfoTab(),
                            _buildParentTab(),
                            _buildDocumentsTab(),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildBasicInfoTab() {
    final basic = student!['basic_info'];
    final school = student!['school_info'];
    final health = student!['health'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoText("Gender:", basic?['gender']),
          _infoText("DOB:", basic?['date_of_birth']?.split('T')[0]),
          _infoText("Blood Group:", basic?['blood_group']),
          _infoText("Contact:", basic?['contact_number']),
          const SizedBox(height: 16),
          const Divider(),
          const Text("School Info", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          _infoText("Admission Date:", school?['admission_date']?.split('T')[0]),
          _infoText("Class Joined:", school?['class_joined']),
          _infoText("Previous School:", school?['prev_school']),
          _infoText("Class Teacher:", school?['class_teacher']),
          const SizedBox(height: 16),
          const Divider(),
          const Text("Health Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          _infoText("Disability:", health?['disability'] == true ? "Yes" : "No"),
          _infoText("Disability Details:", health?['disability_details']),
          _infoText("Disease:", health?['disease'] == true ? "Yes" : "No"),
          _infoText("Disease Details:", health?['disease_details']),
        ],
      ),
    );
  }

  Widget _buildParentTab() {
    final parent = student!['parent'];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _parentCard(
            name: parent?['father_name'] ?? '',
            role: "Father",
            mobile: parent?['father_contact'],
            email: parent?['father_email'],
            address: parent?['father_address'],
            occupation: parent?['father_occupation'],
            age: parent?['father_age'],
          ),
          _parentCard(
            name: parent?['mother_name'] ?? '',
            role: "Mother",
            mobile: parent?['mother_contact'],
            email: parent?['mother_email'],
            address: parent?['mother_address'],
            occupation: parent?['mother_occupation'],
            age: parent?['mother_age'],
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          SizedBox(height: 24),
          Text("Student’s ID/Passport", style: TextStyle(fontWeight: FontWeight.w600)),
          SizedBox(height: 8),
          Text("No: 45675789790898", style: TextStyle(color: Color(0xFF29ABE2))),
          SizedBox(height: 24),
          Text("Parent’s ID/Passport", style: TextStyle(fontWeight: FontWeight.w600)),
          SizedBox(height: 8),
          Text("No: 45675789790898", style: TextStyle(color: Color(0xFF29ABE2))),
        ],
      ),
    );
  }

  Widget _infoText(String title, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text("$title ", style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value ?? 'N/A')),
        ],
      ),
    );
  }

  Widget _parentCard({
    required String name,
    required String role,
    String? age,
    String? occupation,
    String? mobile,
    String? email,
    String? address,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 20, 8, 16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const CircleAvatar(
            radius: 50,
            backgroundColor: Colors.grey,
            child: Icon(Icons.person, color: Colors.white, size: 60),
          ),
          const SizedBox(height: 10),
          Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2E3192))),
          Text("($role)", style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 12),
          _infoText("Age:", age),
          _infoText("Occupation:", occupation),
          _infoText("Mobile:", mobile),
          _infoText("Email:", email),
          const Align(alignment: Alignment.centerLeft, child: Text("Address", style: TextStyle(fontWeight: FontWeight.bold))),
          Align(alignment: Alignment.centerLeft, child: Text(address ?? 'N/A')),
        ],
      ),
    );
  }
}
