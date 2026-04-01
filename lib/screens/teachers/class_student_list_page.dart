import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:school_app/config/config.dart';

import '../../models/teacher_class_student.dart';
import '../../services/teacher_class_student_list.dart';
import '/services/teacher_class_section_service.dart';
import '../students/student_profile_page.dart';
// import 'class_teacher_student_details_page.dart';

class ClassStudentListPage extends StatefulWidget {
  const ClassStudentListPage({super.key});

  @override
  State<ClassStudentListPage> createState() => _ClassStudentListPageState();
}

class _ClassStudentListPageState extends State<ClassStudentListPage> {
  List<Student> students = [];
  List<TeacherClass> teacherClasses = [];
  Map<int, String> studentImageUrls = {};

  bool isLoading = true;
  String? selectedClassId;
  String? selectedClassName;

  @override
  void initState() {
    super.initState();
    fetchClasses();
  }

  Future<void> fetchClasses() async {
    try {
      final service = TeacherClassService();
      final fetchedClasses = await service.fetchTeacherClasses();

      setState(() {
        teacherClasses = fetchedClasses;
        if (teacherClasses.isNotEmpty) {
          selectedClassId = teacherClasses.first.id.toString();
          selectedClassName = teacherClasses.first.fullName;
        }
      });

      if (selectedClassId != null) {
        await fetchStudentsForClass(selectedClassId!);
      }
    } catch (e) {
      debugPrint("Error fetching classes: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchStudentsForClass(String classId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';

      final fetchedStudents = await StudentService.fetchStudents(token);
      final initialImageUrls = <int, String>{};

      for (final student in fetchedStudents) {
        final imagePath = student.profileImagePath?.trim();
        if (imagePath != null && imagePath.isNotEmpty) {
          initialImageUrls[student.id] = imagePath;
        }
      }

      setState(() {
        students = fetchedStudents;
        studentImageUrls = initialImageUrls;
        isLoading = false;
      });

      await _loadStudentProfileImages(token, fetchedStudents);
    } catch (e) {
      debugPrint("Error fetching students: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadStudentProfileImages(
    String token,
    List<Student> studentList,
  ) async {
    final missingStudents = studentList
        .where((student) => !studentImageUrls.containsKey(student.id))
        .toList();

    if (missingStudents.isEmpty) {
      return;
    }

    final loadedEntries = await Future.wait(
      missingStudents.map((student) async {
        try {
          final response = await http.get(
            AppConfig.apiUri('/student/students/${student.id}'),
            headers: {'Authorization': 'Bearer $token', 'accept': '*/*'},
          );

          if (response.statusCode != 200) {
            return MapEntry(student.id, null);
          }

          final payload = jsonDecode(response.body) as Map<String, dynamic>;
          return MapEntry(student.id, _extractProfileImagePath(payload));
        } catch (_) {
          return MapEntry(student.id, null);
        }
      }),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      for (final entry in loadedEntries) {
        final imagePath = entry.value?.trim();
        if (imagePath != null && imagePath.isNotEmpty) {
          studentImageUrls[entry.key] = imagePath;
        }
      }
    });
  }

  String? _extractProfileImagePath(Map<String, dynamic> payload) {
    for (final key in const [
      'profile_img',
      'profileImage',
      'profile_image',
      'image',
    ]) {
      final value = payload[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Select your class',
                              style: TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: 120,
                              height: 40,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFCCCCCC),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: selectedClassId,
                                underline: const SizedBox(),
                                icon: const Icon(Icons.arrow_drop_down),
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Color(0xFF29ABE2),
                                  fontWeight: FontWeight.bold,
                                ),
                                items: teacherClasses.map((cls) {
                                  return DropdownMenuItem(
                                    value: cls.id.toString(),
                                    child: Text(cls.fullName),
                                  );
                                }).toList(),
                                onChanged: (value) async {
                                  setState(() {
                                    selectedClassId = value;
                                    selectedClassName = teacherClasses
                                        .firstWhere(
                                          (c) => c.id.toString() == value,
                                        )
                                        .fullName;
                                    isLoading = true;
                                  });
                                  await fetchStudentsForClass(value!);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${students.length} students',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'You are class teacher',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  students.isEmpty
                      ? const Center(child: Text('No students in this class.'))
                      : Column(
                          children: students.asMap().entries.map((entry) {
                            final index = entry.key + 1;
                            final student = entry.value;
                            return _StudentRow(
                              name: '$index. ${student.studentName}',
                              imageUrl:
                                  studentImageUrls[student.id] ??
                                  student.profileImagePath,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    // builder: (_) =>
                                    //     StudentDetailPage(studentId: student.id),
                                    builder: (_) => StudentProfilePage(
                                      studentId: student.id,
                                      isTeacherView: true,
                                    ),
                                  ),
                                );
                              },
                            );
                          }).toList(),
                        ),
                ],
              ),
            ),
    );
  }
}

class _StudentRow extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final VoidCallback onTap;

  const _StudentRow({required this.name, this.imageUrl, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final trimmedImageUrl = imageUrl?.trim() ?? '';

    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey,
                backgroundImage: trimmedImageUrl.isNotEmpty
                    ? NetworkImage(AppConfig.absoluteUrl(trimmedImageUrl))
                    : null,
                child: trimmedImageUrl.isEmpty
                    ? const Icon(Icons.person, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(name)),
            ],
          ),
          const Divider(color: Colors.grey, thickness: 0.5, height: 16),
        ],
      ),
    );
  }
}
