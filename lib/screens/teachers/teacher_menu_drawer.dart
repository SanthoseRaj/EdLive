import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'package:school_app/screens/login_page.dart';
import 'package:school_app/services/session_service.dart';

import 'teacher_achivement_page.dart';
import 'teacher_report_page.dart';
import 'teacher_payments_page.dart';
import 'teacher_transport.dart';
import 'teacher_message_page.dart';
import 'teacher_pta_page.dart';
import 'teacher_add_library_book_page.dart';
import 'teacher_specialcare_page.dart';
import 'teacher_co_curricular_page.dart';
import 'teacher_resource_page.dart';
import 'teacher_quick_notes.dart';

class MenuDrawer extends StatefulWidget {
  const MenuDrawer({super.key});

  @override
  State<MenuDrawer> createState() => _MenuDrawerState();
}

class _MenuDrawerState extends State<MenuDrawer> {
  int _selectedIndex = -1;

  final List<Map<String, dynamic>> _menuItems = [
    {
      'icon': 'achievements.svg',
      'label': 'Achievements',
      'route': '/achievements',
    },
    {'icon': 'todo.svg', 'label': 'My to-do list', 'route': '/todo'},
    {'icon': 'reports.svg', 'label': 'Reports', 'route': '/reports'},
    {'icon': 'attendance.svg', 'label': 'Attendance', 'route': '/attendance'},
    {'icon': 'class_time.svg', 'label': 'Class & Time', 'route': '/classtime'},
    {'icon': 'payments.svg', 'label': 'Payments', 'route': '/payments'},
    {'icon': 'exams.svg', 'label': 'Exams', 'route': '/exams'},
    {'icon': 'transport.svg', 'label': 'Transport', 'route': '/transport'},
    {'icon': 'message.svg', 'label': 'Message', 'route': '/message'},
    {'icon': 'events.svg', 'label': 'Events & Holidays', 'route': '/events'},
    {'icon': 'pta.svg', 'label': 'PTA', 'route': '/pta'},
    {'icon': 'library.svg', 'label': 'Library', 'route': '/library'},
    {'icon': 'syllabus.svg', 'label': 'Syllabus', 'route': '/syllabus'},
    {
      'icon': 'special_care.svg',
      'label': 'Special care',
      'route': '/special_care',
    },
    {
      'icon': 'co_curricular.svg',
      'label': 'Co curricular activities',
      'route': '/co_curricular',
    },
    {
      'icon': 'quick_notes.svg',
      'label': 'Quick notes',
      'route': '/quick_notes',
    },
    {'icon': 'resources.svg', 'label': 'Resources', 'route': '/resources'},
    {'icon': 'school.svg', 'label': 'My School', 'route': '/school'},
    {'icon': 'calendar.svg', 'label': 'Calendar', 'route': '/calendar'},
    {'icon': 'settings.svg', 'label': 'Settings', 'route': '/settings'},
    {'icon': 'help.svg', 'label': 'Help', 'route': '/help'},
    {'icon': 'terms.svg', 'label': 'Terms and conditions', 'route': '/terms'},
    {'icon': 'logout.svg', 'label': 'Logout', 'route': '/'},
  ];

  Future<void> _handleLogout() async {
    final authToken = await SessionService.prepareLogout();

    if (!mounted) {
      return;
    }

    unawaited(SessionService.notifyServerLogout(authToken));

    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _menuItems.length,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemBuilder: (context, index) {
                  final item = _menuItems[index];
                  final isSelected = _selectedIndex == index;

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF29ABE2)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        hoverColor: Colors.transparent,
                        splashFactory: NoSplash.splashFactory,
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
                          item['label'],
                          style: const TextStyle(color: Colors.white),
                        ),
                        onTap: () async {
                          setState(() => _selectedIndex = index);

                          if (item['label'] == 'Logout') {
                            await _handleLogout();
                          } else if (item['route'] == '/achievements') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const TeacherAchievementPage(),
                              ),
                            );
                          } else if (item['route'] == '/reports') {
                            // ✅ Add this
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const TeacherReportPage(),
                              ),
                            );
                          } else if (item['route'] == '/payments') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const TeacherPaymentsPage(),
                              ),
                            );
                          } else if (item['route'] == '/transport') {
                            final prefs = await SharedPreferences.getInstance();
                            final userDataString = prefs.getString('user_data');
                            int staffId = 0;

                            if (userDataString != null) {
                              final userData = json.decode(userDataString);
                              if (userData['staffid'] != null &&
                                  userData['staffid'].isNotEmpty) {
                                staffId =
                                    userData['staffid'][0]; // first staffId
                              }
                            }

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TransportPage(
                                  staffId: staffId,
                                  // academicYear: academicYear,
                                ),
                              ),
                            );
                          } else if (item['route'] == '/message') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const TeacherMessagePage(),
                              ),
                            );
                          } else if (item['route'] == '/pta') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const TeacherPTAPage(),
                              ),
                            );
                          } else if (item['route'] == '/library') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const AddLibraryBookPage(),
                              ),
                            );
                          } else if (item['route'] == '/special_care') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SpecialCarePage(),
                              ),
                            );
                          } else if (item['route'] == '/co_curricular') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const CoCurricularActivitiesPage(),
                              ),
                            );
                          } else if (item['route'] == '/resources') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const TeacherResourcePage(),
                              ),
                            );
                          } else if (item['route'] == '/quick_notes') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const TeacherQuickNotesPage(),
                              ),
                            );
                          } else if ([
                            '/todo',
                            '/classtime',
                            '/settings',
                            '/attendance',
                            '/exams',
                            '/syllabus',
                            '/events',
                          ].contains(item['route'])) {
                            Navigator.pushNamed(context, item['route']);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${item['label']} page coming soon.',
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
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
}
