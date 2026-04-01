import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

import 'package:school_app/models/achievement_model.dart';
import 'package:school_app/models/class_section.dart';
import 'package:school_app/models/teacher_student_classsection.dart';

import 'package:school_app/providers/teacher_achievement_provider.dart';

import 'package:school_app/screens/teachers/teacher_menu_drawer.dart';

import 'package:school_app/services/class_section_service.dart';
import 'package:school_app/services/teacher_student_classsection.dart';
import 'package:school_app/widgets/teacher_app_bar.dart';

class AddTeacherAchievementPage extends StatefulWidget {
  const AddTeacherAchievementPage({super.key});

  @override
  State<AddTeacherAchievementPage> createState() =>
      _TeacherAchievementPageState();
}

class _TeacherAchievementPageState extends State<AddTeacherAchievementPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _awardedByController = TextEditingController();
  final TextEditingController _academicYearController = TextEditingController();

  int? _categoryId = 1;
  int? _classId;
  int? _studentId;
  String _visibility = "school";
  DateTime? _selectedDate;

  List<ClassSection> _classSections = [];
  List<StudentClassSection> _students = [];
  bool _loadingClasses = true;
  bool _loadingStudents = false;

  int? _selectedStudentId;

  // File upload variables
  File? _selectedFile; // mobile
  Uint8List? _selectedFileBytes; // web
  String? _selectedFileName; // web

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    try {
      final service = ClassService();
      final classes = await service.fetchClassSections();
      setState(() {
        _classSections = classes;
        if (_classSections.isNotEmpty) {
          _classId = _classSections.first.id;
          _loadStudentsForClass(_classId!);
        }
        _loadingClasses = false;
      });
    } catch (e) {
      setState(() => _loadingClasses = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error loading classes: $e")));
    }
  }

 Future<void> _loadStudentsForClass(int classId) async {
  setState(() {
    _loadingStudents = true;
    _students = [];
    _selectedStudentId = null;
    _studentId = null;
  });

  try {
    final service = StudentService();
    final students = await service.fetchStudents();

    // Since the student API does not provide classId, show all students
    final filtered = students; 

    setState(() {
      _students = filtered;
      if (_students.isNotEmpty) {
        _selectedStudentId = _students.first.id;
        _studentId = _students.first.id;
      }
      _loadingStudents = false;
    });
  } catch (e) {
    setState(() => _loadingStudents = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text("Error loading students: $e")));
  }
}

  Future<void> _submit(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;
    if (_classId == null || _studentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select class and student")));
      return;
    }
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Please select a date")));
      return;
    }

    final categoryMap = {
      1: "academic",
      2: "sports",
      3: "arts",
      4: "leadership",
      5: "community_service",
    };

    final categoryString = categoryMap[_categoryId];
    if (categoryString == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid category selected")));
      return;
    }

    final achievement = Achievement(
      studentId: _studentId!,
      title: _titleController.text,
      description: _descController.text,
      categoryId: categoryString,
      achievementDate: _selectedDate!.toIso8601String().split("T").first,
      awardedBy: _awardedByController.text,
      evidenceUrl: "",
      isVisible: _visibility,
      classId: _classId!,
      academicYearId: int.tryParse(_academicYearController.text) ?? 2024,
    );

    try {
      await Provider.of<AchievementProvider>(context, listen: false)
          .addAchievement(
        achievement,
        file: _selectedFile,
        webFileBytes: _selectedFileBytes,
        webFileName: _selectedFileName,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Achievement added successfully"),
          backgroundColor: Colors.green,
        ),
      );

      _resetForm();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to add achievement: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _resetForm() {
    if (!mounted) return;
    setState(() {
      _titleController.clear();
      _descController.clear();
      _awardedByController.clear();
      _academicYearController.clear();
      _selectedDate = null;
      _categoryId = 1;
      _visibility = "school";
      _selectedFile = null;
      _selectedFileBytes = null;
      _selectedFileName = null;

      if (_classSections.isNotEmpty) _classId = _classSections.first.id;
      if (_students.isNotEmpty) {
        _selectedStudentId = _students.first.id;
        _studentId = _students.first.id;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final loading = context.watch<AchievementProvider>().loading;

    return Scaffold(
      appBar: TeacherAppBar(),
      drawer: const MenuDrawer(),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Container(
              color: const Color(0xFFFCEE21),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text("< Back",
                          style: TextStyle(fontSize: 16, color: Colors.black)),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2E3192),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: SvgPicture.asset(
                            'assets/icons/achievements.svg',
                            height: 24,
                            width: 24,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          "Add Achievement",
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2E3192)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 15,
                              spreadRadius: 2,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: ListView(
                            children: [
                              const Divider(),
                              const SizedBox(height: 12),
                              const Text(
                                "🎓 Student Information",
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87),
                              ),
                              const SizedBox(height: 12),
                              _loadingClasses
                                  ? const Center(child: CircularProgressIndicator())
                                  : DropdownButtonFormField<int>(
                                      value: _classId,
                                      decoration: InputDecoration(
                                        labelText: "Select Class",
                                        filled: true,
                                        fillColor: Colors.grey.shade50,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(14),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                      items: _classSections
                                          .map(
                                            (c) => DropdownMenuItem<int>(
                                              value: c.id,
                                              child: Text(c.fullName),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() => _classId = val);
                                          _loadStudentsForClass(val);
                                        }
                                      },
                                      validator: (val) =>
                                          val == null ? "Select a class" : null,
                                    ),
                              const SizedBox(height: 12),
                              _loadingStudents
                                  ? const Center(child: CircularProgressIndicator())
                                  : DropdownButtonFormField<int>(
                                      value: _selectedStudentId,
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                        labelText: "Select Student",
                                        filled: true,
                                        fillColor: Colors.grey.shade50,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(14),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                      items: _students
                                          .map((s) => DropdownMenuItem<int>(
                                                value: s.id,
                                                child: Text(s.name),
                                              ))
                                          .toList(),
                                      onChanged: (val) {
                                        setState(() {
                                          _selectedStudentId = val;
                                          _studentId = val;
                                        });
                                      },
                                      validator: (val) =>
                                          val == null ? "Select a student" : null,
                                    ),
                              const SizedBox(height: 20),
                              const Divider(),
                              const SizedBox(height: 12),
                              const Text(
                                "🏆 Achievement Details",
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _titleController,
                                decoration: InputDecoration(
                                  labelText: "Title",
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                validator: (val) =>
                                    val!.isEmpty ? "Enter achievement title" : null,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _descController,
                                maxLines: 3,
                                decoration: InputDecoration(
                                  labelText: "Description",
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                validator: (val) =>
                                    val!.isEmpty ? "Enter description" : null,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _awardedByController,
                                decoration: InputDecoration(
                                  labelText: "Awarded By",
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                validator: (val) =>
                                    val!.isEmpty ? "Enter awarded by" : null,
                              ),
                              const SizedBox(height: 12),
                              Text("Evidence Upload (Optional)", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                              const SizedBox(height: 6),
ElevatedButton.icon(
  onPressed: () async {
    if (kIsWeb) {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'jpg', 'jpeg', 'png', 'gif', 'webp', // Images including WebP
          'pdf', 'doc', 'docx', // Documents
          'txt', // Text files
        ],
        allowMultiple: false,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFileBytes = result.files.first.bytes;
          _selectedFileName = result.files.first.name;
          _selectedFile = null;
        });
      }
    } else {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'jpg', 'jpeg', 'png', 'gif', 'webp', // WebP added here
          'pdf', 'doc', 'docx',
          'txt',
        ],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty && result.files.first.path != null) {
        setState(() {
          _selectedFile = File(result.files.first.path!);
          _selectedFileName = result.files.first.name;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("File selection failed")),
        );
      }
    }
  },
  icon: const Icon(Icons.upload_file),
  label: Text(
    (_selectedFile != null
        ? "Selected: ${_selectedFile!.path.split('/').last}"
        : _selectedFileName != null
            ? "Selected: $_selectedFileName"
            : "Choose File (Image)"),
  ),
),  const SizedBox(height: 16),
                              TextFormField(
                                controller: _academicYearController,
                                keyboardType: TextInputType.number,
                                maxLength: 4,
                                decoration: InputDecoration(
                                  labelText: "Academic Year",
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide.none,
                                  ),
                                  counterText: "",
                                ),
                                validator: (val) {
                                  if (val == null || val.isEmpty) return "Enter academic year";
                                  if (int.tryParse(val) == null) return "Enter a valid year";
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _selectedDate == null
                                            ? "Date not selected"
                                            : "Date: ${_selectedDate!.toString().split(' ').first}",
                                        style: const TextStyle(fontSize: 15),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.calendar_today, color: Colors.black87),
                                      onPressed: () async {
                                        final picked = await showDatePicker(
                                          context: context,
                                          initialDate: DateTime.now(),
                                          firstDate: DateTime(2000),
                                          lastDate: DateTime(2100),
                                        );
                                        if (picked != null) setState(() => _selectedDate = picked);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<int>(
                                value: _categoryId,
                                decoration: InputDecoration(
                                  labelText: "Category",
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 1, child: Text("Academic")),
                                  DropdownMenuItem(value: 2, child: Text("Sports")),
                                  DropdownMenuItem(value: 3, child: Text("Arts")),
                                  DropdownMenuItem(value: 4, child: Text("Leadership")),
                                  DropdownMenuItem(value: 5, child: Text("Community Service")),
                                ],
                                onChanged: (val) => setState(() => _categoryId = val),
                                validator: (val) => val == null ? "Select a category" : null,
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                value: _visibility,
                                decoration: InputDecoration(
                                  labelText: "Visibility",
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                items: const [
                                  DropdownMenuItem(value: "school", child: Text("School (All Students)")),
                                  DropdownMenuItem(value: "public", child: Text("Public (Everyone)")),
                                  DropdownMenuItem(value: "class", child: Text("Class (Classmates)")),
                                  DropdownMenuItem(value: "private", child: Text("Private (Only Admins)")),
                                ],
                                onChanged: (val) => setState(() => _visibility = val ?? "school"),
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.indigo,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    elevation: 3,
                                  ),
                                  onPressed: () => _submit(context),
                                  child: const Text("Submit Achievement", style: TextStyle(fontSize: 16, color: Colors.white)),
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
            ),
    );
  }
}
