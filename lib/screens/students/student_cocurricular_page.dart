import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:school_app/screens/students/student_menu_drawer.dart';
import 'package:school_app/widgets/student_app_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';


class StudentActivitiesPage extends StatefulWidget {
  final int studentId;
  final String academicYear;

  const StudentActivitiesPage({
    super.key,
    required this.studentId,
    required this.academicYear,
  });

  @override
  State<StudentActivitiesPage> createState() => _StudentActivitiesPageState();
}


class _StudentActivitiesPageState extends State<StudentActivitiesPage> {
  bool isLoading = true;
  List<dynamic> activities = [];
  String? errorMessage;
  Map<String, dynamic>? _selectedActivity;

  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    fetchStudentActivities();

    // Poll every 15 seconds (adjust as needed)
    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      fetchStudentActivities(autoUpdate: true);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }


Future<void> fetchStudentActivities({bool autoUpdate = false}) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("auth_token");

    if (token == null) {
      if (!autoUpdate) setState(() => errorMessage = "No auth token found");
      return;
    }

    final url =
        "https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api/co-curricular/student-activities"
        "?studentId=${widget.studentId}&academicYear=${widget.academicYear}";

    final response = await http.get(
      Uri.parse(url),
      headers: {
        "Authorization": "Bearer $token",
        "accept": "application/json",
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);

      if (autoUpdate) {
        // 🔹 Only update if new data is different
        if (!listEquals(activities, data)) {
          setState(() => activities = data);
        }
      } else {
        setState(() {
          activities = data;
          isLoading = false;
        });
      }
    } else {
      if (!autoUpdate) {
        setState(() {
          errorMessage = "Failed to fetch activities: ${response.statusCode}";
          isLoading = false;
        });
      }
    }
  } catch (e) {
    if (!autoUpdate) {
      setState(() {
        errorMessage = "Error: $e";
        isLoading = false;
      });
    }
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: StudentAppBar(),
      drawer: StudentMenuDrawer(),
body: Container(
  color: const Color(0xFFDBD88A),
  padding: const EdgeInsets.all(16),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // 🔙 Back button
      GestureDetector(
        onTap: () {
          if (_selectedActivity != null) {
            setState(() => _selectedActivity = null);
          } else {
            Navigator.pop(context);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: const Text(
            '< Back',
            style: TextStyle(color: Colors.black, fontSize: 16),
          ),
        ),
      ),
      const SizedBox(height: 8),

      // 🔹 Page title below back button
     // 🔹 Page title with icon below back button
Row(
  children: [
    Container(
      width: 35,
      height: 35,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFF2E3192),
        borderRadius: BorderRadius.circular(6),
      ),
      child: SvgPicture.asset(
        'assets/icons/co_curricular.svg', // ✅ your SVG icon
        color: Colors.white,
      ),
    ),
    const SizedBox(width: 12),
    const Text(
      'Co curricular activities',
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Color(0xFF2E3192),
      ),
    ),
  ],
),
const SizedBox(height: 12),

      const SizedBox(height: 12),

      // 🔹 List or Detail view
      Expanded(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage != null
                ? Center(child: Text(errorMessage!))
                : activities.isEmpty
                    ? const Center(child: Text("No activities found"))
                    : _selectedActivity != null
                        ? _buildActivityDetail(_selectedActivity!)
                        : ListView.builder(
                            itemCount: activities.length,
                            itemBuilder: (context, index) {
                              final activity = activities[index];
                              return GestureDetector(
                                onTap: () {
                                  setState(() => _selectedActivity = activity);
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 6,
                                        offset: Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        activity["activity_name"] ?? "Unknown Activity",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          color: Color(0xFF2E3192),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        "Category: ${activity["category_name"]}",
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "Class: ${activity["class_name"]}",
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
      ),
    ],
  ),
),
 );
  }

  Widget _buildActivityDetail(Map<String, dynamic> activity) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))
        ],
      ),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
            child: Text(
              activity["activity_name"] ?? "No title",
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E3192),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Category: ${activity["category_name"]}',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Class: ${activity["class_name"]}',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Student: ${activity["student_name"]}',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Academic Year: ${activity["academic_year"]}',
            style: const TextStyle(fontSize: 16),
          ),
        ]),
      ),
    );
  }
}
