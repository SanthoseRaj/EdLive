import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/config.dart';
import 'providers/exam_result_provider.dart';
import 'providers/library_book_detail_provider.dart';
import 'providers/library_books_list_provider.dart';
import 'providers/student_notification_dashboard_provider.dart';
import 'providers/student_settings_provider.dart';
import 'providers/student_task_provider.dart';
import 'providers/teacher_achievement_provider.dart';
import 'providers/teacher_attendance_provider.dart';
import 'providers/teacher_dashboard_provider.dart';
import 'providers/teacher_library_copy_provider.dart';
import 'providers/teacher_library_member_provider.dart';
import 'providers/teacher_library_provider.dart';
import 'providers/teacher_settings_provider.dart';
import 'providers/teacher_task_provider.dart';
import 'providers/teacher_timetable_provider.dart';
import 'screens/login_page.dart';
import 'screens/students/select_child_page.dart';
import 'screens/students/student_achievement_page.dart';
import 'screens/students/student_dashboard.dart';
import 'screens/students/student_library_page.dart';
import 'screens/students/student_messages_page.dart';
import 'screens/students/student_settings_page.dart';
import 'screens/students/student_timetable.dart';
import 'screens/students/student_todo_list_screen.dart';
import 'screens/teachers/class_time_pageview.dart';
import 'screens/teachers/settings.dart';
import 'screens/teachers/teacher_attendance_page.dart';
import 'screens/teachers/teacher_dashboard.dart';
import 'screens/teachers/teacher_events_holidays_page.dart';
import 'screens/teachers/teacher_exam_page.dart';
import 'screens/teachers/teacher_profile_page.dart';
import 'screens/teachers/teacher_syllabus_page.dart';
import 'screens/teachers/todo_list_screen.dart';
import 'package:school_app/screens/students/student_payments_page.dart';
import 'package:school_app/screens/students/student_profile_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.setAcademicYear();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TeacherTaskProvider()),
        ChangeNotifierProvider(create: (_) => StudentTaskProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => TimetableProvider()),
        ChangeNotifierProvider(create: (_) => AttendanceProvider()),
        ChangeNotifierProvider(create: (_) => StudentSettingsProvider()),
        ChangeNotifierProvider(create: (_) => AchievementProvider()),
        ChangeNotifierProvider(create: (_) => LibraryProvider()),
        ChangeNotifierProvider(create: (_) => LibraryCopyProvider()),
        ChangeNotifierProvider(create: (_) => LibraryMemberProvider()),
        ChangeNotifierProvider(create: (_) => LibraryBooksListProvider()),
        ChangeNotifierProvider(create: (_) => LibraryBookDetailProvider()),
        ChangeNotifierProvider(create: (_) => DashboardCountsProvider()),
        ChangeNotifierProvider(create: (_) => ExamResultProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<int> _getStaffId() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = _readJsonMap(prefs.getString('user_data'));
    final selectedChild = _readJsonMap(prefs.getString('selected_child'));
    final loggedInUserType = prefs.getString('user_type')?.toLowerCase();

    if (loggedInUserType != 'teacher') {
      final selectedTeacherId = _resolveTeacherStaffId(selectedChild);
      if (selectedTeacherId != null) {
        return selectedTeacherId;
      }
    }

    final userTeacherId =
        _extractPositiveInt(userData?['staffid']) ??
        _extractPositiveInt(userData?['teacher_id']) ??
        _extractPositiveInt(userData?['staff_id']) ??
        _extractPositiveInt(userData?['id']);
    if (userTeacherId != null) {
      return userTeacherId;
    }

    final storedTeacherId = prefs.getInt('teacher_id');
    if (storedTeacherId != null && storedTeacherId > 0) {
      return storedTeacherId;
    }

    throw Exception('Staff ID not found');
  }

  Map<String, dynamic>? _readJsonMap(String? rawData) {
    if (rawData == null || rawData.isEmpty) {
      return null;
    }

    try {
      return jsonDecode(rawData) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
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
    if (value is List && value.isNotEmpty) {
      return _extractPositiveInt(value.first);
    }
    return null;
  }

  int? _resolveTeacherStaffId(Map<String, dynamic>? selectedChild) {
    final selectedType =
        selectedChild?['user_type']?.toString().toLowerCase() ?? '';
    final isTeacherSelection =
        selectedType == 'staff' || selectedType == 'teacher';

    if (!isTeacherSelection) {
      return null;
    }

    return _extractPositiveInt(selectedChild?['staffid']) ??
        _extractPositiveInt(selectedChild?['teacher_id']) ??
        _extractPositiveInt(selectedChild?['staff_id']) ??
        _extractPositiveInt(selectedChild?['id']) ??
        _extractPositiveInt(selectedChild?['user_id']);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EDLive School App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Roboto',
      ),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        if (settings.name == '/') {
          return MaterialPageRoute(builder: (_) => const AuthGatePage());
        }

        switch (settings.name) {
          case '/dashboard':
            return MaterialPageRoute(
              builder: (_) => const TeacherDashboardPage(),
            );
          case '/todo':
            return MaterialPageRoute(builder: (_) => const ToDoListPage());
          case '/classtime':
            return MaterialPageRoute(builder: (_) => const ClassTimePageView());
          case '/profile':
            return MaterialPageRoute(
              builder: (_) => FutureBuilder<int>(
                future: _getStaffId(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Scaffold(
                      backgroundColor: Colors.white,
                      body: Center(child: CircularProgressIndicator()),
                    );
                  } else if (snapshot.hasError || !snapshot.hasData) {
                    return const Scaffold(
                      backgroundColor: Colors.white,
                      body: Center(child: Text('Failed to load profile')),
                    );
                  } else {
                    final staffId = snapshot.data!;
                    return TeacherProfilePage(staffId: staffId);
                  }
                },
              ),
            );
          case '/settings':
            return MaterialPageRoute(builder: (_) => const SettingsPage());

          case '/student-todo':
            return MaterialPageRoute(
              builder: (_) => const StudentToDoListPage(),
            );
          case '/student-dashboard':
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (_) => StudentDashboardPage(childData: args),
            );
          case '/select-child':
            return MaterialPageRoute(builder: (_) => const SelectChildPage());
          case '/student-details':
            final studentId = settings.arguments as int;
            return MaterialPageRoute(
              builder: (_) =>
                  StudentProfilePage(studentId: studentId, isTeacherView: true),
            );
          case '/student-profile':
            final id = settings.arguments as int;
            return MaterialPageRoute(
              builder: (_) => StudentProfilePage(studentId: id),
            );
          case '/timetable':
            final args = settings.arguments as Map<String, dynamic>;
            final studentId = args['studentId'].toString();
            return MaterialPageRoute(
              builder: (_) => StudentTimeTablePage(studentId: studentId),
            );
          case '/student-settings':
            return MaterialPageRoute(
              builder: (_) => const StudentSettingsPage(),
            );
          case '/student-library':
            return MaterialPageRoute(
              builder: (_) => const StudentLibraryPage(),
            );
          case '/student-achievements':
            final args = settings.arguments as Map<String, dynamic>;
            final classId = args['classId'] as int;
            return MaterialPageRoute(
              builder: (_) => StudentAchievementPage(classId: classId),
            );
          case '/student-payments':
            final args = settings.arguments as Map<String, dynamic>;
            final studentId = args['studentId'] as String;
            return MaterialPageRoute(
              builder: (_) => StudentPaymentsPage(studentId: studentId),
            );
          case '/student-messages':
            final args = settings.arguments as Map<String, dynamic>;
            final studentId = args['studentId'] as int;
            return MaterialPageRoute(
              builder: (_) => StudentMessagesPage(studentId: studentId),
            );

          case '/attendance':
            return MaterialPageRoute(
              builder: (_) => const TeacherAttendancePage(),
            );
          case '/syllabus':
            return MaterialPageRoute(
              builder: (_) => const TeacherSyllabusPage(),
            );
          case '/exams':
            return MaterialPageRoute(builder: (_) => const TeacherExamPage());
          case '/events':
            return MaterialPageRoute(
              builder: (_) => const TeacherEventsHolidaysPage(),
            );

          default:
            return MaterialPageRoute(builder: (_) => const LoginPage());
        }
      },
    );
  }
}

class AuthGatePage extends StatefulWidget {
  const AuthGatePage({super.key});

  @override
  State<AuthGatePage> createState() => _AuthGatePageState();
}

class _AuthGatePageState extends State<AuthGatePage> {
  late final Future<_AuthLaunchData> _launchDataFuture = _loadLaunchData();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AuthLaunchData>(
      future: _launchDataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final launchData = snapshot.data ?? const _AuthLaunchData();
        final selectedProfileType =
            launchData.selectedChild?['user_type']?.toString().toLowerCase() ??
            '';
        final opensTeacherDashboard =
            selectedProfileType == 'staff' || selectedProfileType == 'teacher';
        final hasToken =
            launchData.token != null && launchData.token!.trim().isNotEmpty;

        if (hasToken) {
          if (launchData.userType == 'teacher' || opensTeacherDashboard) {
            return const TeacherDashboardPage();
          }

          if (launchData.userType == 'student' ||
              launchData.userType == 'parent') {
            if (launchData.selectedChild != null) {
              return StudentDashboardPage(childData: launchData.selectedChild!);
            }

            return const SelectChildPage();
          }
        }

        return const LoginPage();
      },
    );
  }

  Future<_AuthLaunchData> _loadLaunchData() async {
    final prefs = await SharedPreferences.getInstance();
    return _AuthLaunchData(
      token: prefs.getString('auth_token'),
      userType: prefs.getString('user_type')?.toLowerCase(),
      selectedChild: _readJsonMap(prefs.getString('selected_child')),
    );
  }

  Map<String, dynamic>? _readJsonMap(String? rawData) {
    if (rawData == null || rawData.isEmpty) {
      return null;
    }

    try {
      return jsonDecode(rawData) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}

class _AuthLaunchData {
  final String? token;
  final String? userType;
  final Map<String, dynamic>? selectedChild;

  const _AuthLaunchData({this.token, this.userType, this.selectedChild});
}
