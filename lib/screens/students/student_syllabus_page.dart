import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:school_app/widgets/student_app_bar.dart';
import 'student_menu_drawer.dart';
import 'student_syllabus_detail_page.dart';
import '../../models/student_syllabus_model.dart';
import '../../services/student_syllabus_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:school_app/config/config.dart';

class StudentSyllabusPage extends StatefulWidget {
  const StudentSyllabusPage({super.key});

  @override
  State<StudentSyllabusPage> createState() => _StudentSyllabusPageState();
}

class _StudentSyllabusPageState extends State<StudentSyllabusPage> {
  Future<List<SyllabusSubject>>? _syllabusFuture;

  @override
  void initState() {
    super.initState();
    _loadSyllabus();
  }

  void _loadSyllabus() async {
    final prefs = await SharedPreferences.getInstance();
    final classId = prefs.getInt('class_id') ?? 1; // fallback to 1 if null

    setState(() {
      _syllabusFuture = SyllabusService().fetchSyllabusSubjects(classId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF91C1BC),
      drawer: StudentMenuDrawer(),
      appBar: StudentAppBar(),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back and Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text(
                      '< Back',
                      style: TextStyle(fontSize: 14, color: Colors.black),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 35,
                        height: 35,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E3192),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: SvgPicture.asset(
                          'assets/icons/syllabus.svg',
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Syllabus',
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

            // Fetch Data
            Expanded(
              child: FutureBuilder<List<SyllabusSubject>>(
                future: _syllabusFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        "Error: ${snapshot.error}",
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text("No syllabus found"));
                  }

                  final subjects = snapshot.data!;
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: subjects.length,
                    itemBuilder: (context, index) {
                      final subject = subjects[index];
                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          title: Text(
                            subject.subjectName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          // ⬅️ Removed subjectCode (no subtitle now)
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2BB5E4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              minimumSize: const Size(80, 35),
                            ),
                            onPressed: () async {
                              final prefs =
                                  await SharedPreferences.getInstance();
                              final classId = prefs.getInt('class_id') ?? 1;

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SyllabusDetailPage(
                                    classId: classId,
                                    subjectId: subject.subjectId,
                                    academicYear: AppConfig.academicYear,
                                    subjectName: subject.subjectName,
                                  ),
                                ),
                              );
                            },

                            child: const Text(
                              'View',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
