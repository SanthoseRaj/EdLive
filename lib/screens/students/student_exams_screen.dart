import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:school_app/widgets/student_app_bar.dart';
import 'student_menu_drawer.dart';
import '../../models/student_exam_model.dart';
import '../../services/exam_service.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class StudentExamsScreen extends StatefulWidget {
  final String studentId;
  const StudentExamsScreen({super.key, required this.studentId});

  @override
  State<StudentExamsScreen> createState() => _StudentExamsScreenState();
}

class _StudentExamsScreenState extends State<StudentExamsScreen> {
  List<StudentExam> examList = [];
  bool isLoading = true;
  String errorMsg = '';
  StudentExam? _selectedExam; // 🔹 for detail view
  Timer? _refreshTimer; // 🔹 Timer

  @override
  void initState() {
    super.initState();
    loadExams();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      loadExams();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel(); // 🔹 cancel timer when leaving page
    super.dispose();
  }

  Future<void> loadExams() async {
    try {
      final data = await ExamService.fetchExams(widget.studentId);

      // 🔹 Sort by examDate (latest first)
      data.sort((a, b) => b.examDate.compareTo(a.examDate));

      // 🔹 Compare with existing list — refresh only if different
      bool hasChanged = false;

      if (data.length != examList.length) {
        hasChanged = true;
      } else {
        for (int i = 0; i < data.length; i++) {
          if (data[i].id != examList[i].id ||
              data[i].examDate != examList[i].examDate ||
              data[i].title != examList[i].title ||
              data[i].description != examList[i].description) {
            hasChanged = true;
            break;
          }
        }
      }

      if (hasChanged) {
        setState(() {
          examList = data;
        });
      }

      if (isLoading) {
        setState(() => isLoading = false);
      }
    } catch (e) {
      print('❌ Error fetching student exams: $e');
      setState(() {
        errorMsg = 'Error loading exams';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_selectedExam != null) {
          setState(() {
            _selectedExam = null; // go back to list
          });
          return false; // ❌ prevent page pop
        }
        return true; // ✅ allow normal back
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFCDBB1),
        drawer: const StudentMenuDrawer(),
        appBar: StudentAppBar(),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🔙 Back Button
                GestureDetector(
                  onTap: () {
                    if (_selectedExam != null) {
                      setState(() => _selectedExam = null);
                    } else {
                      Navigator.pop(context);
                    }
                  },
                  child: const Text(
                    '< Back',
                    style: TextStyle(fontSize: 16, color: Colors.black87),
                  ),
                ),
                const SizedBox(height: 16),

                // 📘 Title and Icon
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E3192),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: SvgPicture.asset(
                        'assets/icons/exams.svg',
                        height: 20,
                        width: 20,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Exams',
                      style: TextStyle(
                        fontSize: 33,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E3192),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 📋 Exam List or Detail
                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : errorMsg.isNotEmpty
                      ? Center(child: Text(errorMsg))
                      : examList.isEmpty
                      ? const Center(child: Text('No exams found'))
                      : _selectedExam != null
                      ? _buildExamDetail(_selectedExam!)
                      : ListView.builder(
                          itemCount: examList.length,
                          itemBuilder: (context, index) {
                            final exam = examList[index];
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedExam = exam;
                                });
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 6,
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Center(
                                      child: Text(
                                        exam.examType,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF2E3192),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      exam.title,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      DateFormat(
                                        'd, MMM yyyy, h:mm a',
                                      ).format(exam.examDate),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.black87,
                                      ),
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
    );
  }

  /// 🔹 Detail Container
  Widget _buildExamDetail(StudentExam exam) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Exam Type
            Center(
              child: Text(
                exam.examType,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E3192),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              exam.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),

            // Date
            Text(
              DateFormat('d, MMM yyyy, h:mm a').format(exam.examDate),
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 8),

            // Subject
            Text(
              'Subject: ${exam.subject}',
              style: const TextStyle(fontSize: 16, color: Color(0xFF2E3192)),
            ),
            const SizedBox(height: 8),

            // Description
            Text(
              'Description: ${exam.description}',
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }
}
