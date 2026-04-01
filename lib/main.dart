import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/login_page.dart';

import 'screens/teachers/teacher_dashboard.dart';
import 'screens/teachers/todo_list_screen.dart';
import 'screens/teachers/class_time_pageview.dart';
import 'screens/teachers/teacher_profile_page.dart';
import 'screens/teachers/settings.dart';
import 'screens/teachers/teacher_attendance_page.dart';
import 'screens/teachers/teacher_exam_page.dart';
import 'screens/teachers/teacher_syllabus_page.dart';
import 'screens/teachers/teacher_events_holidays_page.dart';

import 'screens/students/student_dashboard.dart';
import 'screens/students/select_child_page.dart';
import 'screens/students/student_todo_list_screen.dart';
import 'package:school_app/screens/students/student_profile_page.dart';
import 'screens/students/student_timetable.dart';
import 'screens/students/student_settings_page.dart';
import 'screens/students/student_achievement_page.dart  ';
import 'package:school_app/screens/students/student_payments_page.dart';
import 'screens/students/student_messages_page.dart';
import 'screens/students/student_library_page.dart';

import 'providers/student_settings_provider.dart';

import 'providers/teacher_task_provider.dart'; // For teacher
import 'providers/student_task_provider.dart'; // For student
import 'providers/teacher_settings_provider.dart';
import 'providers/teacher_timetable_provider.dart';
import 'providers/teacher_attendance_provider.dart';
import 'providers/teacher_achievement_provider.dart';
import 'providers/teacher_library_provider.dart';
import 'providers/teacher_library_copy_provider.dart';
import 'providers/teacher_library_member_provider.dart';
import 'providers/library_books_list_provider.dart';
import 'providers/library_book_detail_provider.dart';
import 'providers/student_notification_dashboard_provider.dart';
import 'providers/exam_result_provider.dart';
import 'providers/teacher_dashboard_provider.dart';

import 'dart:convert';

import 'config/config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  AppConfig.setAcademicYear(); // ✅ global

  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('auth_token');
  final userType = prefs.getString('user_type');
  final userDataString = prefs.getString('user_data');

  Map<String, dynamic>? parsedUserData;
  if (userDataString != null) {
    parsedUserData = jsonDecode(userDataString);
  }

  final selectedChildString = prefs.getString('selected_child');
  Map<String, dynamic>? selectedChild;
  if (selectedChildString != null) {
    selectedChild = jsonDecode(selectedChildString);
  }

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
      child: MyApp(
        token: token,
        userType: userType,
        userData: parsedUserData,
        selectedChild: selectedChild,
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  final String? token;
  final String? userType;
  final Map<String, dynamic>? userData;
  final Map<String, dynamic>? selectedChild;

  const MyApp({
    super.key,
    required this.token,
    required this.userType,
    required this.userData,
    required this.selectedChild,
  });

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
        // Handle the initial '/' route with token & userType logic first
        if (settings.name == '/') {
          final selectedProfileType =
              selectedChild?['user_type']?.toString().toLowerCase() ?? '';
          final opensTeacherDashboard =
              selectedProfileType == 'staff' ||
              selectedProfileType == 'teacher';

          if (token != null) {
            if (userType == 'teacher' || opensTeacherDashboard) {
              return MaterialPageRoute(
                builder: (_) => const TeacherDashboardPage(),
              );
            } else if (userType == 'student' || userType == 'parent') {
              if (selectedChild != null) {
                return MaterialPageRoute(
                  builder: (_) =>
                      StudentDashboardPage(childData: selectedChild!),
                );
              } else {
                return MaterialPageRoute(
                  builder: (_) => const SelectChildPage(),
                );
              }
            }
          }
          return MaterialPageRoute(builder: (_) => const LoginPage());
        }

        // Other routes
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

          // Student routes
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
              builder: (_) {
                // return StudentDetailPage(studentId: studentId);
                return StudentProfilePage(
                  studentId: studentId,
                  isTeacherView: true,
                );
              },
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

          case '/student-library': // ✅ NEW ROUTE
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

          // Teacher menu routes
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
