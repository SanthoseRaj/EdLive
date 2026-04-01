import 'dart:async';
// lib/screens/teacher_dashboard.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:school_app/screens/teachers/todo_list_screen.dart';
import 'package:school_app/screens/students/select_child_page.dart';
import 'package:school_app/providers/teacher_settings_provider.dart';
import 'package:school_app/providers/teacher_dashboard_provider.dart';

import 'teacher_menu_drawer.dart';
import 'teacher_attendance_page.dart';
import 'package:school_app/widgets/teacher_app_bar.dart';
import 'teacher_exam_page.dart';
import 'teacher_transport.dart';
import 'teacher_syllabus_page.dart';
import 'teacher_events_holidays_page.dart';
import 'teacher_payments_page.dart';
import 'teacher_pta_page.dart';
import 'teacher_message_page.dart';
import 'teacher_resource_page.dart';
import 'teacher_report_page.dart';
import 'teacher_quick_notes.dart';
import 'teacher_specialcare_page.dart';
import 'teacher_co_curricular_page.dart';
import 'teacher_notifiction_page.dart';
import 'teacher_achivement_page.dart';
import 'teacher_add_library_book_page.dart';

class TeacherDashboardPage extends StatefulWidget {
  const TeacherDashboardPage({super.key});

  @override
  State<TeacherDashboardPage> createState() => _TeacherDashboardPageState();
}

class _TeacherDashboardPageState extends State<TeacherDashboardPage>
    with WidgetsBindingObserver {
  Timer? _countRefreshTimer;
  bool _isInitialLoadPending = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<SettingsProvider>().loadSettings();
      _loadInitialCounts();
    });
    _startCountRefreshTimer();
  }

  @override
  void dispose() {
    _countRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
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

      context.read<DashboardProvider>().fetchCounts(showLoading: false);
    });
  }

  Future<void> _loadInitialCounts() async {
    await context.read<DashboardProvider>().fetchCounts(showLoading: false);
    if (!mounted) {
      return;
    }

    setState(() {
      _isInitialLoadPending = false;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) {
      return;
    }

    switch (state) {
      case AppLifecycleState.resumed:
        _startCountRefreshTimer();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _countRefreshTimer?.cancel();
        break;
    }
  }

  Future<void> _handleBack() async {
    final prefs = await SharedPreferences.getInstance();
    final loggedInUserType = prefs.getString('user_type')?.toLowerCase();
    final selectedChildString = prefs.getString('selected_child');

    Map<String, dynamic>? selectedChild;
    if (selectedChildString != null && selectedChildString.isNotEmpty) {
      try {
        selectedChild = jsonDecode(selectedChildString) as Map<String, dynamic>;
      } catch (_) {
        selectedChild = null;
      }
    }

    final selectedType =
        selectedChild?['user_type']?.toString().toLowerCase() ?? '';
    final openedFromChildSelection =
        loggedInUserType != 'teacher' &&
        (selectedType == 'staff' || selectedType == 'teacher');

    if (openedFromChildSelection) {
      if (!mounted) {
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SelectChildPage()),
      );
      return;
    }

    if (!mounted) {
      return;
    }

    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    SystemNavigator.pop();
  }

  Future<T?> _pushAndClearCount<T>({
    required Route<T> route,
    required String itemType,
  }) async {
    await context.read<DashboardProvider>().clearBadgeCount(itemType);
    if (!mounted) {
      return null;
    }
    return Navigator.push(context, route);
  }

  Widget _buildBadgeTile({
    required int? Function(DashboardProvider provider) selector,
    required Widget Function(int? badgeCount) builder,
  }) {
    return Selector<DashboardProvider, int?>(
      selector: (context, provider) => selector(provider),
      builder: (context, badgeCount, _) => builder(badgeCount),
    );
  }

  @override
  Widget build(BuildContext context) {
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
        drawer: const MenuDrawer(),
        appBar: const TeacherAppBar(),
        body: _isInitialLoadPending
            ? const Center(child: CircularProgressIndicator())
            : Consumer<SettingsProvider>(
                builder: (context, settings, _) {
                  return ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      GestureDetector(
                        onTap: _handleBack,
                        child: const Row(
                          // children: [
                          //   Icon(
                          //     Icons.arrow_back_ios_new_rounded,
                          //     size: 14,
                          //     color: Colors.black,
                          //   ),
                          //   SizedBox(width: 2),
                          //   Text(
                          //     'Back',
                          //     style: TextStyle(
                          //       fontSize: 13,
                          //       color: Colors.black,
                          //       fontWeight: FontWeight.w500,
                          //     ),
                          //   ),
                          // ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      /// First group: Notifications, Achievements, To-do, Reports
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _buildBadgeTile(
                            selector: (provider) =>
                                provider.counts?.notifications,
                            builder: (badgeCount) => DashboardTile(
                              title: 'Notifications',
                              subtitle: 'PTA meeting on 12, Feb. 2019',
                              iconPath: 'assets/icons/notification.svg',
                              color: const Color(0xFFF9F7A5),
                              badgeCount: badgeCount,
                              onTap: () async {
                                await _pushAndClearCount(
                                  itemType: 'notifications',
                                  route: MaterialPageRoute(
                                    builder: (_) =>
                                        const TeacherNotificationPage(),
                                  ),
                                );
                              },
                            ),
                          ),

                          if (settings.isVisible('achievements'))
                            _buildBadgeTile(
                              selector: (provider) =>
                                  provider.counts?.achievements,
                              builder: (badgeCount) => DashboardTile(
                                title: 'Achievements',
                                subtitle: 'Congratulate your teacher',
                                iconPath: 'assets/icons/achievements.svg',
                                color: const Color(0xFFFCEE21),
                                badgeCount: badgeCount,
                                onClose: () => settings.updateVisibility(
                                  'achievements',
                                  false,
                                ),
                                onTap: () async {
                                  await _pushAndClearCount(
                                    itemType: 'achievements',
                                    route: MaterialPageRoute(
                                      builder: (_) =>
                                          const TeacherAchievementPage(),
                                    ),
                                  );
                                },
                              ),
                            ),
                          if (settings.isVisible('todo'))
                            _buildBadgeTile(
                              selector: (provider) => provider.counts?.todo,
                              builder: (badgeCount) => DashboardTile(
                                title: 'Home Work',
                                subtitle: 'Make your own list, set reminder.',
                                iconPath: 'assets/icons/todo.svg',
                                color: const Color(0xFF8FD8E5),
                                badgeCount: badgeCount,
                                onClose: () =>
                                    settings.updateVisibility('todo', false),
                                onTap: () async {
                                  await _pushAndClearCount(
                                    itemType: 'todo',
                                    route: MaterialPageRoute(
                                      builder: (_) => const ToDoListPage(),
                                    ),
                                  );
                                },
                              ),
                            ),
                          DashboardTile(
                            title: 'Reports',
                            subtitle: 'Progress report updated',
                            iconPath: 'assets/icons/reports.svg',
                            color: const Color(0xFFFFCCCC),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const TeacherReportPage(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      /// Second group: Attendance, Class & Time
                      Row(
                        children: [
                          Expanded(
                            child: DashboardTile(
                              title: 'Attendance',
                              iconPath: 'assets/icons/attendance.svg',
                              color: const Color(0xFFFFCCCC),
                              centerContent: true,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const TeacherAttendancePage(),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DashboardTile(
                              title: 'Class & Time',
                              iconPath: 'assets/icons/class_time.svg',
                              color: const Color(0xFFFCDBB1),
                              centerContent: true,
                              onTap: () =>
                                  Navigator.pushNamed(context, '/classtime'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      /// Third group: Payments, Exams
                      Row(
                        children: [
                          Expanded(
                            child: _buildBadgeTile(
                              selector: (provider) => provider.counts?.payments,
                              builder: (badgeCount) => DashboardTile(
                                title: 'Payments',
                                iconPath: 'assets/icons/payments.svg',
                                color: const Color(0xFFC0DD94),
                                badgeCount: badgeCount,
                                centerContent: true,
                                onTap: () async {
                                  await _pushAndClearCount(
                                    itemType: 'payments',
                                    route: MaterialPageRoute(
                                      builder: (_) =>
                                          const TeacherPaymentsPage(),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DashboardTile(
                              title: 'Exams',
                              iconPath: 'assets/icons/exams.svg',
                              color: const Color(0xFFAAE5C8),
                              // badgeCount: 2, // placeholder
                              centerContent: true,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const TeacherExamPage(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      /// Fourth group: Transport, Message
                      Row(
                        children: [
                          Expanded(
                            child: DashboardTile(
                              title: 'Transport',
                              iconPath: 'assets/icons/transport.svg',
                              color: const Color(0xFFCCCCFF),
                              centerContent: true,
                              onTap: () async {
                                final prefs =
                                    await SharedPreferences.getInstance();
                                final userDataString = prefs.getString(
                                  'user_data',
                                );
                                int staffId = 0;

                                if (userDataString != null) {
                                  final userData = json.decode(userDataString);
                                  if (userData['staffid'] != null &&
                                      userData['staffid'].isNotEmpty) {
                                    staffId = userData['staffid'][0];
                                  }
                                }

                                if (!context.mounted) return;

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => TransportPage(
                                      staffId: staffId,
                                      // academicYear:
                                      //     AppConfig.academicYear, // ✅ global use
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                          const SizedBox(width: 12),
                          Expanded(
                            child: DashboardTile(
                              title: 'Message',
                              iconPath: 'assets/icons/message.svg',
                              color: const Color(0xFFE8B3DE),
                              // badgeCount: counts?.messages,
                              centerContent: true,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const TeacherMessagePage(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      /// Fifth group: Events & Holidays, PTA, Library, Syllabus, Special Care, Co-Curricular, Quick Notes, Resources
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          DashboardTile(
                            title: 'Events & Holidays',
                            subtitle: '16 Jan 2019, Pongal',
                            iconPath: 'assets/icons/events.svg',
                            color: const Color(0xFFF9AFD2),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const TeacherEventsHolidaysPage(
                                        startInMonthView: true,
                                      ),
                                ),
                              );
                            },
                          ),
                          if (settings.isVisible('pta'))
                            DashboardTile(
                              title: 'PTA',
                              subtitle: 'Next meeting: 22 Sep. 2019',
                              iconPath: 'assets/icons/pta.svg',
                              color: const Color(0xFFDBC0B6),
                              onClose: () =>
                                  settings.updateVisibility('pta', false),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const TeacherPTAPage(),
                                  ),
                                );
                              },
                            ),
                          if (settings.isVisible('library'))
                            _buildBadgeTile(
                              selector: (provider) => provider.counts?.library,
                              builder: (badgeCount) => DashboardTile(
                                title: 'Library',
                                subtitle: 'Manage books and records',
                                iconPath: 'assets/icons/library.svg',
                                color: const Color(0xFFACCFE2),
                                badgeCount: badgeCount,
                                onClose: () =>
                                    settings.updateVisibility('library', false),
                                onTap: () async {
                                  await _pushAndClearCount(
                                    itemType: 'library',
                                    route: MaterialPageRoute(
                                      builder: (_) =>
                                          const AddLibraryBookPage(),
                                    ),
                                  );
                                },
                              ),
                            ),
                          if (settings.isVisible('subjects'))
                            DashboardTile(
                              title: 'Syllabus',
                              subtitle: 'Lessons to be completed',
                              iconPath: 'assets/icons/syllabus.svg',
                              color: const Color(0xFFA3D3A7),
                              onClose: () =>
                                  settings.updateVisibility('subjects', false),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const TeacherSyllabusPage(),
                                  ),
                                );
                              },
                            ),
                          if (settings.isVisible('special_care'))
                            DashboardTile(
                              title: 'Special care',
                              subtitle: 'Students need your support',
                              iconPath: 'assets/icons/special_care.svg',
                              color: const Color(0xFFFFD399),
                              onClose: () => settings.updateVisibility(
                                'special_care',
                                false,
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const SpecialCarePage(),
                                  ),
                                );
                              },
                            ),
                          if (settings.isVisible('cocurricular'))
                            DashboardTile(
                              title: 'Co curricular activities',
                              subtitle: 'NCC Camp on 23, Jan.2019',
                              iconPath: 'assets/icons/co_curricular.svg',
                              color: const Color(0xFFDBD88A),
                              onClose: () => settings.updateVisibility(
                                'cocurricular',
                                false,
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const CoCurricularActivitiesPage(),
                                  ),
                                );
                              },
                            ),
                          if (settings.isVisible('quick_notes'))
                            DashboardTile(
                              title: 'Sticky notes',
                              subtitle: 'Note anything worth noting',
                              iconPath: 'assets/icons/quick_notes.svg',
                              color: const Color(0xFFE6E6E6),
                              onClose: () => settings.updateVisibility(
                                'quick_notes',
                                false,
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const TeacherQuickNotesPage(),
                                  ),
                                );
                              },
                            ),
                          if (settings.isVisible('resources'))
                            DashboardTile(
                              title: 'Resources',
                              subtitle: 'Useful links and study materials',
                              iconPath: 'assets/icons/resources.svg',
                              color: const Color(0xFFD8CAD8),
                              onClose: () =>
                                  settings.updateVisibility('resources', false),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const TeacherResourcePage(),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

/// DashboardTile widget (no changes)
class DashboardTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String iconPath;
  final Color color;
  final int? badgeCount;
  final bool centerContent;
  final VoidCallback? onTap;
  final VoidCallback? onClose;

  const DashboardTile({
    super.key,
    required this.title,
    required this.iconPath,
    required this.color,
    this.subtitle,
    this.badgeCount,
    this.centerContent = false,
    this.onTap,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final svgIcon = Stack(
      clipBehavior: Clip.none,
      children: [
        SvgPicture.asset(
          iconPath,
          height: 36,
          width: 36,
          colorFilter: const ColorFilter.mode(
            Color(0xFF0D47A1),
            BlendMode.srcIn,
          ),
        ),
        if (badgeCount != null && badgeCount! > 0)
          Positioned(
            top: -6,
            right: iconPath.contains('payments') ? -8 : -6,
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
        height: centerContent ? 100 : null,
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
                        svgIcon,
                        const SizedBox(height: 8),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFF0D47A1),
                          ),
                        ),
                      ],
                    ),
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      svgIcon,
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFF0D47A1),
                              ),
                            ),
                            if (subtitle != null)
                              Text(
                                subtitle!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
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
