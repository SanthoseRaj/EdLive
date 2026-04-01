import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:school_app/config/config.dart';
import 'package:school_app/providers/student_settings_provider.dart';
import 'package:school_app/widgets/student_app_bar.dart';
import 'student_menu_drawer.dart';
import 'student_timetable.dart';
import 'student_attendance_page.dart';
import 'student_exams_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'package:school_app/providers/student_notification_dashboard_provider.dart';

import 'student_syllabus_page.dart';
import 'select_child_page.dart';
import 'student_events_holidays_page.dart';
import 'student_school_bus_page.dart';
import 'teacher_list_page.dart';
import 'student_payments_page.dart';
import 'student_report_page.dart';
import 'student_food_page.dart';
import 'student_achievement_page.dart';
import 'student_messages_page.dart';
import 'student_notifiction_page.dart';
import 'student_cocurricular_page.dart';
import 'student_library_page.dart';
import 'student_quicknotes_page.dart';

class StudentDashboardPage extends StatefulWidget {
  final Map<String, dynamic> childData;
  const StudentDashboardPage({super.key, required this.childData});

  @override
  State<StudentDashboardPage> createState() => _StudentDashboardPageState();
}

class _StudentDashboardPageState extends State<StudentDashboardPage> {
  Timer? _countRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<StudentSettingsProvider>().loadSettings();
    });
    _loadCounts();
    _startCountRefreshTimer();
  }

  @override
  void dispose() {
    _countRefreshTimer?.cancel();
    super.dispose();
  }

  void _startCountRefreshTimer() {
    _countRefreshTimer?.cancel();
    _countRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) {
        return;
      }

      final route = ModalRoute.of(context);
      if (route?.isCurrent != true) {
        return;
      }

      _loadCounts();
    });
  }

  Future<void> _loadCounts() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) {
      return;
    }

    final studentId = _resolveDashboardStudentId(prefs);
    if (studentId != null) {
      await Provider.of<DashboardCountsProvider>(
        context,
        listen: false,
      ).fetchDashboardCounts(studentId);
    }
  }

  Future<T?> _pushAndClearCount<T>({
    required Route<T> route,
    required String itemType,
  }) async {
    await context.read<DashboardCountsProvider>().clearBadgeCount(itemType);
    if (!mounted) {
      return null;
    }
    return Navigator.push(context, route);
  }

  Future<T?> _pushNamedAndClearCount<T extends Object?>(
    String routeName, {
    required String itemType,
    Object? arguments,
  }) async {
    await context.read<DashboardCountsProvider>().clearBadgeCount(itemType);
    if (!mounted) {
      return null;
    }
    return Navigator.pushNamed<T>(context, routeName, arguments: arguments);
  }

  Future<void> _handleBack() async {
    if (!mounted) {
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const SelectChildPage()),
    );
  }

  // Future<void> _loadStudentTodos() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   final token = prefs.getString('auth_token');

  //   if (token != null) {
  //     final provider = Provider.of<StudentTaskProvider>(context, listen: false);
  //     provider.setAuthToken(token);
  //     await provider.fetchStudentTodos(); // ✅ Fetch ToDos from backend
  //   }
  // }

  // ignore: unused_element
  Future<int?> _getStudentId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('student_id'); // 👈 same key you saved in login
  }

  // ignore: unused_element
  String getCurrentAcademicYear() {
    final now = DateTime.now();
    final startYear = now.month >= 6 ? now.year : now.year - 1;
    return '$startYear-${startYear + 1}';
  }

  int? _extractPositiveInt(dynamic value) {
    if (value is int && value > 0) {
      return value;
    }
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null && parsed > 0) {
        return parsed;
      }
    }
    return null;
  }

  int? _resolveDashboardStudentId(SharedPreferences prefs) {
    final childId =
        _extractPositiveInt(widget.childData['id']) ??
        _extractPositiveInt(widget.childData['student_id']) ??
        _extractPositiveInt(widget.childData['studentId']);
    if (childId != null) {
      return childId;
    }

    final selectedChildString = prefs.getString('selected_child');
    if (selectedChildString != null && selectedChildString.isNotEmpty) {
      try {
        final selectedChild = jsonDecode(selectedChildString);
        if (selectedChild is Map<String, dynamic>) {
          final selectedChildId =
              _extractPositiveInt(selectedChild['id']) ??
              _extractPositiveInt(selectedChild['student_id']) ??
              _extractPositiveInt(selectedChild['studentId']);
          if (selectedChildId != null) {
            return selectedChildId;
          }
        }
      } catch (_) {}
    }

    final storedStudentId = prefs.getInt('student_id');
    if (storedStudentId != null && storedStudentId > 0) {
      return storedStudentId;
    }

    return null;
  }

  String? _dashboardSubtitle(
    DashboardCountsProvider counts,
    String itemType, {
    String? fallback,
  }) {
    return counts.subtitleFor(itemType, fallback: fallback);
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.childData;
    final settings = Provider.of<StudentSettingsProvider>(context);
    final counts = Provider.of<DashboardCountsProvider>(context);

    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        await _handleBack();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F4F4),
        appBar: StudentAppBar(),
        drawer: const StudentMenuDrawer(),
        body: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            GestureDetector(
              onTap: _handleBack,
              child: Row(
                children: const [
                  // Icon(Icons.arrow_back, size: 20, color: Colors.blue),
                  SizedBox(width: 4),
                  Text(
                    '< Back',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.black,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                DashboardTile(
                  title: 'Notifications',
                  subtitle: _dashboardSubtitle(
                    counts,
                    'notifications',
                    fallback: 'View your latest notification',
                  ),
                  iconPath: 'assets/icons/notification.svg',
                  color: const Color(0xFFF9F7A5),
                  badgeCount: counts.notifications,
                  onTap: () async {
                    await _pushAndClearCount(
                      itemType: 'notifications',
                      route: MaterialPageRoute(
                        builder: (_) => const StudentNotificationPage(),
                      ),
                    );
                  },
                ),
                if (settings.isVisible('achievements'))
                  DashboardTile(
                    title: 'Achievements',
                    subtitle: _dashboardSubtitle(
                      counts,
                      'achievements',
                      fallback: 'View your latest achievement',
                    ),
                    iconPath: 'assets/icons/achievements.svg',
                    color: const Color(0xFFF7EB7C),
                    badgeCount: counts.achievements, // ✅ dynamic
                    onTap: () async {
                      final prefs = await SharedPreferences.getInstance();
                      final classId = prefs.getInt('class_id') ?? 0;
                      await _pushAndClearCount(
                        itemType: 'achievements',
                        route: MaterialPageRoute(
                          builder: (context) =>
                              StudentAchievementPage(classId: classId),
                        ),
                      );
                    },
                  ),
                DashboardTile(
                  title: 'Home Work',
                  subtitle: _dashboardSubtitle(
                    counts,
                    'todo',
                    fallback: 'Check your latest homework',
                  ),
                  iconPath: 'assets/icons/todo.svg',
                  color: const Color(0xFF8FD8E5),
                  badgeCount: counts.todo, // ✅ dynamic
                  onTap: () async {
                    await _pushNamedAndClearCount(
                      '/student-todo',
                      itemType: 'todo',
                      arguments: {
                        'studentId': child['id'], // 👈 use id, not studentId
                        'child': child,
                      },
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DashboardTile(
                    title: 'Attendance',
                    iconPath: 'assets/icons/attendance.svg',
                    color: const Color(0xFFFFCCCC),
                    centerContent: true,
                    onTap: () async {
                      final prefs = await SharedPreferences.getInstance();
                      final studentId = prefs.getInt(
                        'student_id',
                      ); // Make sure you saved it during login

                      if (studentId != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                StudentAttendancePage(studentId: studentId),
                          ),
                        );
                      } else {
                        // Optional: handle error if ID is not found
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              "Student ID not found. Please login again.",
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final prefs = await SharedPreferences.getInstance();
                      final studentId = prefs.getInt('student_id');

                      if (studentId != null) {
                        await _pushAndClearCount(
                          itemType: 'payments',
                          route: MaterialPageRoute(
                            builder: (_) => StudentPaymentsPage(
                              studentId: studentId.toString(),
                            ), // 👈 convert to String
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Student ID not found. Please login again.',
                            ),
                          ),
                        );
                      }
                    },
                    child: DashboardTile(
                      title: 'Payments',
                      subtitle: _dashboardSubtitle(
                        counts,
                        'payments',
                        fallback: 'View your latest fee update',
                      ),
                      iconPath: 'assets/icons/payments.svg',
                      color: const Color(0xFFC0DD94),
                      badgeCount: counts.payments, // ✅ dynamic
                      centerContent: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DashboardTile(
                    title: 'Time table',
                    iconPath: 'assets/icons/class_time.svg',
                    color: const Color(0xFFE8B3DE),
                    centerContent: true,
                    onTap: () async {
                      final prefs = await SharedPreferences.getInstance();
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

                      // ✅ Use past academic year dynamically

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              StudentTimeTablePage(studentId: studentId),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final prefs = await SharedPreferences.getInstance();

                      // ✅ Safely retrieve the stored student ID
                      final studentIdInt = prefs.getInt('student_id');

                      if (studentIdInt == null) {
                        // ✅ Show error if student_id not found
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Student ID not found')),
                        );
                        return;
                      }

                      final studentId = studentIdInt
                          .toString(); // ✅ Convert to String

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StudentExamsScreen(
                            studentId: studentId,
                          ), // ✅ Pass studentId
                        ),
                      );
                    },
                    child: DashboardTile(
                      title: 'Exams',
                      iconPath: 'assets/icons/exams.svg',
                      color: const Color(0xFFAAE5C8),
                      // badgeCount: 2,
                      centerContent: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12), // ✅ Moved here OUTSIDE the Row
            DashboardTile(
              title: 'Events & Holidays',
              subtitle: '16, Jan 2019, Pongal (Govt. Holiday)',
              iconPath: 'assets/icons/events.svg',
              color: const Color(0xFFF9AFD2),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const EventsHolidaysPage(startInMonthView: true),
                  ),
                );
              },
            ),

            const SizedBox(height: 12),
            // Library

            // Reports
            DashboardTile(
              title: 'Reports',
              subtitle: 'Progress report updated',
              iconPath: 'assets/icons/reports.svg',
              color: const Color(0xFFFFCCCC),
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                final studentId =
                    prefs.getInt('student_id') ?? 0; // Replace with actual key
                if (studentId != 0) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          StudentReportPage(studentId: studentId),
                    ),
                  );
                }
              },
            ),

            const SizedBox(height: 12),

            // Library
            DashboardTile(
              title: 'Library',
              subtitle: _dashboardSubtitle(
                counts,
                'library',
                fallback: 'Check your latest library update',
              ),
              iconPath: 'assets/icons/library.svg',
              color: const Color(0xFFA5D6F9),
              badgeCount: counts.library, // ✅ dynamic
              onTap: () async {
                await _pushAndClearCount(
                  itemType: 'library',
                  route: MaterialPageRoute(
                    builder: (context) => const StudentLibraryPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // New Food Section
            DashboardTile(
              title: 'Food',
              subtitle: 'Menu updated today',
              iconPath: 'assets/icons/food.svg',
              color: const Color(0xFFFFE0B2),
              centerContent: false, // 👈 use row layout
              height: 65, // 👈 reduced height (140 - 40px)
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StudentFoodPage()),
                );
              },
            ),

            const SizedBox(height: 12),
            Row(
              children: [
                if (settings.isVisible('transport'))
                  Expanded(
                    child: DashboardTile(
                      title: 'School bus',
                      subtitle: '7:45 AM',
                      iconPath: 'assets/icons/transport.svg',
                      color: const Color(0xFFCCCCFF),
                      centerContent: true,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const StudentSchoolBusPage(),
                          ),
                        );
                      },
                      onClose: () =>
                          settings.updateVisibility('transport', false),
                    ),
                  ),
                if (settings.isVisible('transport') &&
                    settings.isVisible('messages'))
                  const SizedBox(width: 12),
                if (settings.isVisible('messages'))
                  Expanded(
                    child: DashboardTile(
                      title: 'Message',
                      subtitle: _dashboardSubtitle(
                        counts,
                        'messages',
                        fallback: 'View your latest message',
                      ),
                      iconPath: 'assets/icons/message.svg',
                      color: const Color(0xFFA3D3A7),
                      badgeCount: counts.messages, // ✅ dynamic
                      centerContent: true,
                      onTap: () async {
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

                        await _pushAndClearCount(
                          itemType: 'messages',
                          route: MaterialPageRoute(
                            builder: (_) =>
                                StudentMessagesPage(studentId: studentIdInt),
                          ),
                        );
                      },
                      onClose: () =>
                          settings.updateVisibility('messages', false),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            /// Syllabus
            if (settings.isVisible('subjects'))
              DashboardTile(
                title: 'Syllabus',
                subtitle: 'Updated on 1 Jan 2019',
                iconPath: 'assets/icons/syllabus.svg',
                color: const Color(0xFF91C1BC),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const StudentSyllabusPage(),
                    ),
                  );
                },
                onClose: () => settings.updateVisibility('subjects', false),
              ),
            const SizedBox(height: 12),
            if (settings.isVisible('subjects')) ...[
              DashboardTile(
                title: 'Teachers',
                subtitle: 'You can interact with teachers',
                icon: Icons.person,
                color: const Color(0xFFFFD399),
                onTap: () async {
                  final prefs = await SharedPreferences.getInstance();
                  final studentIdInt = prefs.getInt('student_id');

                  if (studentIdInt != null) {
                    final studentId = studentIdInt.toString();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            StudentTeacherPage(studentId: studentId),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Student ID not found. Please log in again.',
                        ),
                      ),
                    );
                  }
                },
                onClose: () => settings.updateVisibility('subjects', false),
              ),

              const SizedBox(height: 12),
            ],

            // Quick Notes
            DashboardTile(
              title: 'Sticky Notes',
              subtitle: 'View notes from your teachers',
              iconPath: 'assets/icons/quick_notes.svg',
              color: const Color(0xFFE6E6E6),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const StudentQuickNotesPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // Co-curricular activities
            if (settings.isVisible('cocurricular')) ...[
              DashboardTile(
                title: 'Co curricular activities',
                subtitle: 'View your enrolled activities',
                iconPath: 'assets/icons/co_curricular.svg',
                color: const Color(0xFFDBD88A),
                onTap: () async {
                  final prefs = await SharedPreferences.getInstance();
                  final studentId = prefs.getInt("student_id") ?? 0;
                  final academicYear = AppConfig.academicYear;

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StudentActivitiesPage(
                        studentId: studentId,
                        academicYear: academicYear,
                      ),
                    ),
                  );
                },
                onClose: () => settings.updateVisibility('cocurricular', false),
              ),

              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

// DashboardTile widget remains the same, no change needed here.

class DashboardTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? iconPath;
  final IconData? icon;
  final Color color;
  final int? badgeCount;
  final bool centerContent;
  final VoidCallback? onTap;
  final VoidCallback? onClose;

  // 👇 NEW: optional height override
  final double? height;

  const DashboardTile({
    super.key,
    required this.title,
    this.iconPath,
    this.icon,
    required this.color,
    this.subtitle,
    this.badgeCount,
    this.centerContent = false,
    this.onTap,
    this.onClose,
    this.height, // 👈 add to constructor
  });

  @override
  Widget build(BuildContext context) {
    final resolvedHeight = height ?? (centerContent ? 156 : null);

    final Widget iconWidget = Stack(
      clipBehavior: Clip.none,
      children: [
        iconPath != null
            ? SvgPicture.asset(
                iconPath!,
                height: 36,
                width: 36,
                colorFilter: const ColorFilter.mode(
                  Color(0xFF0D47A1),
                  BlendMode.srcIn,
                ),
              )
            : Icon(
                icon ?? Icons.help_outline,
                size: 36,
                color: const Color(0xFF0D47A1),
              ),
        if (badgeCount != null && badgeCount! > 0)
          Positioned(
            top: -6,
            right: -6,
            child: CircleAvatar(
              radius: 9,
              backgroundColor: const Color(0xFF9E005D),
              child: Text(
                badgeCount.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ),
      ],
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        // 👇 Use the provided height if given; otherwise fall back to default
        height: resolvedHeight,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            if (onClose != null)
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: onClose,
                  child: const Icon(Icons.close, size: 16, color: Colors.black),
                ),
              ),
            centerContent
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        iconWidget,
                        const SizedBox(height: 8),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF0D47A1),
                          ),
                        ),
                        if (subtitle != null) const SizedBox(height: 4),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: title == 'Attendance'
                                  ? const Color(0xFFED1C24)
                                  : title == 'Payments' ||
                                        title == 'Message' ||
                                        title == 'School bus'
                                  ? Colors.black
                                  : Colors.grey,
                            ),
                          ),
                      ],
                    ),
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      iconWidget,
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Color(0xFF0D47A1),
                              ),
                            ),
                            if (subtitle != null)
                              Text(
                                subtitle!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }
}
