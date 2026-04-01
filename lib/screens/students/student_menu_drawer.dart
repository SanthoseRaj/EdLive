import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:convert';

import 'package:restart_app/restart_app.dart';
import 'package:school_app/config/config.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'student_timetable.dart';
import 'student_attendance_page.dart';
import 'student_exams_screen.dart';
import 'student_syllabus_page.dart'; // ✅ Adjust the path if needed
import 'student_events_holidays_page.dart'; // Adjust the path as needed
import 'student_school_bus_page.dart';
import 'student_payments_page.dart';
import 'student_report_page.dart';
import 'student_achievement_page.dart';

class StudentMenuDrawer extends StatefulWidget {
  const StudentMenuDrawer({super.key});

  @override
  State<StudentMenuDrawer> createState() => _StudentMenuDrawerState();
}

class _StudentMenuDrawerState extends State<StudentMenuDrawer> {
  int? selectedIndex;

  final List<Map<String, String>> _menuItems = const [
    {'icon': 'todo.svg', 'label': 'My to do list', 'route': '/student-todo'},
    {'icon': 'timetable.svg', 'label': 'Timetable', 'route': '/timetable'},
    {'icon': 'attendance.svg', 'label': 'Attendance', 'route': '/attendance'},
    {'icon': 'exams.svg', 'label': 'Exams', 'route': '/exams'},
    {'icon': 'payments.svg', 'label': 'Fees', 'route': '/fees'},
    {'icon': 'school_bus.svg', 'label': 'School bus', 'route': '/transport'},
    {'icon': 'syllabus.svg', 'label': 'Syllabus', 'route': '/syllabus'},
    {'icon': 'events.svg', 'label': 'Events & Holidays', 'route': '/events'},
    {'icon': 'reports.svg', 'label': 'Reports', 'route': '/reports'},
    {
      'icon': 'achievements.svg',
      'label': 'Achievements',
      'route': '/achievements',
    },
    {'icon': 'school.svg', 'label': 'My School', 'route': '/school'},
    {'icon': 'calendar.svg', 'label': 'Calendar', 'route': '/calendar'},
    {'icon': 'settings.svg', 'label': 'Settings', 'route': '/student-settings'},
    {'icon': 'logout.svg', 'label': 'Logout', 'route': '/'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _menuItems.length,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemBuilder: (context, index) {
                  final item = _menuItems[index];
                  final isSelected = index == selectedIndex;

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF29ABE2)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListTile(
                      leading: SvgPicture.asset(
                        'assets/icons/${item['icon']}',
                        height: 24,
                        width: 24,
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                      ),
                      title: Text(
                        item['label'] ?? '',
                        style: const TextStyle(color: Colors.white),
                      ),
                      onTap: () async {
                        setState(() {
                          selectedIndex = index;
                        });

                        final prefs = await SharedPreferences.getInstance();

                        if (item['label'] == 'Logout') {
                          // 1. Clear all stored data
                          final prefs = await SharedPreferences.getInstance();
                          await prefs
                              .clear(); // Clear everything, not just auth_token

                          // 2. Navigate to login page and remove all previous routes
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            '/', // Replace with your login route if different
                            (route) => false,
                          );

                          // 3. (Optional) Force full app restart to ensure no leftover state
                          await Restart.restartApp(); // Requires restart_app package
                        } else if (item['label'] == 'Timetable') {
                          final selectedChildString = prefs.getString(
                            'selected_child',
                          );
                          if (selectedChildString == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "No child selected. Please select a child.",
                                ),
                              ),
                            );
                            return;
                          }

                          final selectedChild = jsonDecode(selectedChildString);
                          final studentId = selectedChild['id'].toString();
                          if (AppConfig.academicYear.isEmpty) {
                            AppConfig.setAcademicYear();
                          }

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => StudentTimeTablePage(
                                studentId: studentId,
                              ),
                            ),
                          );
                        } else if (item['label'] == 'Attendance') {
                          final studentId = prefs.getInt('student_id');
                          if (studentId != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    StudentAttendancePage(studentId: studentId),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Student ID not found. Please login again.",
                                ),
                              ),
                            );
                          }
                        } else if (item['label'] == 'My to do list') {
                          Navigator.pushNamed(context, '/student-todo');
                        } else if (item['label'] == 'Exams') {
                          final studentIdInt = prefs.getInt('student_id');
                          if (studentIdInt == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Student ID not found'),
                              ),
                            );
                            return;
                          }
                          final studentId = studentIdInt.toString();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  StudentExamsScreen(studentId: studentId),
                            ),
                          );
                        } else if (item['label'] == 'Syllabus') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const StudentSyllabusPage(),
                            ),
                          );
                        } else if (item['label'] == 'Events & Holidays') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const EventsHolidaysPage(
                                startInMonthView: true,
                              ),
                            ),
                          );
                        } else if (item['label'] == 'School bus') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const StudentSchoolBusPage(),
                            ),
                          );
                        } else if (item['label'] == 'Settings') {
                          Navigator.pushNamed(context, '/student-settings');
                        } else if (item['label'] == 'Fees') {
                          // 👇 Add this new navigation block
                          final prefs = await SharedPreferences.getInstance();
                          final studentIdInt = prefs.getInt('student_id');
                          if (studentIdInt == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Student ID not found'),
                              ),
                            );
                            return;
                          }

                          final studentId = studentIdInt.toString();

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  StudentPaymentsPage(studentId: studentId),
                            ),
                          );
                        } else if (item['label'] == 'Reports') {
                          final prefs = await SharedPreferences.getInstance();
                          final studentIdInt = prefs.getInt('student_id');
                          if (studentIdInt == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Student ID not found'),
                              ),
                            );
                            return;
                          }

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  StudentReportPage(studentId: studentIdInt),
                            ),
                          );
                        } else if (item['label'] == 'Achievements') {
                          final prefs = await SharedPreferences.getInstance();
                          final studentIdInt = prefs.getInt('student_id');
                          final classId = prefs.getInt(
                            'class_id',
                          ); // make sure class_id is saved in SharedPreferences

                          if (studentIdInt == null || classId == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Student ID or Class ID not found',
                                ),
                              ),
                            );
                            return;
                          }

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  StudentAchievementPage(classId: classId),
                            ),
                          );
                        }
                      },
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
}
