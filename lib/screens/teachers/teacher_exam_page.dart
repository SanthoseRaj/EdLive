import 'package:flutter/material.dart';
import 'package:school_app/widgets/teacher_app_bar.dart';
import 'teacher_menu_drawer.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'teacher_exam_announce_class_test_page.dart';

import 'package:school_app/models/class_section.dart';
import 'package:school_app/models/teacher_exam_model.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:school_app/config/config.dart';

class TeacherExamPage extends StatefulWidget {
  const TeacherExamPage({super.key});

  @override
  State<TeacherExamPage> createState() => _TeacherExamPageState();
}

class _TeacherExamPageState extends State<TeacherExamPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<ClassSection> classList = [];
  ClassSection? selectedClass;
  bool isLoading = true;

  List<TeacherExam> exams = [];
  bool isExamLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    fetchClasses();
  }

  Future<void> fetchExamsForClass(String classId) async {
    setState(() => isExamLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';

      final url = Uri.parse('${AppConfig.baseUrl}/exams/teacher/$classId');

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        final List data = body['data'];
        exams = data.map((e) => TeacherExam.fromJson(e)).toList();
      } else {
        exams = [];
      }
    } catch (e) {
      exams = [];
    }

    setState(() => isExamLoading = false);
  }

  Future<void> fetchClasses() async {
    final url = Uri.parse('${AppConfig.baseUrl}/master/classes');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          classList = data.map((json) => ClassSection.fromJson(json)).toList();
          selectedClass = classList.isNotEmpty ? classList[0] : null;
          if (selectedClass != null) {
            fetchExamsForClass(selectedClass!.id.toString());
          }

          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
        // Handle error
      }
    } catch (e) {
      setState(() => isLoading = false);
      // Handle error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFAAE5C8),
      drawer: const MenuDrawer(),
      appBar: TeacherAppBar(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back Button + Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text(
                    '< Back',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      height: 32,
                      width: 32,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E3192),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: SvgPicture.asset(
                        'assets/icons/exams.svg',
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Exams',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E3192),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // White Content Box
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  // Class Dropdown Row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        const Flexible(
                          child: Text(
                            'Select your class',
                            style: TextStyle(fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 110,
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFCCCCCC),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: isLoading
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : DropdownButton<ClassSection>(
                                  value: selectedClass,
                                  isExpanded: true,
                                  underline: const SizedBox(),
                                  icon: const Icon(Icons.arrow_drop_down),
                                  dropdownColor: Colors.white,
                                  selectedItemBuilder: (context) {
                                    return classList.map((cls) {
                                      return Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          cls.fullName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Color(0xFF29ABE2),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      );
                                    }).toList();
                                  },
                                  onChanged: (value) async {
                                    if (value != null) {
                                      setState(() => selectedClass = value);
                                      fetchExamsForClass(value.id.toString());

                                      final prefs =
                                          await SharedPreferences.getInstance();
                                      await prefs.setString(
                                        'classId',
                                        value.id.toString(),
                                      );
                                      await prefs.setString(
                                        'className',
                                        value.fullName,
                                      ); // ✅ store class name too
                                    }
                                  },

                                  items: classList.map((cls) {
                                    return DropdownMenuItem(
                                      value: cls,
                                      child: Text(
                                        cls.fullName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Color(0xFF29ABE2),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Tabs
                  TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.blue,
                    labelColor: Colors.black,
                    tabs: const [
                      Tab(text: 'Class tests'),
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Other Exams'),
                            SizedBox(width: 4),
                            // CircleAvatar(
                            //   radius: 8,
                            //   backgroundColor: Colors.purple,
                            //   child: Text(
                            //     '1',
                            //     style: TextStyle(
                            //       fontSize: 10,
                            //       color: Colors.white,
                            //     ),
                            //   ),
                            // ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // TabBarView
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildClassTestsTab(),
                        const Center(child: Text('Other Exams Coming Soon')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassTestsTab() {
    if (isExamLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // ✅ Sort exams by date here first
    final sortedExams = List<TeacherExam>.from(exams)
      ..sort(
        (a, b) =>
            DateTime.parse(b.examDate).compareTo(DateTime.parse(a.examDate)),
      );

    return Padding(
      padding: const EdgeInsets.all(12),
      child: ListView(
        children: [
          Center(
            child: SizedBox(
              width: 220,
              child: ElevatedButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AnnounceClassTestPage(
                        className:
                            selectedClass?.fullName ?? '', // display in UI
                      ),
                    ),
                  );

                  // ✅ Refresh exam list automatically when returning
                  if (selectedClass != null) {
                    fetchExamsForClass(selectedClass!.id.toString());
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  minimumSize: const Size(double.infinity, 45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: const Text(
                  'Announce a class test',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ✅ Map the sorted list to widgets
          ...sortedExams.map((exam) {
            return Column(
              children: [
                _buildTestSection(exam: exam),
                const Divider(color: Color(0xFFB3B3B3), thickness: 1),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTestSection({required TeacherExam exam, bool showTitle = true}) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (showTitle)
                Align(
                  alignment: Alignment.center,
                  child: Text(
                    exam.examType,
                    style: const TextStyle(
                      fontSize: 18,
                      color: Color(0xFF29ABE2),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  exam.examDate.split('T').first,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                exam.subject,
                style: const TextStyle(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  exam.description,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: IconButton(
            icon: SvgPicture.asset(
              'assets/icons/pencil.svg',
              height: 20,
              width: 20,
              colorFilter: const ColorFilter.mode(
                Colors.black,
                BlendMode.srcIn,
              ),
            ),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AnnounceClassTestPage(
                    examId: exam.id,
                    className: selectedClass?.fullName ?? '',
                  ),
                ),
              );

              // ✅ Auto-refresh after editing
              if (selectedClass != null) {
                fetchExamsForClass(selectedClass!.id.toString());
              }
            },
          ),
        ),
      ],
    );
  }
}
