import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:school_app/widgets/teacher_app_bar.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'teacher_menu_drawer.dart';
import 'teacher_syllabus_detail_page.dart';

import 'package:school_app/models/class_section.dart';
import 'package:school_app/services/class_section_service.dart';
import 'package:school_app/services/teacher_class_section_service.dart';
import 'package:school_app/services/teacher_syllabus_subject_service.dart';
import 'package:school_app/models/teacher_syllabus_subject_model.dart';
import '../../models/teacher_syllabus_model.dart';
import '../../services/teacher_syllabus_service.dart';

class TeacherSyllabusPage extends StatefulWidget {
  const TeacherSyllabusPage({super.key});

  @override
  State<TeacherSyllabusPage> createState() => _TeacherSyllabusPageState();
}

class _TeacherSyllabusPageState extends State<TeacherSyllabusPage> {
  List<ClassSection> _classSections = [];
  ClassSection? _selectedClass;

  List<Subject> _subjects = [];
  bool _loadingClasses = true;
  bool _loadingSubjects = false;

  List<TeacherClass> _teacherClasses = [];
  TeacherClass? _selectedTeacherClass;
  bool _loadingTeacherClasses = true;

  bool isAdding = false;
  TeacherClass? _selectedAddClass;
  Subject? _selectedAddSubject;
  final termController = TextEditingController();

  // Academic Year dropdown
  List<String> _academicYears = [];
  String? _selectedAcademicYear;

  @override
  void initState() {
    super.initState();
    _loadClasses();
    _loadTeacherClasses();

    // Generate last 5 academic years
    final currentYear = DateTime.now().year;
    _academicYears = List.generate(
        5, (i) => '${currentYear - i}-${currentYear - i + 1}');
    _selectedAcademicYear = _academicYears.first;
  }

  Future<bool> _addSyllabus({
    required int classId,
    required int subjectId,
    required String term,
    required String academicYear,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    final url = Uri.parse(
        'https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api/syllabus');
    final body = jsonEncode({
      "class_id": classId,
      "subject_id": subjectId,
      "term": term,
      "academic_year": academicYear,
    });

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      if (response.statusCode == 201) {
        return true;
      } else {
        print('Failed to add syllabus: ${response.statusCode} ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error adding syllabus: $e');
      return false;
    }
  }

  Future<void> _loadTeacherClasses() async {
    try {
      final classes = await TeacherClassService().fetchTeacherClasses();
      setState(() {
        _teacherClasses = classes;
        if (classes.isNotEmpty) _selectedTeacherClass = classes.first;
        _loadingTeacherClasses = false;
      });
    } catch (e) {
      setState(() => _loadingTeacherClasses = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Failed to load teacher classes: $e")));
    }
  }

  Future<void> _loadClasses() async {
    try {
      final classes = await ClassService().fetchClassSections();
      setState(() {
        _classSections = classes;
        if (classes.isNotEmpty) _selectedClass = classes.first;
        _loadingClasses = false;
      });
      if (_selectedClass != null) _loadSubjects(_selectedClass!.id);
    } catch (e) {
      setState(() => _loadingClasses = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Failed to load classes: $e")));
    }
  }

  Future<void> _loadSubjects(int classId) async {
    setState(() => _loadingSubjects = true);
    try {
      final subjects = await SyllabusService().fetchSubjects(classId);
      setState(() {
        _subjects = subjects;
        _loadingSubjects = false;
      });
    } catch (e) {
      setState(() => _loadingSubjects = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Failed to load subjects: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFA7D7A7),
      drawer: MenuDrawer(),
      appBar: TeacherAppBar(),
      body: _loadingClasses
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Back Button
                      Padding(
                        padding: const EdgeInsets.only(left: 15.0, top: 0),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => Navigator.pop(context),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                              child: Text("< Back", style: TextStyle(fontSize: 16)),
                            ),
                          ),
                        ),
                      ),

                      // Title Row
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2E3192),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: SvgPicture.asset(
                                'assets/icons/syllabus.svg',
                                height: 26,
                                width: 26,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Syllabus',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2E3192),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 10),

                      // White Container (Class + Subject List OR Add Form)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 20),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: isAdding
                                ? _buildAddForm()
                                : Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Class Dropdown in list mode
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            const Text(
                                              'Class',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.black,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Container(
                                              width: 120,
                                              height: 30,
                                              padding: const EdgeInsets.symmetric(horizontal: 8),
                                              decoration: BoxDecoration(
                                                border: Border.all(color: Color(0xFF4D4D4D)),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: DropdownButtonHideUnderline(
                                                child: DropdownButton<ClassSection>(
                                                  isExpanded: true,
                                                  icon: const Icon(Icons.arrow_drop_down,
                                                      color: Color(0xFF808080)),
                                                  value: _selectedClass,
                                                  items: _classSections.map((cls) {
                                                    return DropdownMenuItem(
                                                      value: cls,
                                                      child: Text(
                                                        cls.fullName,
                                                        style: const TextStyle(color: Color(0xFF666666)),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    );
                                                  }).toList(),
                                                  onChanged: (val) {
                                                    if (val == null) return;
                                                    setState(() => _selectedClass = val);
                                                    _loadSubjects(val.id);
                                                  },
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      const SizedBox(height: 12),

                                      // Subject List
                                      Expanded(
                                        child: _loadingSubjects
                                            ? const Center(child: CircularProgressIndicator())
                                            : ListView.builder(
                                                itemCount: _subjects.length,
                                                itemBuilder: (context, index) {
                                                  final subject = _subjects[index];
                                                  return InkWell(
  onTap: () {
    if (_selectedClass == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SyllabusDetailPage(
          classId: _selectedClass!.id,
          subjectId: subject.id,
          selectedClass: _selectedClass!.fullName,
          subject: subject.name,
        ),
      ),
    );
  },
  child: Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black12,
          blurRadius: 6,
          offset: const Offset(0, 3),
        ),
      ],
      border: Border.all(color: Colors.grey.shade200),
    ),
    child: Row(
      children: [
        // Icon with colored background
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF29ABE2).withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SvgPicture.asset(
            'assets/icons/book.svg', // your subject icon
            height: 22,
            width: 22,
            color: const Color(0xFF29ABE2),
          ),
        ),
        const SizedBox(width: 16),

        // Subject name + subtitle
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                subject.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E3192),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Click to view syllabus',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),

        // Arrow icon
        SvgPicture.asset(
          'assets/icons/arrow_right.svg',
          height: 18,
          width: 18,
          color: Colors.grey.shade400,
        ),
      ],
    ),
  ),
);
 },
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

                // Add Button
                Positioned(
                  top: 50,
                  right: 16,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() => isAdding = true);
                    },
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text("Add a subject"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF29ABE2),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildAddForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Class Dropdown
          const Text("Select Class", style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
          const SizedBox(height: 6),
          DropdownButtonFormField<TeacherClass>(
            value: _selectedAddClass,
            isExpanded: true,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            hint: const Text("Select Class"),
            items: _teacherClasses.map((cls) {
              return DropdownMenuItem(
                value: cls,
                child: Text(cls.fullName),
              );
            }).toList(),
            onChanged: (val) => setState(() => _selectedAddClass = val),
          ),
          const SizedBox(height: 16),

          // Subject Dropdown
          const Text("Select Subject", style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
          const SizedBox(height: 6),
          DropdownButtonFormField<Subject>(
            value: _selectedAddSubject,
            isExpanded: true,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            hint: const Text("Select Subject"),
            items: _subjects.map((sub) {
              return DropdownMenuItem(
                value: sub,
                child: Text(sub.name),
              );
            }).toList(),
            onChanged: (val) => setState(() => _selectedAddSubject = val),
          ),
          const SizedBox(height: 16),

          // Term
          const Text("Enter Term", style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
          const SizedBox(height: 6),
          TextField(
            controller: termController,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
          const SizedBox(height: 16),

          // Academic Year Dropdown
        // Academic Year (editable)
const Text("Academic Year", style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
const SizedBox(height: 6),
TextField(
  controller: TextEditingController(
      text: "${DateTime.now().year}-${DateTime.now().year + 1}"), // initial value
  decoration: InputDecoration(
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  ),
  onChanged: (val) {
    _selectedAcademicYear = val; // update state when edited
  },
),
const SizedBox(height: 16),
   const SizedBox(height: 16),

          const Spacer(),

          // Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => setState(() => isAdding = false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text("Cancel",style:TextStyle( color:Colors.white,)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    if (_selectedAddClass != null &&
                        _selectedAddSubject != null &&
                        _selectedAcademicYear != null) {
                      final success = await _addSyllabus(
                        classId: _selectedAddClass!.id,
                        subjectId: _selectedAddSubject!.id,
                        term: termController.text.trim(),
                        academicYear: _selectedAcademicYear!,
                      );
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Syllabus added successfully')),
                        );
                        setState(() {
                          isAdding = false;
                          _loadSubjects(_selectedAddClass!.id);
                        });
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Failed to add syllabus')),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF29ABE2),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text("Save",style:TextStyle( color:Colors.white,)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
