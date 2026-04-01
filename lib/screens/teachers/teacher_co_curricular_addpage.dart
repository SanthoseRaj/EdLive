import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:school_app/config/config.dart';
import 'package:school_app/screens/teachers/teacher_menu_drawer.dart';
import 'package:school_app/widgets/teacher_app_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '/models/teacher_student_classsection.dart';
import '/services/co_curricular_activities_service.dart';
import '/services/co_curricular_cateogries_service.dart';
import '/services/teacher_class_section_service.dart';
import '/services/teacher_student_classsection.dart';

class AddedCoCurricularStat {
  final String activityName;
  final String categoryName;
  final String className;

  const AddedCoCurricularStat({
    required this.activityName,
    required this.categoryName,
    required this.className,
  });
}

class CoCurricularPageResult {
  final bool didChange;
  final AddedCoCurricularStat? latestAddedStat;

  const CoCurricularPageResult({required this.didChange, this.latestAddedStat});
}

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
  int? selectedActivity;

  final TextEditingController remarksController = TextEditingController();
  bool isLoadingClasses = true;
  bool isLoadingStudents = false;
  bool isSubmitting = false;
  bool _didUpdateEnrollments = false;
  AddedCoCurricularStat? _latestAddedStat;

  @override
  void initState() {
    super.initState();
    loadClassSections();
  }

  @override
  void dispose() {
    remarksController.dispose();
    super.dispose();
  }

  String get _academicYear {
    if (AppConfig.academicYear.isNotEmpty) {
      return AppConfig.academicYear;
    }

    final now = DateTime.now();
    final startYear = now.month >= 6 ? now.year : now.year - 1;
    return '$startYear-${startYear + 1}';
  }

  String? get _selectedActivityName {
    if (selectedActivity == null) {
      return null;
    }

    for (final activity in allActivities) {
      if (activity.id == selectedActivity) {
        return activity.name;
      }
    }

    return null;
  }

  void _closePage() {
    Navigator.pop(
      context,
      CoCurricularPageResult(
        didChange: _didUpdateEnrollments,
        latestAddedStat: _latestAddedStat,
      ),
    );
  }

  Future<void> loadClassSections() async {
    try {
      final service = TeacherClassService();
      final sections = await service.fetchTeacherClasses();

      if (!mounted) {
        return;
      }

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
      if (!mounted) {
        return;
      }

      setState(() => isLoadingClasses = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load teacher classes: $e')),
      );
    }
  }

  Future<void> loadStudents({int? classId}) async {
    if (!mounted) {
      return;
    }

    setState(() => isLoadingStudents = true);
    try {
      final service = StudentService();
      final data = await service.fetchStudents();

      if (!mounted) {
        return;
      }

      setState(() {
        students = data;
        selectedStudent = students.isNotEmpty ? students.first : null;
        isLoadingStudents = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() => isLoadingStudents = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to load students')));
    }
  }

  Future<void> loadCategories() async {
    try {
      final cats = await CoCurricularCategoryService.fetchCategories();

      if (!mounted) {
        return;
      }

      setState(() {
        categories = cats;
        selectedCategoryObj = categories.isNotEmpty ? categories.first : null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load categories')),
      );
    }
  }

  Future<void> loadActivitiesByCategory(int categoryId) async {
    try {
      final activities = await CoCurricularService.fetchActivitiesByCategory(
        categoryId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        allActivities = activities;
        selectedActivity = activities.isNotEmpty ? activities.first.id : null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load activities')),
      );
    }
  }

  Future<void> enrollStudent() async {
    if (selectedStudent == null ||
        selectedClass == null ||
        selectedCategoryObj == null ||
        selectedActivity == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select all fields')));
      return;
    }

    setState(() => isSubmitting = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      final selectedActivityName = _selectedActivityName;

      final body = jsonEncode({
        "studentId": selectedStudent!.id,
        "activityId": selectedActivity,
        "classId": selectedClass!.id,
        "categoryId": selectedCategoryObj!.id,
        "academicYear": _academicYear,
        "remarks": remarksController.text.trim(),
      });

      final response = await http.post(
        AppConfig.apiUri('/co-curricular/enroll'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      if (!mounted) {
        return;
      }

      if (response.statusCode == 201) {
        _didUpdateEnrollments = true;
        if (selectedActivityName != null) {
          _latestAddedStat = AddedCoCurricularStat(
            activityName: selectedActivityName,
            categoryName: selectedCategoryObj!.name,
            className: selectedClass!.fullName,
          );
        }
        remarksController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Student enrolled successfully')),
        );
      } else if (response.body.toLowerCase().contains('duplicate key')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This student is already enrolled in this activity'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to enroll: ${response.statusCode} ${response.body}',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) {
        setState(() => isSubmitting = false);
      }
    }
  }

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
        AppConfig.apiUri(
          '/co-curricular/remove',
          queryParameters: {
            'studentId': selectedStudent!.id,
            'activityId': selectedActivity,
          },
        ),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (!mounted) {
        return;
      }

      if (response.statusCode == 200) {
        _didUpdateEnrollments = true;
        _latestAddedStat = null;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Student removed from activity')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to remove: ${response.statusCode} ${response.body}',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        _closePage();
      },
      child: Scaffold(
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
                GestureDetector(
                  onTap: _closePage,
                  child: const Text(
                    '< Back',
                    style: TextStyle(color: Colors.black, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
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
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Class',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      DropdownButtonFormField<TeacherClass>(
                                        initialValue: selectedClass,
                                        items: classSections
                                            .map(
                                              (teacherClass) =>
                                                  DropdownMenuItem(
                                                    value: teacherClass,
                                                    child: Text(
                                                      teacherClass.fullName,
                                                    ),
                                                  ),
                                            )
                                            .toList(),
                                        onChanged: (value) async {
                                          setState(() {
                                            selectedClass = value;
                                            selectedStudent = null;
                                            students = [];
                                          });
                                          if (value != null) {
                                            await loadStudents(
                                              classId: value.id,
                                            );
                                          }
                                        },
                                        decoration: InputDecoration(
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderSide: BorderSide(
                                              color: Colors.grey.shade400,
                                              width: 1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderSide: const BorderSide(
                                              color: Color(0xFF2E3192),
                                              width: 2,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 10,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'Student Name',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      isLoadingStudents
                                          ? const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            )
                                          : DropdownButtonFormField<
                                              StudentClassSection
                                            >(
                                              initialValue: selectedStudent,
                                              items: students
                                                  .map(
                                                    (student) =>
                                                        DropdownMenuItem(
                                                          value: student,
                                                          child: Text(
                                                            student.name,
                                                          ),
                                                        ),
                                                  )
                                                  .toList(),
                                              onChanged: (value) {
                                                setState(() {
                                                  selectedStudent = value;
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
                                      const Text(
                                        'Category Name',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      DropdownButtonFormField<
                                        CoCurricularCategory
                                      >(
                                        initialValue: selectedCategoryObj,
                                        items: categories
                                            .map(
                                              (category) => DropdownMenuItem(
                                                value: category,
                                                child: Text(category.name),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: (value) async {
                                          setState(() {
                                            selectedCategoryObj = value;
                                            allActivities = [];
                                            selectedActivity = null;
                                          });
                                          if (value != null) {
                                            await loadActivitiesByCategory(
                                              value.id,
                                            );
                                          }
                                        },
                                        decoration: InputDecoration(
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'Activity Name',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      DropdownButtonFormField<
                                        CoCurricularActivity
                                      >(
                                        initialValue:
                                            selectedActivity == null ||
                                                allActivities.isEmpty
                                            ? null
                                            : allActivities.firstWhere(
                                                (activity) =>
                                                    activity.id ==
                                                    selectedActivity,
                                                orElse: () =>
                                                    allActivities.first,
                                              ),
                                        items: allActivities
                                            .map(
                                              (activity) => DropdownMenuItem(
                                                value: activity,
                                                child: Text(activity.name),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: (value) {
                                          setState(() {
                                            selectedActivity = value?.id;
                                          });
                                        },
                                        decoration: InputDecoration(
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'Remarks',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      TextField(
                                        controller: remarksController,
                                        maxLines: 3,
                                        decoration: InputDecoration(
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 16,
                                  bottom: 20,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: removeStudentEnrollment,
                                        child: Container(
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade400,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
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
                                        onTap: isSubmitting
                                            ? null
                                            : enrollStudent,
                                        child: Container(
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF29ABE2),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Center(
                                            child: isSubmitting
                                                ? const SizedBox(
                                                    height: 20,
                                                    width: 20,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: Colors.white,
                                                        ),
                                                  )
                                                : const Text(
                                                    "Add",
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.w600,
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
      ),
    );
  }
}
