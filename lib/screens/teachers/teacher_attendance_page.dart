import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:school_app/screens/teachers/teacher_menu_drawer.dart';
import 'package:school_app/widgets/teacher_app_bar.dart';

import 'package:school_app/models/class_section.dart';

// Attendance Month
import 'package:school_app/models/teacher_attendance_year.dart';
import 'package:school_app/providers/teacher_attendance_provider.dart';

// import 'package:school_app/services/attendance_service.dart';

// Attendance Day
import 'package:school_app/services/teacher_student_classsection.dart';
import 'package:school_app/models/teacher_student_classsection.dart';
import 'package:school_app/config/config.dart';

final DateTime now = DateTime.now();
final String formattedDate = DateFormat(
  'd, MMM. y',
).format(now); // e.g., 23, Jul. 2025
final String dayName = DateFormat('EEEE').format(now); // e.g., Tuesday

class TeacherAttendancePage extends StatelessWidget {
  const TeacherAttendancePage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFFFAEAE),
        drawer: const MenuDrawer(),
        appBar: const TeacherAppBar(),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 7),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text(
                      '< Back',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        color: const Color(0xFF2E3192),
                        child: SvgPicture.asset(
                          'assets/icons/attendance.svg',
                          height: 20,
                          width: 18,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Attendance',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E3192),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: const [
                      TabBar(
                        indicatorColor: Color(0xFF29ABE2),
                        labelColor: Color(0xFF29ABE2),
                        unselectedLabelColor: Colors.black,
                        tabs: [
                          Tab(text: 'Day'),
                          Tab(text: 'Month'),
                          Tab(text: 'Year'),
                        ],
                      ),

                      Expanded(
                        child: TabBarView(
                          children: [
                            TeacherAttendanceDayTab(),
                            TeacherAttendanceMonthTab(),
                            TeacherAttendanceYearTab(), // ← NEW
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TeacherAttendanceDayTab extends StatefulWidget {
  const TeacherAttendanceDayTab({super.key});

  @override
  State<TeacherAttendanceDayTab> createState() =>
      _TeacherAttendanceDayTabState();
}

class _TeacherAttendanceDayTabState extends State<TeacherAttendanceDayTab> {
  int totalAbsentees = 0;
  bool isAttendanceMarked =
      false; // ✅ New flag to check if attendance is marked

  String? selectedClass;
  int? selectedClassId;
  List<ClassSection> classSections = [];

  List<StudentClassSection> students = [];
  bool isLoading = true;
  DateTime selectedDate = DateTime.now();

  List<int> morningTaps = [];
  List<int> afternoonTaps = [];

  @override
  void initState() {
    super.initState();
    loadClassSections();
  }

  Future<void> loadClassSections() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/master/classes'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final loadedSections = data
            .map((e) => ClassSection.fromJson(e))
            .toList();

        setState(() {
          classSections = loadedSections;
          if (classSections.isNotEmpty) {
            selectedClass = classSections.first.fullName;
            selectedClassId = classSections.first.id;
          }
        });

        await fetchStudents();
      }
    } catch (e) {
      print("Failed to load class sections: $e");
    }
  }

  Future<void> fetchStudents() async {
    try {
      final studentList = await StudentService().fetchStudents();
      setState(() {
        students = studentList;
        morningTaps = List.filled(studentList.length, 0);
        afternoonTaps = List.filled(studentList.length, 0);
      });

      await fetchAttendanceStatus();
      setState(() => isLoading = false);
    } catch (e) {
      print("Error: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchAttendanceStatus() async {
    if (selectedClassId == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';

      morningTaps = List.filled(students.length, 0);
      afternoonTaps = List.filled(students.length, 0);
      totalAbsentees = 0;
      isAttendanceMarked = false; // ✅ Reset flag

      for (int i = 0; i < students.length; i++) {
        final student = students[i];

        final response = await http.get(
          Uri.parse(
            '${AppConfig.baseUrl}/attendance/student?studentId=${student.id}&date=${DateFormat('yyyy-MM-dd').format(selectedDate)}',
          ),
          headers: {'Authorization': 'Bearer $token', 'accept': '*/*'},
        );

        final List<dynamic> dataList = jsonDecode(response.body);
        if (dataList.isNotEmpty) {
          final Map<String, dynamic> data = dataList[0];
          setState(() {
            morningTaps[i] = data['is_present_morning'] == true ? 1 : 2;
            afternoonTaps[i] = data['is_present_afternoon'] == true ? 1 : 2;

            // ✅ Check if attendance is marked for this student
            if (data['is_present_morning'] != null ||
                data['is_present_afternoon'] != null) {
              isAttendanceMarked = true;
            }

            if (data['is_present_morning'] == false ||
                data['is_present_afternoon'] == false) {
              totalAbsentees++;
            }
          });
        }
      }

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print("Error fetching attendance: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> refetchSingleStudentAttendance(int index, String session) async {
    final student = students[index];
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    try {
      final response = await http.get(
        Uri.parse(
          '${AppConfig.baseUrl}/attendance/student?studentId=${student.id}&date=${DateFormat('yyyy-MM-dd').format(selectedDate)}',
        ),
        headers: {'Authorization': 'Bearer $token', 'accept': '*/*'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> dataList = jsonDecode(response.body);
        if (dataList.isNotEmpty) {
          final Map<String, dynamic> data = dataList[0];

          setState(() {
            if (session == "morning") {
              morningTaps[index] = data['is_present_morning'] == true ? 1 : 2;
            } else if (session == "afternoon") {
              afternoonTaps[index] = data['is_present_afternoon'] == true
                  ? 1
                  : 2;
            }
          });
        }
      }
    } catch (e) {
      print("Error refetching attendance: $e");
    }
  }

  Future<void> toggleAttendance({
    required int studentId,
    required int classId,
    required String session,
    required bool isPresent,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/attendance/toggle'),
        headers: {
          'Content-Type': 'application/json',
          'accept': '*/*',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          "studentId": studentId,
          "classId": classId,
          "date": DateFormat('yyyy-MM-dd').format(selectedDate),
          "session": session,
          "isPresent": isPresent,
        }),
      );

      if (response.statusCode == 200) {
        print("Attendance updated for $studentId - $session: $isPresent");
      } else {
        print("Failed to update attendance: ${response.statusCode}");
      }
    } catch (e) {
      print("API error: $e");
    }
  }

  // ✅ Check if selected date is today
  bool get isToday {
    final now = DateTime.now();
    return selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;
  }

  // ✅ Check if selected date is in the future
  bool get isFutureDate {
    final now = DateTime.now();
    return selectedDate.isAfter(DateTime(now.year, now.month, now.day));
  }

  void _goToPreviousDay() async {
    setState(() {
      selectedDate = selectedDate.subtract(const Duration(days: 1));
      isLoading = true;
    });

    await fetchAttendanceStatus();
    setState(() => isLoading = false);
  }

  void _goToNextDay() async {
    // ✅ Allow navigation to future dates for viewing, but disable attendance editing
    if (!isFutureDate) {
      setState(() {
        selectedDate = selectedDate.add(const Duration(days: 1));
        isLoading = true;
      });

      await fetchAttendanceStatus();
      setState(() => isLoading = false);
    }
  }

  Widget getAttendanceIcon(int state) {
    switch (state) {
      case 1:
        return Icon(Icons.check, color: Colors.green, size: 24);
      case 2:
        return Icon(Icons.close, color: Colors.red, size: 24);
      default:
        return Icon(
          Icons.check_box_outline_blank,
          color: isToday ? Colors.grey.shade400 : Colors.grey.shade300,
          size: 20,
        );
    }
  }

  // ✅ Get the appropriate message based on attendance status
  String get attendanceMessage {
    if (!isToday && !isAttendanceMarked) {
      return "No attendance"; // ✅ Show "No attendance" for past dates without attendance
    } else if (totalAbsentees == 0 && isAttendanceMarked) {
      return "No absentees"; // ✅ Show "No absentees" when attendance is marked and no one is absent
    } else if (totalAbsentees > 0) {
      return "$totalAbsentees absentee${totalAbsentees > 1 ? 's' : ''}"; // ✅ Show count of absentees
    } else {
      return "No attendance"; // ✅ Default message
    }
  }

  // ✅ Get the color for the attendance message
  Color get attendanceMessageColor {
    if (!isToday && !isAttendanceMarked) {
      return Colors.grey; // ✅ Grey for "No attendance" in past dates
    } else if (totalAbsentees == 0 && isAttendanceMarked) {
      return Colors.green; // ✅ Green for "No absentees"
    } else if (totalAbsentees > 0) {
      return Colors.red; // ✅ Red for absentees count
    } else {
      return Colors.grey; // ✅ Default grey
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final formattedDate = DateFormat('d, MMM. y').format(selectedDate);
    final dayName = DateFormat('EEEE').format(selectedDate);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ✅ Always allow going to previous days (view only)
                  IconButton(
                    onPressed: _goToPreviousDay,
                    icon: const Icon(
                      Icons.arrow_left,
                      size: 28,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    formattedDate,
                    style: TextStyle(
                      fontSize: 18,
                      color: isToday ? Color(0xFF2E3192) : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // ✅ Disable going to future dates
                  IconButton(
                    onPressed: isFutureDate ? null : _goToNextDay,
                    icon: Icon(
                      Icons.arrow_right,
                      size: 28,
                      color: isFutureDate ? Colors.grey : Colors.black,
                    ),
                  ),
                ],
              ),
              Text(
                dayName,
                style: TextStyle(
                  fontSize: 14,
                  color: isToday ? Colors.black : Colors.grey,
                ),
              ),
              // ✅ Use the dynamic attendance message
              Text(
                attendanceMessage,
                style: TextStyle(
                  color: attendanceMessageColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  height: 38,
                  width: 100,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: const BoxDecoration(color: Color(0xFFCCCCCC)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedClass,
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: Color(0xFF2E3192),
                      ),
                      dropdownColor: Colors.white,
                      style: const TextStyle(
                        color: Color(0xFF29ABE2),
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      onChanged: (String? newValue) async {
                        final selected = classSections.firstWhere(
                          (c) => c.fullName == newValue,
                        );
                        setState(() {
                          selectedClass = selected.fullName;
                          selectedClassId = selected.id;
                          isLoading = true;
                        });

                        await fetchStudents();
                        setState(() => isLoading = false);
                      },
                      items: classSections.map((section) {
                        return DropdownMenuItem<String>(
                          value: section.fullName,
                          child: Text(section.fullName),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: const [
                  Expanded(flex: 3, child: SizedBox()),
                  Expanded(
                    flex: 1,
                    child: Text(
                      "M",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      "AN",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              // ✅ Show view-only message for past dates
              if (!isToday)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    "View Only - Past Date",
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: students.length,
            itemBuilder: (context, index) {
              final student = students[index];
              return Container(
                height: 55,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        "${index + 1}. ${student.name}",
                        style: TextStyle(
                          color: isToday ? Colors.black : Colors.grey.shade600,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: GestureDetector(
                        // ✅ Only allow tapping if it's today
                        onTap: isToday
                            ? () async {
                                setState(
                                  () => morningTaps[index] =
                                      (morningTaps[index] + 1) % 3,
                                );
                                if (morningTaps[index] != 0) {
                                  await toggleAttendance(
                                    studentId: student.id,
                                    classId: selectedClassId!,
                                    session: "morning",
                                    isPresent: morningTaps[index] == 1,
                                  );
                                  await refetchSingleStudentAttendance(
                                    index,
                                    "morning",
                                  );

                                  // ✅ Update attendance marked status after toggle
                                  setState(() {
                                    isAttendanceMarked = true;
                                  });
                                }
                              }
                            : null,
                        child: Center(
                          child: getAttendanceIcon(morningTaps[index]),
                        ),
                      ),
                    ),
                    Container(
                      width: 12,
                      height: double.infinity,
                      color: const Color(0xFFE6E6E6),
                    ),
                    Expanded(
                      flex: 1,
                      child: GestureDetector(
                        // ✅ Only allow tapping if it's today
                        onTap: isToday
                            ? () async {
                                setState(
                                  () => afternoonTaps[index] =
                                      (afternoonTaps[index] + 1) % 3,
                                );
                                if (afternoonTaps[index] != 0) {
                                  await toggleAttendance(
                                    studentId: student.id,
                                    classId: selectedClassId!,
                                    session: "afternoon",
                                    isPresent: afternoonTaps[index] == 1,
                                  );
                                  await refetchSingleStudentAttendance(
                                    index,
                                    "afternoon",
                                  );

                                  // ✅ Update attendance marked status after toggle
                                  setState(() {
                                    isAttendanceMarked = true;
                                  });
                                }
                              }
                            : null,
                        child: Center(
                          child: getAttendanceIcon(afternoonTaps[index]),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class StudentMonthlyAttendance {
  final int studentId;
  final String fullName;
  final int totalDays;
  final double totalPresent;
  final double totalAbsent;

  StudentMonthlyAttendance({
    required this.studentId,
    required this.fullName,
    required this.totalDays,
    required this.totalPresent,
    required this.totalAbsent,
  });

  factory StudentMonthlyAttendance.fromJson(Map<String, dynamic> json) {
    return StudentMonthlyAttendance(
      studentId: json['student_id'],
      fullName: json['full_name'],
      totalDays: int.tryParse(json['total_days'] ?? '0') ?? 0,
      totalPresent: double.tryParse(json['total_present'] ?? '0.00') ?? 0.00,
      totalAbsent: double.tryParse(json['total_absent'] ?? '0.00') ?? 0.00,
    );
  }
}

class TeacherAttendanceMonthTab extends StatefulWidget {
  const TeacherAttendanceMonthTab({super.key});

  @override
  State<TeacherAttendanceMonthTab> createState() =>
      _TeacherAttendanceMonthTabState();
}

class _TeacherAttendanceMonthTabState extends State<TeacherAttendanceMonthTab> {
  String? selectedClass;
  int? selectedClassId;
  List<ClassSection> classSections = [];

  bool viewAbsentOnly = false;
  bool isLoading = true;
  List<StudentMonthlyAttendance> students = [];
  DateTime currentMonth = DateTime.now(); // ✅ Track current month

  @override
  void initState() {
    super.initState();
    loadClassSections();
  }

  Future<void> loadClassSections() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/master/classes'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final loadedSections = data
            .map((e) => ClassSection.fromJson(e))
            .toList();

        setState(() {
          classSections = loadedSections;
          if (classSections.isNotEmpty) {
            selectedClass = classSections.first.fullName;
            selectedClassId = classSections.first.id;
          }
        });

        fetch(); // Fetch attendance after loading classes
      }
    } catch (e) {
      print('Failed to load class sections: $e');
    }
  }

  Future<void> fetch() async {
    setState(() => isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';

      final classId = selectedClassId;
      if (classId == null) return;

      final startDate = DateFormat(
        'yyyy-MM-dd',
      ).format(DateTime(currentMonth.year, currentMonth.month, 1));
      final endDate = DateFormat(
        'yyyy-MM-dd',
      ).format(DateTime(currentMonth.year, currentMonth.month + 1, 0));

      final response = await http.get(
        Uri.parse(
          '${AppConfig.baseUrl}/attendance/monthly?classId=$classId&startDate=$startDate&endDate=$endDate',
        ),
        headers: {'Authorization': 'Bearer $token', 'accept': '*/*'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final fetchedStudents = data
            .map((e) => StudentMonthlyAttendance.fromJson(e))
            .toList();

        setState(() {
          students = fetchedStudents;
          isLoading = false;
        });
      } else {
        print("Failed to fetch: ${response.statusCode}");
        setState(() => isLoading = false);
      }
    } catch (e) {
      print("Error: $e");
      setState(() => isLoading = false);
    }
  }

  void goToPreviousMonth() {
    setState(() {
      currentMonth = DateTime(currentMonth.year, currentMonth.month - 1);
    });
    fetch();
  }

  void goToNextMonth() {
    setState(() {
      currentMonth = DateTime(currentMonth.year, currentMonth.month + 1);
    });
    fetch();
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = viewAbsentOnly
        ? students.where((s) => s.totalAbsent > 0).toList()
        : students;

    final totalAbsences = students.fold<double>(
      0,
      (sum, s) => sum + s.totalAbsent,
    );
    final totalWorkingDays = students.isNotEmpty ? students.first.totalDays : 0;
    final totalPossibleAttendances = totalWorkingDays * students.length;
    final absencePercentage = totalPossibleAttendances > 0
        ? (totalAbsences / totalPossibleAttendances) * 100
        : 0;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_left, color: Colors.black),
                    onPressed: goToPreviousMonth,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('MMMM yyyy').format(currentMonth),
                    style: const TextStyle(
                      fontSize: 18,
                      color: Color(0xFF2E3192),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.arrow_right, color: Colors.black),
                    onPressed: goToNextMonth,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                "Total absences: $totalAbsences (${absencePercentage.toStringAsFixed(1)}%)",
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    height: 38,
                    width: 100,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: const BoxDecoration(color: Color(0xFFCCCCCC)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedClass,
                        icon: const Icon(
                          Icons.arrow_drop_down,
                          color: Color(0xFF2E3192),
                        ),
                        style: const TextStyle(
                          color: Color(0xFF29ABE2),
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        onChanged: (String? newValue) {
                          final selected = classSections.firstWhere(
                            (c) => c.fullName == newValue,
                          );
                          setState(() {
                            selectedClass = selected.fullName;
                            selectedClassId = selected.id;
                          });
                          fetch();
                        },
                        items: classSections.map((section) {
                          return DropdownMenuItem<String>(
                            value: section.fullName,
                            child: Text(section.fullName),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Transform.scale(
                        scale: 0.8,
                        child: Checkbox(
                          value: viewAbsentOnly,
                          onChanged: (value) {
                            setState(() {
                              viewAbsentOnly = value!;
                            });
                          },
                        ),
                      ),
                      const Text(
                        "View absence only",
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : filteredList.isEmpty
              ? const Center(
                  child: Text(
                    "No attendance data available.",
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: filteredList.length,
                  itemBuilder: (context, index) {
                    final student = filteredList[index];
                    final isFullyPresent = student.totalAbsent == 0;

                    return ListTile(
                      title: Text(
                        student.fullName,
                        style: const TextStyle(color: Colors.black),
                      ),
                      subtitle: Text(
                        "Present: ${student.totalPresent}, Absent: ${student.totalAbsent}",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      trailing: isFullyPresent
                          ? const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check, color: Colors.green),
                                SizedBox(width: 4),
                                Text(
                                  "Present",
                                  style: TextStyle(color: Colors.green),
                                ),
                              ],
                            )
                          : Text(
                              "✘ ${student.totalAbsent} absences",
                              style: const TextStyle(color: Colors.red),
                            ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class TeacherAttendanceYearTab extends StatefulWidget {
  const TeacherAttendanceYearTab({super.key});

  @override
  State<TeacherAttendanceYearTab> createState() =>
      _TeacherAttendanceYearTabState();
}

class _TeacherAttendanceYearTabState extends State<TeacherAttendanceYearTab> {
  int selectedYear = DateTime.now().year;

  String? selectedClass;
  int? selectedClassId;
  List<ClassSection> classSections = [];

  bool viewAbsentOnly = false;
  bool isLoading = true;
  List<StudentMonthlyAttendance> students = [];

  @override
  void initState() {
    super.initState();
    loadClassSections();
  }

  Future<void> loadClassSections() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/master/classes'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final loadedSections = data
            .map((e) => ClassSection.fromJson(e))
            .toList();

        setState(() {
          classSections = loadedSections;
          if (classSections.isNotEmpty) {
            selectedClass = classSections.first.fullName;
            selectedClassId = classSections.first.id;
          }
        });

        fetch(); // Call fetch() after classSections are loaded
      }
    } catch (e) {
      print('Failed to load class sections: $e');
    }
  }

  Future<void> fetch() async {
    setState(() => isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';

      final classId = selectedClassId;
      if (classId == null) return;

      final startDate = "$selectedYear-01-01";
      final endDate = "$selectedYear-12-31";

      final response = await http.get(
        Uri.parse(
          '${AppConfig.baseUrl}/attendance/monthly?classId=$classId&startDate=$startDate&endDate=$endDate',
        ),
        headers: {'Authorization': 'Bearer $token', 'accept': '*/*'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final fetchedStudents = data
            .map((e) => StudentMonthlyAttendance.fromJson(e))
            .toList();

        setState(() {
          students = fetchedStudents;
          isLoading = false;
        });
      } else {
        print("Failed to fetch: ${response.statusCode}");
        setState(() => isLoading = false);
      }
    } catch (e) {
      print("Error: $e");
      setState(() => isLoading = false);
    }
  }

  void _changeYear(int offset) {
    setState(() {
      selectedYear += offset;
      isLoading = true;
    });
    fetch();
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = viewAbsentOnly
        ? students.where((s) => s.totalAbsent > 0).toList()
        : students;

    final totalAbsences = students.fold<double>(
      0,
      (sum, s) => sum + s.totalAbsent,
    );
    final totalWorkingDays = students.isNotEmpty ? students.first.totalDays : 0;
    final totalPossibleAttendances = totalWorkingDays * students.length;
    final absencePercentage = totalPossibleAttendances > 0
        ? (totalAbsences / totalPossibleAttendances) * 100
        : 0;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_left,
                      size: 28,
                      color: Colors.black,
                    ),
                    onPressed: () => _changeYear(-1),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "$selectedYear",
                    style: const TextStyle(
                      fontSize: 18,
                      color: Color(0xFF2E3192),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_right,
                      size: 28,
                      color: Colors.black,
                    ),
                    onPressed: () => _changeYear(1),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                "Total absences: $totalAbsences (${absencePercentage.toStringAsFixed(1)}%)",
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    height: 38,
                    width: 100,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: const BoxDecoration(color: Color(0xFFCCCCCC)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedClass,
                        icon: const Icon(
                          Icons.arrow_drop_down,
                          color: Color(0xFF2E3192),
                        ),
                        style: const TextStyle(
                          color: Color(0xFF29ABE2),
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        onChanged: (String? newValue) {
                          final selected = classSections.firstWhere(
                            (c) => c.fullName == newValue,
                          );
                          setState(() {
                            selectedClass = selected.fullName;
                            selectedClassId = selected.id;
                          });
                          fetch();
                        },

                        items: classSections.map((section) {
                          return DropdownMenuItem<String>(
                            value: section.fullName,
                            child: Text(section.fullName),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Transform.scale(
                        scale: 0.8,
                        child: Checkbox(
                          value: viewAbsentOnly,
                          onChanged: (value) {
                            setState(() {
                              viewAbsentOnly = value!;
                            });
                          },
                        ),
                      ),
                      const Text(
                        "View absence only",
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : filteredList.isEmpty
              ? const Center(
                  child: Text(
                    "No attendance data available.",
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: filteredList.length,
                  itemBuilder: (context, index) {
                    final student = filteredList[index];
                    final isFullyPresent = student.totalAbsent == 0;

                    return ListTile(
                      title: Text(
                        student.fullName,
                        style: const TextStyle(color: Colors.black),
                      ),
                      subtitle: Text(
                        "Present: ${student.totalPresent}, Absent: ${student.totalAbsent}",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      trailing: isFullyPresent
                          ? const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check, color: Colors.green),
                                SizedBox(width: 4),
                                Text(
                                  "Present",
                                  style: TextStyle(color: Colors.green),
                                ),
                              ],
                            )
                          : Text(
                              "✘ ${student.totalAbsent} absences",
                              style: const TextStyle(color: Colors.red),
                            ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
