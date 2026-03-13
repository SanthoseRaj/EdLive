import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_svg/svg.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:school_app/widgets/teacher_app_bar.dart';
import 'teacher_menu_drawer.dart';

import 'package:school_app/services/announce_exam_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:school_app/models/exam_type_model.dart';
import 'package:school_app/services/exam_type_service.dart';

class AnnounceClassTestPage extends StatefulWidget {
  final int? examId;
  final String className;

  const AnnounceClassTestPage({Key? key, this.examId, required this.className})
    : super(key: key);

  @override
  State<AnnounceClassTestPage> createState() => _AnnounceClassTestPageState();
}

class _AnnounceClassTestPageState extends State<AnnounceClassTestPage> {
  final TextEditingController dateController = TextEditingController();
  final TextEditingController timeController = TextEditingController();
  final TextEditingController subjectController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController titleController = TextEditingController();
  final TextEditingController examTypeController = TextEditingController();

  final String currentDate = DateFormat('d, MMM. yyyy').format(DateTime.now());

  bool sms = true;
  bool whatsapp = true;
  bool email = true;

  bool _isEditMode = false;

  String? selectedClassName;

  List<ExamType> examTypes = [];
  ExamType? selectedExamType;
  bool isExamTypeLoading = true;

  @override
  void initState() {
    super.initState();
    loadClassName();
    fetchExamTypes();

    if (widget.examId != null) {
      _isEditMode = true;
      fetchExamDetails(widget.examId!);
    }
  }

  Future<void> fetchExamTypes() async {
    try {
      final service = ExamTypeService();
      final types = await service.fetchExamTypes();
      setState(() {
        examTypes = types;
        isExamTypeLoading = false;
      });
    } catch (e) {
      setState(() => isExamTypeLoading = false);
      print("Error loading exam types: $e");
    }
  }

  Future<void> loadClassName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedClassName = prefs.getString('className') ?? widget.className;
    });
  }

  Future<void> fetchExamDetails(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    final url = Uri.parse(
      'https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api/exams/$id',
    );

    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body)['data'];

        setState(() {
          titleController.text = data['title'] ?? '';
          subjectController.text = data['subject'] ?? '';
          descriptionController.text = data['description'] ?? '';

          DateTime dt = DateTime.parse(data['exam_date']);
          dateController.text = DateFormat('d, MMM. yyyy').format(dt);
          timeController.text = DateFormat('h:mm a').format(dt);
        });

        // Match fetched exam_type_id with dropdown list
        final fetchedExamTypeId = data['exam_type_id'];
        if (examTypes.isNotEmpty) {
          final matchedType = examTypes.firstWhere(
            (type) => type.id == fetchedExamTypeId,
            orElse: () => examTypes.first,
          );
          setState(() {
            selectedExamType = matchedType;
            examTypeController.text = matchedType.examType;
          });
        } else {
          // Retry if examTypes not loaded yet
          Future.delayed(const Duration(milliseconds: 300), () {
            if (examTypes.isNotEmpty) {
              final matchedType = examTypes.firstWhere(
                (type) => type.id == fetchedExamTypeId,
                orElse: () => examTypes.first,
              );
              setState(() {
                selectedExamType = matchedType;
                examTypeController.text = matchedType.examType;
              });
            }
          });
        }
      } else {
        print("Failed to load exam details");
      }
    } catch (e) {
      print("Error fetching exam: $e");
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    dateController.dispose();
    timeController.dispose();
    subjectController.dispose();
    descriptionController.dispose();
    examTypeController.dispose();
    super.dispose();
  }

  Future<void> pickDate() async {
    DateTime now = DateTime.now();

    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year, now.month, now.day), // No past dates
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      dateController.text = DateFormat('d, MMM. yyyy').format(picked);
    }
  }

  Future<void> pickTime() async {
    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      timeController.text = picked.format(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: TeacherAppBar(),
      drawer: MenuDrawer(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Breadcrumb + Close
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 13, fontFamily: 'Arial'),
                      children: [
                        const TextSpan(
                          text: 'Exams > ',
                          style: TextStyle(color: Colors.black),
                        ),
                        TextSpan(
                          text: '${selectedClassName ?? widget.className} ',
                          style: const TextStyle(color: Colors.black),
                        ),
                        const TextSpan(
                          text: '> Class tests',
                          style: TextStyle(color: Color(0xFFB3B3B3)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                _isEditMode ? 'Edit class test' : 'Announce class test',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF29ABE2),
                ),
              ),
              const SizedBox(height: 20),

              // Date + Time
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: dateController,
                      readOnly: true,
                      decoration: InputDecoration(
                        hintText: 'Select Date',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(
                            Icons.calendar_today,
                            color: Color(0xFF2E3192),
                          ),
                          onPressed: pickDate,
                        ),
                      ),
                      onTap: pickDate,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: timeController,
                      readOnly: true,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.access_time),
                          onPressed: pickTime,
                          color: const Color(0xFF2E3192),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Exam Type Dropdown
              const Text(
                'Exam Type',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: isExamTypeLoading
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : DropdownButton<ExamType>(
                        value: selectedExamType,
                        isExpanded: true,
                        underline: const SizedBox(),
                        hint: const Text('Select Exam Type'),
                        items: examTypes.map((type) {
                          return DropdownMenuItem<ExamType>(
                            value: type,
                            child: Text(
                              type.examType,
                              style: const TextStyle(color: Colors.black),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedExamType = value;
                            examTypeController.text = value?.examType ?? '';
                          });
                        },
                      ),
              ),

              const SizedBox(height: 12),

              // Title
              const Text(
                'Title',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  hintText: 'Exam title',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 12),

              // Subject
              const Text(
                'Subject',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: subjectController,
                decoration: const InputDecoration(
                  hintText: 'Lesson name, topic etc...',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 12),

              // Description
              const Text(
                'Description',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Type',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 10),

              // Checkboxes
              Row(
                children: [
                  Checkbox(
                    value: sms,
                    activeColor: Colors.green,
                    checkColor: Colors.white,
                    side: const BorderSide(color: Colors.black),
                    onChanged: (val) => setState(() => sms = val ?? false),
                  ),
                  const Text('SMS'),
                  Checkbox(
                    value: whatsapp,
                    activeColor: Colors.green,
                    checkColor: Colors.white,
                    side: const BorderSide(color: Colors.black),
                    onChanged: (val) => setState(() => whatsapp = val ?? false),
                  ),
                  const Text('Whats app'),
                  Checkbox(
                    value: email,
                    activeColor: Colors.green,
                    checkColor: Colors.white,
                    side: const BorderSide(color: Colors.black),
                    onChanged: (val) => setState(() => email = val ?? false),
                  ),
                  const Text('Email'),
                ],
              ),

              const Spacer(),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[300],
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        // ✅ Validation
                        if (titleController.text.isEmpty ||
                            subjectController.text.isEmpty ||
                            descriptionController.text.isEmpty ||
                            dateController.text.isEmpty ||
                            timeController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Please fill all fields"),
                            ),
                          );
                          return;
                        }

                        final date = dateController.text;
                        final time = timeController.text;
                        final combined = DateFormat(
                          'd, MMM. yyyy h:mm a',
                        ).parse('$date $time');
                        final isoString = combined.toIso8601String();

                        final prefs = await SharedPreferences.getInstance();
                        final token = prefs.getString('auth_token') ?? '';
                        final classId = selectedClassName != null
                            ? prefs.getString('classId') ?? ''
                            : ''; // keep this if you want fallback

                        final examData = {
                          "title": titleController.text,
                          "subject": subjectController.text,
                          "exam_date": isoString,
                          "class_id": classId,
                          "description": descriptionController.text,
                          "exam_type_id": selectedExamType?.id ?? 1,
                        };

                        final url = _isEditMode
                            ? Uri.parse(
                                'https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api/exams/${widget.examId}',
                              )
                            : Uri.parse(
                                'https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api/exams',
                              );

                        final headers = {
                          'Content-Type': 'application/json',
                          'Authorization': 'Bearer $token',
                        };

                        final response = _isEditMode
                            ? await http.put(
                                url,
                                headers: headers,
                                body: jsonEncode(examData),
                              )
                            : await http.post(
                                url,
                                headers: headers,
                                body: jsonEncode(examData),
                              );

                        if (response.statusCode == 200 ||
                            response.statusCode == 201) {
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  _isEditMode
                                      ? "Class test updated successfully"
                                      : "Class test announced successfully",
                                ),
                              ),
                            );
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                _isEditMode
                                    ? "Failed to update class test"
                                    : "Failed to announce class test",
                              ),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.lightBlue,
                      ),
                      child: Text(
                        _isEditMode ? 'Update' : 'Send',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
