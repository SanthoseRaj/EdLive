import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:school_app/screens/students/student_menu_drawer.dart';
import 'package:school_app/widgets/student_app_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../models/exam_type_model.dart';
import '../../services/exam_type_service.dart';


final ValueNotifier<String> selectedTerm = ValueNotifier<String>("Final");

class StudentReportPage extends StatefulWidget {
  final int studentId; // Pass student ID
  const StudentReportPage({super.key, required this.studentId});

  @override
  State<StudentReportPage> createState() => _StudentReportPageState();
}

class _StudentReportPageState extends State<StudentReportPage> {
  List<Map<String, dynamic>> examRows = [];

  List<ExamType> examTypes = [];
ExamType? selectedExamType;


  String grade = '';
  String averageScore = '';
  String classRank = '';


  String getGradeFromScore(double score) {
  if (score >= 95) return "A+";
  if (score >= 90) return "A";
  if (score >= 85) return "B+";
  if (score >= 80) return "B";
  if (score >= 75) return "C+";
  if (score >= 70) return "C";
  if (score >= 65) return "D+";
  if (score >= 60) return "D";
  return "F";
}


 @override
void initState() {
  super.initState();
  fetchExamTypes();
}

Future<void> fetchExamTypes() async {
  try {
    final types = await ExamTypeService().fetchExamTypes();
    setState(() {
      examTypes = types;
      if (types.isNotEmpty) {
        selectedExamType = types.first;
        fetchExamResults(); // fetch results for default selected exam
      }
    });
  } catch (e) {
    debugPrint("Error fetching exam types: $e");
  }
}


  Future<void> fetchExamResults() async {
  if (selectedExamType == null) return;

  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('auth_token') ?? '';

  final url = Uri.parse(
    'https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api/exams/results/student/${widget.studentId}?examTypeId=${selectedExamType!.id}',
  );

  final response = await http.get(
    url,
    headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
  );

  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    if (data['success'] == true) {
      final examResults = data['data']['examResults'] as List;
      final termResults = data['data']['termResults'] as List;

   setState(() {
  examRows = examResults
      .map((e) => {
            'subject': e['subject'] ?? e['exam_title'] ?? '',
            'marks': (e['marks'] ?? '').toString(),
          })
      .toList();

  if (termResults.isNotEmpty) {
    final avg = double.tryParse(termResults[0]['average_percentage'].toString()) ?? 0.0;
    averageScore = avg.toStringAsFixed(2); // ✅ formatted to 2 decimals
    grade = getGradeFromScore(avg); // ✅ derive grade based on average
    classRank = termResults[0]['class_rank'].toString();
  }
});
  }
  } else {
    debugPrint('Failed to fetch exam results: ${response.statusCode}');
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: StudentAppBar(),
      drawer: StudentMenuDrawer(),
      body: Column(
        children: [
          // Pink Report Section
          Expanded(
            child: Container(
              width: double.infinity,
              color: const Color(0xFFFDCFD0),
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back Button
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Row(
                        children: const [
                          SizedBox(width: 4),
                          Text("< Back", style: TextStyle(color: Colors.black)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Report Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFF2E3192),
                          ),
                          child: SvgPicture.asset(
                            "assets/icons/reports.svg",
                            height: 32,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          "Report",
                          style: TextStyle(
                            fontSize: 35,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2E3192),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Grades & Marks",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF2E3192),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Grade, Average Score, Class Rank
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _ReportStat(
                          title: "Grade",
                          value: grade.isEmpty ? "-" : grade,
                        ),
                        _ReportStat(
                          title: "Average Score",
                          value: averageScore.isEmpty ? "-" : "$averageScore%",
                        ),
                        _ReportStat(
                          title: "Class Rank",
                          value: classRank.isEmpty ? "-" : classRank,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Term Dropdown + Table
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        children: [
                          // Term row with dropdown
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("Term"),
                                ValueListenableBuilder<String>(
                                  valueListenable: selectedTerm,
                                  builder: (context, value, _) {
                                    return Container(
                                      height: 32,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: const Color(0xFF4D4D4D),
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: DropdownButton<ExamType>(
  value: selectedExamType,
  underline: const SizedBox(),
  icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF808080)),
  style: const TextStyle(color: Color(0xFF4D4D4D), fontSize: 14),
  items: examTypes.map((exam) {
    return DropdownMenuItem(
      value: exam,
      child: Text(exam.examType),
    );
  }).toList(),
  onChanged: (newValue) {
    if (newValue != null) {
      setState(() {
        selectedExamType = newValue;
        fetchExamResults();
      });
    }
  },
),
  );
                                  },
                                ),
                              ],
                            ),
                          ),

                          // Divider line
                          Container(height: 1, color: Colors.grey.shade300),

                          // Table Header
                          Container(
                            color: Colors.grey.shade200,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: const [
                                Text(
                                  "Subject",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  "Practical",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),

                          // Table Rows
                          ...examRows.map(
                            (e) => _buildRow(e['subject']!, e['marks']!),
                          ),

                          // Total
                          Container(
                            color: const Color(0xFFEAEAEA),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "Total",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                Text(
                                  examRows
                                      .fold<int>(
                                        0,
                                        (prev, e) =>
                                            prev + int.parse(e['marks'] ?? '0'),
                                      )
                                      .toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildRow(String subject, String marks) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(subject), Text(marks)],
      ),
    );
  }
}

class _ReportStat extends StatelessWidget {
  final String title;
  final String value;

  const _ReportStat({required this.title, required this.value, super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Color(0xFF2E3192),
          ),
        ),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF666666),
          ),
        ),
      ],
    );
  }
}
