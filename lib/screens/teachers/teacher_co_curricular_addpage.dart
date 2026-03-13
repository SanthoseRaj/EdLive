import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:school_app/screens/teachers/teacher_menu_drawer.dart';
import 'package:school_app/widgets/teacher_app_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_svg/flutter_svg.dart';

import '/models/class_section.dart';
import '/models/cocurricular_activity_model.dart';
import '/models/teacher_student_classsection.dart';

import '/services/class_section_service.dart';
import '/services/teacher_class_section_service.dart';
import '/services/teacher_student_classsection.dart';
import '/services/co_curricular_cateogries_service.dart';
import '/services/co_curricular_activities_service.dart';

class AddCoCurricularActivityPage extends StatefulWidget {
  const AddCoCurricularActivityPage({super.key});

  @override
  State<AddCoCurricularActivityPage> createState() =>
      _AddCoCurricularActivityPageState();
}

class _AddCoCurricularActivityPageState
    extends State<AddCoCurricularActivityPage> {
  List<TeacherClass> classSections = [];
  TeacherClass? selectedClass;

  List<StudentClassSection> students = [];
  StudentClassSection? selectedStudent;

  List<CoCurricularCategory> categories = [];
  CoCurricularCategory? selectedCategoryObj;

  List<CoCurricularActivity> allActivities = [];
  List<String> activityNames = [];
  int? selectedActivity;

  TextEditingController remarksController = TextEditingController();
  bool isLoadingClasses = true;
  bool isLoadingStudents = false;
  bool isSubmitting = false;

  @override
  void initState() {
    super.initState();
    loadClassSections();
  }

  /// Load classes handled by teacher
  Future<void> loadClassSections() async {
    try {
      final service = TeacherClassService();
      final sections = await service.fetchTeacherClasses();

      setState(() {
        classSections = sections;
        selectedClass = classSections.isNotEmpty ? classSections.first : null;
        isLoadingClasses = false;
      });

      await loadStudents(classId: selectedClass?.id);
      await loadCategories();

      if (selectedCategoryObj != null) {
        await loadActivitiesByCategory(selectedCategoryObj!.id);
      }
    } catch (e) {
      setState(() => isLoadingClasses = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load teacher classes: $e')),
      );
    }
  }

  /// Load students of a class
  Future<void> loadStudents({int? classId}) async {
    setState(() => isLoadingStudents = true);
    try {
      final service = StudentService();
      final data = await service.fetchStudents();

      setState(() {
        students = data;
        selectedStudent = students.isNotEmpty ? students.first : null;
        isLoadingStudents = false;
      });
    } catch (e) {
      setState(() => isLoadingStudents = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load students')),
      );
    }
  }

  /// Load categories
  Future<void> loadCategories() async {
    try {
      final cats = await CoCurricularCategoryService.fetchCategories();
      setState(() {
        categories = cats;
        selectedCategoryObj = categories.isNotEmpty ? categories.first : null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load categories')),
      );
    }
  }

  /// Load activities by category
  Future<void> loadActivitiesByCategory(int categoryId) async {
    try {
      final activities =
          await CoCurricularService.fetchActivitiesByCategory(categoryId);

      setState(() {
        allActivities = activities;
        activityNames = activities.map((e) => e.name).toList();
        selectedActivity =
            activities.isNotEmpty ? activities.first.id : null; // ✅ use id
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load activities')),
      );
    }
  }

  /// Enroll a student in activity
  Future<void> enrollStudent() async {
    if (selectedStudent == null ||
        selectedClass == null ||
        selectedCategoryObj == null ||
        selectedActivity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select all fields')),
      );
      return;
    }

    setState(() => isSubmitting = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';

      final body = jsonEncode({
        "studentId": selectedStudent!.id,
        "activityId": selectedActivity,
        "classId": selectedClass!.id,
        "categoryId": selectedCategoryObj!.id,
        "academicYear": "2025-2026",
        "remarks": remarksController.text,
      });

      final response = await http.post(
        Uri.parse(
            'https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api/co-curricular/enroll'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Student enrolled successfully')),
        );
        remarksController.clear();
      } else if (response.body.contains("duplicate key")) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('This student is already enrolled in this activity')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Failed to enroll: ${response.statusCode} ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => isSubmitting = false);
    }
  }

  /// Remove student from activity
  Future<void> removeStudentEnrollment() async {
    if (selectedStudent == null || selectedActivity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select student and activity to remove')),
      );
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';

      final response = await http.delete(
        Uri.parse(
            'https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api/co-curricular/remove'
            '?studentId=${selectedStudent!.id}&activityId=$selectedActivity'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Student removed from activity')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Failed to remove: ${response.statusCode} ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TeacherAppBar(),
      drawer: MenuDrawer(),
   body: Container(
  width: double.infinity,
  height: double.infinity,
  color: const Color(0xFFDBD88A),
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ✅ Back button at top
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Text(
            '< Back',
            style: TextStyle(
              color: Colors.black,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // ✅ Add Activity title just below Back
       Row(
  children: [
    // ✅ Icon with background color
    Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF2E3192),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SvgPicture.asset(
        'assets/icons/co_curricular.svg',
        width: 20,
        height: 20,
        color: Colors.white, // make icon visible on dark bg
      ),
    ),
    const SizedBox(width: 8),

    // ✅ Text
    const Text(
      'Add Activity',
      style: TextStyle(
        color: Color(0xFF2E3192),
        fontWeight: FontWeight.bold,
        fontSize: 24,
      ),
    ),
  ],
),
        const SizedBox(height: 12),

        // ✅ White container for form content
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(16),
            child: isLoadingClasses
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 🔽 Only keep form fields inside the white container
                           const Text(
  'Class',
  style: TextStyle(fontWeight: FontWeight.bold),
),
const SizedBox(height: 5),

DropdownButtonFormField<TeacherClass>(
  value: selectedClass,
  items: classSections
      .map((c) => DropdownMenuItem(
            value: c,
            child: Text(c.fullName),
          ))
      .toList(),
  onChanged: (val) async {
    setState(() {
      selectedClass = val;
      selectedStudent = null;
      students = [];
    });
    if (val != null) {
      await loadStudents(classId: val.id);
    }
  },
  decoration: InputDecoration(
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8), // rounded corners
    ),
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.grey.shade400, width: 1),
      borderRadius: BorderRadius.circular(8),
    ),
    focusedBorder: OutlineInputBorder(
      borderSide: const BorderSide(color: Color(0xFF2E3192), width: 2), // active border color
      borderRadius: BorderRadius.circular(8),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  ),
),

                              const SizedBox(height: 16),

                              // Student Dropdown
                              const Text('Student Name',
                                  style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 5),
                              isLoadingStudents
                                  ? const Center(
                                      child: CircularProgressIndicator())
                                  : DropdownButtonFormField<StudentClassSection>(
                                      value: selectedStudent,
                                      items: students
                                          .map((s) => DropdownMenuItem(
                                                value: s,
                                                child: Text(s.name),
                                              ))
                                          .toList(),
                                      onChanged: (val) {
                                        setState(() {
                                          selectedStudent = val;
                                        });
                                      },
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                              const SizedBox(height: 16),

                              // Category Dropdown
                              const Text('Category Name',
                                  style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 5),
                              DropdownButtonFormField<CoCurricularCategory>(
                                value: selectedCategoryObj,
                                items: categories
                                    .map((c) => DropdownMenuItem(
                                        value: c, child: Text(c.name)))
                                    .toList(),
                                onChanged: (val) async {
                                  setState(() {
                                    selectedCategoryObj = val;
                                    activityNames = [];
                                    selectedActivity = null;
                                  });
                                  if (val != null) {
                                    await loadActivitiesByCategory(val.id);
                                  }
                                },
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Activity Dropdown
                              const Text('Activity Name',
                                  style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 5),
                              DropdownButtonFormField<CoCurricularActivity>(
                                value: (selectedActivity == null ||
                                        allActivities.isEmpty)
                                    ? null
                                    : allActivities.firstWhere(
                                        (a) => a.id == selectedActivity,
                                        orElse: () => allActivities.first,
                                      ),
                                items: allActivities
                                    .map((a) => DropdownMenuItem(
                                          value: a,
                                          child: Text(
                                              "${a.name} "),
                                        ))
                                    .toList(),
                                onChanged: (val) {
                                  setState(() {
                                    selectedActivity = val?.id;
                                  });
                                },
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Remarks
                              const Text('Remarks',
                                  style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 5),
                              TextField(
                                controller: remarksController,
                                maxLines: 3,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ✅ Buttons pinned bottom
                      Padding(
                        padding: const EdgeInsets.only(top: 16, bottom: 20),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: removeStudentEnrollment,
                                child: Container(
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade400,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      "Remove",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GestureDetector(
                                onTap: isSubmitting ? null : enrollStudent,
                                child: Container(
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Color(0xFF29ABE2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: isSubmitting
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text(
                                            "Add",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    ),
  ),
),
             
    
  );}
    }