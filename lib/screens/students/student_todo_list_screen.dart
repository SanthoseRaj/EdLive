// ignore_for_file: use_build_context_synchronously
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'student_menu_drawer.dart';
import 'package:school_app/widgets/student_app_bar.dart';
import 'package:school_app/models/teacher_syllabus_subject_model.dart';
import 'package:school_app/services/teacher_syllabus_subject_service.dart';

class StudentToDoListPage extends StatefulWidget {
  const StudentToDoListPage({Key? key}) : super(key: key);

  @override
  State<StudentToDoListPage> createState() => _StudentToDoListPageState();
}

class _StudentToDoListPageState extends State<StudentToDoListPage> {
  List<Map<String, dynamic>> _tasks = [];
  bool _isLoading = true;
  Map<int, String> _classDisplayNames = {};
  List<Map<String, dynamic>> _classList = [];
  Map<int, String> _subjectNames = {};
  Map<String, dynamic>? _selectedTask;

  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchClassList();
    _fetchSubjects();
    _fetchTasks();

    // Auto-refresh every 20s
    _autoRefreshTimer = Timer.periodic(
      const Duration(seconds: 20),
      (timer) => _fetchTasks(),
    );
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchSubjects() async {
    try {
      final service = SubjectService();
      final subjects = await service.fetchSubjects();
      setState(() {
        _subjectNames = {
          for (var subject in subjects) subject.id: subject.name,
        };
      });
    } catch (e) {
      debugPrint("Error fetching subjects: $e");
    }
  }

  Future<void> _fetchTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final studentId = prefs.getInt('student_id');
      if (token == null || studentId == null) return;

      final url = Uri.parse(
        'https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api/todos/student/$studentId',
      );

      final response = await http.get(
        url,
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final newTasks = List<Map<String, dynamic>>.from(data);

        if (!_areTaskListsEqual(_tasks, newTasks)) {
          setState(() {
            _tasks = newTasks;
            _isLoading = false;
          });

          // Mark viewed
          for (var task in newTasks) {
            if (task['id'] != null) {
              await _markDashboardViewed(studentId, token, task['id']);
            }
          }
        } else {
          if (_isLoading) setState(() => _isLoading = false);
        }
      } else {
        if (_isLoading) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching tasks: $e");
      if (_isLoading) setState(() => _isLoading = false);
    }
  }

  bool _areTaskListsEqual(
    List<Map<String, dynamic>> oldList,
    List<Map<String, dynamic>> newList,
  ) {
    if (oldList.length != newList.length) return false;
    for (int i = 0; i < oldList.length; i++) {
      if (oldList[i]['id'] != newList[i]['id'] ||
          oldList[i]['title'] != newList[i]['title'] ||
          oldList[i]['description'] != newList[i]['description'] ||
          oldList[i]['date'] != newList[i]['date']) {
        return false;
      }
    }
    return true;
  }

  Future<void> _markDashboardViewed(
    int studentId,
    String token,
    int todoId,
  ) async {
    try {
      final url = Uri.parse(
        'https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api/dashboard/viewed?studentId=$studentId',
      );
      await http.post(
        url,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({"item_type": "todo", "item_id": todoId}),
      );
    } catch (_) {}
  }

  Future<void> _fetchClassList() async {
    final url = Uri.parse(
      'https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api/master/classes',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _classList = data.map((item) {
            return {
              'class_id': item['class_id'],
              'class': item['class'],
              'section': item['section'],
            };
          }).toList();

          _classDisplayNames = {
            for (var c in _classList)
              c['class_id']: '${c['class']} ${c['section']}',
          };
        });
      }
    } catch (_) {}
  }

  String _formatDisplayDate(String dateString) {
    try {
      return DateFormat('dd.MMM yyyy').format(DateTime.parse(dateString));
    } catch (_) {
      return dateString;
    }
  }

  Future<void> _openFile(String filePath) async {
    final fullUrl =
        "https://schoolmanagement.canadacentral.cloudapp.azure.com:443$filePath";
    if (await canLaunchUrl(Uri.parse(fullUrl))) {
      await launchUrl(Uri.parse(fullUrl), mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Could not open file")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF87CEEB),
      appBar: StudentAppBar(),
      drawer: const StudentMenuDrawer(),
      body: Column(
        children: [
          // Back Button
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 10),
            child: GestureDetector(
              onTap: () {
                if (_selectedTask != null) {
                  setState(() => _selectedTask = null);
                } else {
                  Navigator.pop(context);
                }
              },
              child: Row(
                children: [
                  SvgPicture.asset(
                    'assets/icons/arrow_back.svg',
                    height: 11,
                    width: 11,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Back',
                    style: TextStyle(color: Colors.black, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: [
                Icon(Icons.menu_book, color: Colors.indigo[900], size: 32),
                const SizedBox(width: 8),
                Text(
                  'Home Work',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo[900],
                  ),
                ),
              ],
            ),
          ),

          // Body
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _tasks.isEmpty
                ? const Center(child: Text('No tasks found.'))
                : _selectedTask != null
                ? _buildTaskDetail(_selectedTask!)
                : ListView.builder(
                    itemCount: _tasks.length,
                    itemBuilder: (context, index) {
                      final task = _tasks[index];
                      final className = _classDisplayNames[task['class_id']];
                      final subjectName = _subjectNames[task['subject_id']];

                      return GestureDetector(
                        onTap: () => setState(() => _selectedTask = task),
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          padding: const EdgeInsets.all(12),
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
                              Text(
                                _formatDisplayDate(task['date']),
                                style: const TextStyle(fontSize: 14),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                task['title'] ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                task['description'] ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                              if (className != null)
                                Text(
                                  "Class: $className",
                                  style: const TextStyle(
                                    color: Colors.blue,
                                    fontSize: 14,
                                  ),
                                ),
                              if (subjectName != null)
                                Text(
                                  "Subject: $subjectName",
                                  style: const TextStyle(
                                    color: const Color(0xFF2E3192),
                                    fontSize: 14,
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
    );
  }

  Widget _buildTaskDetail(Map<String, dynamic> task) {
    final className = _classDisplayNames[task['class_id']];
    final subjectName = _subjectNames[task['subject_id']];
    final filePath = task['todo_file'];

    return Container(
      margin: const EdgeInsets.all(16),
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
            Center(
              child: Text(
                task['title'] ?? 'No title',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E3192),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Date: ${_formatDisplayDate(task['date'])}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            if (className != null)
              Text(
                'Class: $className',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            if (subjectName != null)
              Text(
                'Subject: $subjectName',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            const SizedBox(height: 12),
            Text(
              task['description'] ?? 'No description',
              style: const TextStyle(fontSize: 16),
            ),
            if (filePath != null && filePath.isNotEmpty) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => _openFile(filePath),
                icon: const Icon(Icons.file_open),
                label: const Text("View File"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo[700],
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
