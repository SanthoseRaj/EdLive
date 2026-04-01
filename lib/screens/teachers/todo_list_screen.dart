import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:school_app/config/config.dart';

import '../../providers/teacher_dashboard_provider.dart';
import '../../providers/teacher_task_provider.dart';
import '../../models/teacher_todo_model.dart';
import '../document_preview_page.dart';

import 'teacher_menu_drawer.dart';
import 'package:school_app/widgets/teacher_app_bar.dart';

import 'package:school_app/services/teacher_syllabus_subject_service.dart';
import 'package:school_app/models/teacher_syllabus_subject_model.dart';

class ToDoListPage extends StatefulWidget {
  const ToDoListPage({Key? key}) : super(key: key);

  @override
  State<ToDoListPage> createState() => _ToDoListPageState();
}

class _ToDoListPageState extends State<ToDoListPage> {
  bool _isEditMode = false;
  bool _isSubmitting = false;
  String? _editingTaskId;
  bool _showAddForm = false;
  DateTime? _selectedDate;
  PlatformFile? _selectedFile;

  final TextEditingController _taskController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  List<Map<String, dynamic>> _classList = [];
  Map<String, dynamic>? _selectedClass;
  Map<int, String> _classDisplayNames = {};
  String? _authToken;

  List<SubjectModel> _subjectList = [];
  SubjectModel? _selectedSubject;

  // New state variables for student-like UI
  Todo? _selectedTask;
  final Set<int> _viewedTodoIds = <int>{};

  @override
  void initState() {
    super.initState();
    _loadTokenAndData();
  }

  Future<void> _loadTokenAndData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    print('Auth token: $token');

    if (!mounted) {
      return;
    }

    setState(() => _authToken = token);

    final provider = Provider.of<TeacherTaskProvider>(context, listen: false);
    provider.setAuthToken(token);

    await _fetchClassList();

    // ✅ Fetch all subjects right away so subject names appear
    await _fetchSubjectsForClass();

    await provider.fetchTodos();
    await _markTodosAsViewed(provider.tasks);
  }

  Future<void> _markTodosAsViewed(List<Todo> tasks) async {
    final dashboardProvider = Provider.of<DashboardProvider>(
      context,
      listen: false,
    );

    // ✅ create safe copy
    final safeTasks = List<Todo>.from(tasks);

    for (final task in safeTasks) {
      final todoId = int.tryParse(task.id ?? '');
      if (todoId == null || _viewedTodoIds.contains(todoId)) {
        continue;
      }

      await dashboardProvider.markDashboardItemViewedByType(
        itemType: 'todo',
        itemId: todoId,
      );

      _viewedTodoIds.add(todoId);
    }
  }

  Future<void> _fetchClassList() async {
    final url = AppConfig.apiUri('/master/classes');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _classList = data.map((item) {
            return {
              'class_id': item['class_id'],
              'class_name': item['class_name'],
              'class': item['class'],
              'section': item['section'],
            };
          }).toList();

          _classDisplayNames = {};
          for (var classItem in _classList) {
            final classId = classItem['class_id'] as int;
            _classDisplayNames[classId] =
                '${classItem['class']} ${classItem['section']}';
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only image, PDF, and Excel files can be attached'),
        ),
      );
      print('Error fetching classes: $e');
    }
  }

  Future<void> _fetchSubjectsForClass() async {
    try {
      final subjects = await SubjectService().fetchSubjects();
      setState(() {
        _subjectList = subjects;
        _selectedSubject = null;
      });
    } catch (e) {
      print('Error fetching subjects: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error fetching subjects: $e')));
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: kTodoUploadExtensions,
        withData: true,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFile = result.files.first;
        });
        print('✅ File selected: ${_selectedFile!.name}');
      } else {
        print('⚠️ File picking cancelled.');
      }
    } catch (e) {
      print('❌ File picking failed: $e');
    }
  }

  Future<void> _submitTask() async {
    if (_isSubmitting) return;

    if (_authToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Authentication error: No token found')),
      );
      return;
    }

    if (_selectedClass == null ||
        _selectedDate == null ||
        _selectedSubject == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select class, subject, and date')),
      );
      return;
    }

    final provider = Provider.of<TeacherTaskProvider>(context, listen: false);
    final title = _taskController.text.trim();
    final description = _descriptionController.text.trim();
    final classId = int.tryParse(_selectedClass!['class_id'].toString()) ?? 0;
    final subjectId = _selectedSubject!.id;
    final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate!);

    if (title.isEmpty || description.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    // ✅ FILE VALIDATION (NEW)
    if (_selectedFile != null) {
      final extension = _selectedFile!.extension?.toLowerCase();

      if (extension == null || !kTodoUploadExtensions.contains(extension)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This file is not supported')),
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      print('Uploading ToDo...');
      print('Title: $title');
      print('Date: $formattedDate');
      print('ClassId: $classId');
      print('SubjectId: $subjectId');
      print('File: ${_selectedFile?.name ?? "none"}');
      print('Auth Token: $_authToken');

      if (_isEditMode && _editingTaskId != null) {
        await provider.updateTodo(
          id: _editingTaskId!,
          title: title,
          date: formattedDate,
          description: description,
          classId: classId,
          subjectId: subjectId,
          pickedFile: _selectedFile,
        );
      } else {
        await provider.addTodo(
          title: title,
          date: formattedDate,
          description: description,
          classId: classId,
          subjectId: subjectId,
          pickedFile: _selectedFile,
        );
      }

      _resetForm();
      final safeTasks = List<Todo>.from(provider.tasks);
      unawaited(_markTodosAsViewed(safeTasks));

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sended successful')));
    } catch (e) {
      print('Submit failed: $e');

      // ✅ CUSTOM ERROR HANDLING (UPDATED)
      String errorMessage = 'Something went wrong';

      final error = e.toString().toLowerCase();

      if (error.contains('file') ||
          error.contains('format') ||
          error.contains('type') ||
          error.contains('unsupported')) {
        errorMessage = 'This file is not supported';
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage)));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _resetForm() {
    setState(() {
      _taskController.clear();
      _descriptionController.clear();
      _selectedDate = null;
      _selectedFile = null;
      _showAddForm = false;
      _isEditMode = false;
      _editingTaskId = null;
      _selectedClass = null;
      _selectedSubject = null;
      _selectedTask = null; // Reset selected task when form is reset
    });
  }

  String _formatDisplayDate(DateTime date) {
    return DateFormat('dd.MMM yyyy').format(date);
  }

  String _formatDisplayDateFromString(String dateString) {
    try {
      return DateFormat('dd.MMM yyyy').format(DateTime.parse(dateString));
    } catch (_) {
      return dateString;
    }
  }

  String _buildTodoFileUrl(String filePath) {
    return AppConfig.absoluteUrl(filePath);
  }

  void _openTaskFile(String filePath) {
    final fullUrl = _buildTodoFileUrl(filePath);
    final fileName =
        Uri.tryParse(fullUrl)?.pathSegments.last ?? filePath.split('/').last;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentPreviewPage(fileUrl: fullUrl, title: fileName),
      ),
    );
  }

  @override
  void dispose() {
    _taskController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TeacherTaskProvider>(context);
    final tasks = List<Todo>.from(provider.tasks);

    return WillPopScope(
      onWillPop: () async {
        if (_selectedTask != null) {
          setState(() => _selectedTask = null);
          return false; // ❌ don't pop page
        } else if (_showAddForm) {
          _resetForm();
          return false; // ❌ don't pop page
        }
        return true; // ✅ allow pop (go dashboard)
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: const Color(0xFF87CEEB),
        drawer: MenuDrawer(),
        appBar: TeacherAppBar(),
        body: Column(
          children: [
            // Back Button - Updated to handle task detail navigation
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 10),
              child: GestureDetector(
                onTap: () {
                  if (_selectedTask != null) {
                    setState(() => _selectedTask = null);
                  } else if (_showAddForm) {
                    _resetForm();
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.menu_book,
                        color: Colors.indigo[900],
                        size: 32,
                      ),
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
                  if (!_showAddForm && _selectedTask == null)
                    ElevatedButton.icon(
                      onPressed: () => setState(() => _showAddForm = true),
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text(
                        'Add',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Conditional rendering based on state
            if (_showAddForm) _buildAddForm(),
            if (_selectedTask != null) _buildTaskDetail(_selectedTask!),
            if (!_showAddForm && _selectedTask == null)
              _buildTaskList(tasks, provider),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskList(List<Todo> tasks, TeacherTaskProvider provider) {
    final safeTasks = List<Todo>.from(tasks);
    return Expanded(
      child: ListView.builder(
        key: const PageStorageKey('todoList'),
        itemCount: tasks.length,
        itemBuilder: (context, index) {
          final task = safeTasks[index]; // ✅ CHANGE THIS

          final className = task.classId != null
              ? _classDisplayNames[task.classId]
              : null;
          final subjectName = _subjectList
              .where((subject) => subject.id == task.subjectId)
              .firstOrNull
              ?.name;

          return GestureDetector(
            onTap: () => setState(() => _selectedTask = task),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                    _formatDisplayDateFromString(task.date),
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    task.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    task.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  if (className != null && className.isNotEmpty)
                    Text(
                      'Class: $className',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.blue[700],
                      ),
                    ),
                  if (subjectName != null && subjectName.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Subject: $subjectName',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF2E3192),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTaskDetail(Todo task) {
    final className = task.classId != null
        ? _classDisplayNames[task.classId]
        : null;
    final subjectName = _subjectList
        .where((subject) => subject.id == task.subjectId)
        .firstOrNull
        ?.name;

    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
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
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 🔹 Title
                    Center(
                      child: Text(
                        task.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E3192),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 🔹 Details
                    Text(
                      'Date: ${_formatDisplayDateFromString(task.date)}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 8),

                    if (className != null && className.isNotEmpty)
                      Text(
                        'Class: $className',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    if (subjectName != null && subjectName.isNotEmpty)
                      Text(
                        'Subject: $subjectName',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    const SizedBox(height: 12),

                    // 🔹 Description
                    Text(
                      task.description,
                      style: const TextStyle(fontSize: 16),
                    ),

                    // 🔹 File Button
                    if (task.fileUrl != null && task.fileUrl!.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () => _openTaskFile(task.fileUrl!),
                        icon: const Icon(Icons.file_open),
                        label: Text(
                          "View File: ${task.fileUrl!.split('/').last}",
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo[700],
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // 🔹 Bottom-aligned Edit/Delete buttons
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _isEditMode = true;
                        _editingTaskId = task.id;
                        _taskController.text = task.title;
                        _descriptionController.text = task.description;
                        _selectedDate = DateTime.tryParse(task.date);

                        _selectedClass = _classList.firstWhere(
                          (c) => c['class_id'] == task.classId,
                          orElse: () => {},
                        );
                        if (_selectedClass!.isEmpty) _selectedClass = null;

                        _showAddForm = true;
                        _selectedTask = null;
                        _selectedSubject = null;
                      });

                      if (_selectedClass != null) {
                        _fetchSubjectsForClass().then((_) {
                          SubjectModel? selected;
                          try {
                            selected = _subjectList.firstWhere(
                              (s) => s.id == task.subjectId,
                            );
                          } catch (_) {
                            selected = null;
                          }
                          setState(() => _selectedSubject = selected);
                        });
                      }
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Confirm Delete'),
                          content: const Text(
                            'Are you sure you want to delete this task?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        final provider = Provider.of<TeacherTaskProvider>(
                          context,
                          listen: false,
                        );
                        await provider.deleteTodo(id: task.id!);
                        setState(() => _selectedTask = null);
                      }
                    },
                    icon: const Icon(Icons.delete),
                    label: const Text('Delete'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddForm() {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        bottomInset > 0 ? bottomInset : 10,
      ),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        padding: const EdgeInsets.all(20),
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
          children: [
            // 🔹 Scrollable Form Content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Select Class"),
                    const SizedBox(height: 10),
                    DropdownButton<Map<String, dynamic>>(
                      isExpanded: true,
                      value: _selectedClass,
                      hint: const Text("Choose Class"),
                      items: _classList
                          .map<DropdownMenuItem<Map<String, dynamic>>>((
                            classItem,
                          ) {
                            return DropdownMenuItem<Map<String, dynamic>>(
                              value: classItem,
                              child: Text(classItem['class_name']),
                            );
                          })
                          .toList(),
                      onChanged: (newValue) {
                        setState(() => _selectedClass = newValue);
                        if (newValue != null) {
                          _fetchSubjectsForClass();
                        }
                      },
                    ),
                    const SizedBox(height: 24),

                    const Text("Select Subject"),
                    const SizedBox(height: 10),
                    DropdownButton<SubjectModel>(
                      isExpanded: true,
                      value: _selectedSubject,
                      hint: const Text("Choose Subject"),
                      items: _subjectList.map((subjectItem) {
                        return DropdownMenuItem<SubjectModel>(
                          value: subjectItem,
                          child: Text(subjectItem.name),
                        );
                      }).toList(),
                      onChanged: (newValue) =>
                          setState(() => _selectedSubject = newValue),
                    ),
                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _selectedDate != null
                                ? _formatDisplayDate(_selectedDate!)
                                : 'Select Date',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.calendar_today),
                          onPressed: _pickDate,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    const Text("Task Title"),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _taskController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Enter title...',
                      ),
                    ),
                    const SizedBox(height: 24),

                    const Text("Description"),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Enter description...',
                      ),
                    ),
                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _pickFile,
                            icon: const Icon(Icons.attach_file),
                            label: Text(
                              _selectedFile != null
                                  ? 'Selected: ${_selectedFile!.name}'
                                  : 'Attach File (Image/Pdf/Word)',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Allowed: JPG, PNG, PDF, DOC',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),

            // 🔹 Fixed Bottom Buttons
            Container(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _resetForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitTask,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
                              'Send',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
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
    );
  }
}
