import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:school_app/screens/teachers/teacher_menu_drawer.dart';
import 'package:school_app/widgets/teacher_app_bar.dart';
import '../../models/teacher_special_care_model.dart';
import '../../services/teacher_special_care_service.dart';
import '../../models/teacher_special_care_item.dart';
import '../../services/teacher_special_care_item_service.dart';
import '/models/teacher_class_student.dart';
import 'package:school_app/services/teacher_class_student_list.dart';

/// ---------------- SpecialCarePage ----------------
class SpecialCarePage extends StatefulWidget {
  const SpecialCarePage({super.key});

  @override
  State<SpecialCarePage> createState() => _SpecialCarePageState();
}

class _SpecialCarePageState extends State<SpecialCarePage> {
  late Future<List<SpecialCareCategory>> _futureCategories;
  final SpecialCareService _service = SpecialCareService();

  @override
  void initState() {
    super.initState();
    _futureCategories = _service.fetchCategories();
  }

  String _getIconPath(String categoryName) {
    switch (categoryName) {
      case "Academic Support":
        return 'assets/icons/book.svg';
      case "Emotional & Mental Wellbeing":
        return 'assets/icons/head.svg';
      case "Health & Safety":
        return 'assets/icons/health.svg';
      case "Inclusive Learning":
        return 'assets/icons/inclusive.svg';
      default:
        return 'assets/icons/book.svg';
    }
  }

  Widget _buildCard(SpecialCareCategory category) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CategoryDetailPage(category: category),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SvgPicture.asset(
              _getIconPath(category.name),
              width: 28,
              height: 28,
              color: const Color(0xFF2E3192),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.name,
                    style: const TextStyle(
                      color: Color(0xFF2E3192),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    category.description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      height: 1.3,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD9CCDB),
      appBar: TeacherAppBar(),
      drawer: MenuDrawer(),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Text(
                "< Back",
                style: TextStyle(color: Colors.black, fontSize: 14),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E3192),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  padding: const EdgeInsets.all(5),
                  child: SvgPicture.asset(
                    'assets/icons/special_care.svg',
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  "Special Care",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E3192),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<SpecialCareCategory>>(
                future: _futureCategories,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(
                      child: Text("Error: ${snapshot.error.toString()}"),
                    );
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text("No categories found"));
                  }

                  final categories = snapshot.data!;
                  return ListView.builder(
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      return _buildCard(category);
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

/// ---------------- Category Detail Page ----------------
class CategoryDetailPage extends StatefulWidget {
  final SpecialCareCategory category;
  const CategoryDetailPage({super.key, required this.category});

  @override
  State<CategoryDetailPage> createState() => _CategoryDetailPageState();
}

class _CategoryDetailPageState extends State<CategoryDetailPage> {
  static const List<String> _subjects = ['Math', 'Science', 'English'];
  static const List<String> _weekdayChips = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
  static const Map<String, String> _weekdayNames = {
    'Mon': 'Monday',
    'Tue': 'Tuesday',
    'Wed': 'Wednesday',
    'Thu': 'Thursday',
    'Fri': 'Friday',
  };

  final TextEditingController notesController = TextEditingController();
  final TextEditingController fileLinkController = TextEditingController();
  final SpecialCareItemService _service = SpecialCareItemService();

  List<Student> allStudents = [];
  List<Student> selectedStudents = [];
  bool isLoadingStudents = true;
  bool _isSubmitting = false;

  final Map<String, List<String>> _selectedDays = {};
  final Map<String, TimeOfDay> _startTimes = {};
  final Map<String, TimeOfDay> _endTimes = {};

  @override
  void initState() {
    super.initState();
    _loadStudents();

    for (final subject in _subjects) {
      _startTimes[subject] = const TimeOfDay(hour: 16, minute: 0);
      _endTimes[subject] = const TimeOfDay(hour: 17, minute: 0);
      _selectedDays[subject] = [];
    }
  }

  @override
  void dispose() {
    notesController.dispose();
    fileLinkController.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      final students = await StudentService.fetchStudents(token);
      if (!mounted) return;
      setState(() {
        allStudents = students;
        isLoadingStudents = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoadingStudents = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to load students: $e")));
    }
  }

  int? _extractPositiveInt(dynamic value) {
    if (value is List && value.isNotEmpty) {
      return _extractPositiveInt(value.first);
    }

    if (value is int) {
      return value > 0 ? value : null;
    }

    if (value is num) {
      final parsed = value.toInt();
      return parsed > 0 ? parsed : null;
    }

    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null && parsed > 0) {
        return parsed;
      }
    }

    return null;
  }

  String _formatDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  String _resolveCareType(String categoryName) {
    switch (categoryName.trim()) {
      case "Academic Support":
        return "academic";
      case "Emotional & Mental Wellbeing":
        return "emotional";
      case "Health & Safety":
        return "health";
      case "Inclusive Learning":
        return "inclusive";
      default:
        return categoryName
            .trim()
            .toLowerCase()
            .replaceAll('&', 'and')
            .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
            .replaceAll(RegExp(r'^_+|_+$'), '');
    }
  }

  Future<int?> _resolveAssignedTeacherId() async {
    final prefs = await SharedPreferences.getInstance();

    final savedTeacherId = prefs.getInt('teacher_id');
    if (savedTeacherId != null && savedTeacherId > 0) {
      return savedTeacherId;
    }

    final savedUserId = prefs.getInt('user_id');
    if (savedUserId != null && savedUserId > 0) {
      return savedUserId;
    }

    final rawUserData = prefs.getString('user_data');
    if (rawUserData == null || rawUserData.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(rawUserData);
      if (decoded is! Map) {
        return null;
      }

      final userData = Map<String, dynamic>.from(decoded);
      final resolvedId =
          _extractPositiveInt(userData['teacher_id']) ??
          _extractPositiveInt(userData['staffid']) ??
          _extractPositiveInt(userData['staff_id']) ??
          _extractPositiveInt(userData['user_id']) ??
          _extractPositiveInt(userData['id']);

      if (resolvedId != null) {
        await prefs.setInt('teacher_id', resolvedId);
      }

      return resolvedId;
    } catch (_) {
      return null;
    }
  }

  void _resetForm() {
    notesController.clear();
    fileLinkController.clear();

    setState(() {
      selectedStudents = [];

      for (final subject in _subjects) {
        _selectedDays[subject] = [];
        _startTimes[subject] = const TimeOfDay(hour: 16, minute: 0);
        _endTimes[subject] = const TimeOfDay(hour: 17, minute: 0);
      }
    });
  }

  void _showMultiSelectStudents() {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.all(12),
          child: ListView(
            children: allStudents.map((student) {
              final isSelected = selectedStudents.contains(student);
              return CheckboxListTile(
                title: Text(student.studentName),
                value: isSelected,
                onChanged: (bool? selected) {
                  setState(() {
                    if (selected == true) {
                      selectedStudents.add(student);
                    } else {
                      selectedStudents.remove(student);
                    }
                  });
                  Navigator.pop(context);
                  _showMultiSelectStudents(); // reopen modal to reflect changes
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Future<void> _submitSpecialCare() async {
    if (selectedStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least one student.")),
      );
      return;
    }

    final selectedDays = <String>[];
    final scheduleEntries = <String>[];

    for (final subject in _subjects) {
      final subjectDays = _selectedDays[subject] ?? const <String>[];
      if (subjectDays.isEmpty) {
        continue;
      }

      for (final day in subjectDays) {
        final fullDay = _weekdayNames[day] ?? day;
        if (!selectedDays.contains(fullDay)) {
          selectedDays.add(fullDay);
        }
      }

      final start = _startTimes[subject]!;
      final end = _endTimes[subject]!;
      scheduleEntries.add(
        "$subject: ${start.format(context)} - ${end.format(context)}",
      );
    }

    if (selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please choose at least one schedule day."),
        ),
      );
      return;
    }

    final assignedTeacherId = await _resolveAssignedTeacherId();
    if (assignedTeacherId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Unable to identify the current teacher. Please login again.",
          ),
        ),
      );
      return;
    }

    final notes = notesController.text.trim();
    final fileLink = fileLinkController.text.trim();
    final parsedFileLink = fileLink.isEmpty ? null : Uri.tryParse(fileLink);
    if (fileLink.isNotEmpty &&
        (parsedFileLink == null ||
            !parsedFileLink.hasScheme ||
            !parsedFileLink.isAbsolute)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid file link.")),
      );
      return;
    }

    final today = DateTime.now();
    final item = SpecialCareItem(
      studentIds: selectedStudents.map((student) => student.id).toList(),
      categoryId: widget.category.id,
      title: widget.category.name,
      description: notes.isEmpty ? widget.category.description : notes,
      careType: _resolveCareType(widget.category.name),
      days: selectedDays,
      time: scheduleEntries.join(", "),
      materials: fileLink.isEmpty ? const [] : [parsedFileLink.toString()],
      tools: const [],
      assignedTo: assignedTeacherId,
      status: "active",
      startDate: _formatDate(today),
      endDate: _formatDate(today.add(const Duration(days: 90))),
      visibility: "class",
    );

    setState(() => _isSubmitting = true);

    try {
      final createdItem = await _service.createSpecialCareItem(item);
      if (!mounted) return;

      _resetForm();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Special care item created for ${createdItem.categoryName ?? widget.category.name}.",
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD9CCDB),
      appBar: TeacherAppBar(),
      drawer: MenuDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Row(
                children: const [
                  SizedBox(width: 4),
                  Text(
                    "< Back",
                    style: TextStyle(color: Colors.black, fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: const Color(0xFF2E3192)),
                  child: SvgPicture.asset(
                    "assets/icons/special_care.svg",
                    height: 20,
                    width: 20,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.category.name,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E3192),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 🔽 Dynamic Student Dropdown
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Student Name",
                            style: TextStyle(fontSize: 14),
                          ),
                          const SizedBox(width: 20),
                          SizedBox(
                            width: 200,
                            child: isLoadingStudents
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : GestureDetector(
                                    onTap: _showMultiSelectStudents,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        border: Border.all(
                                          color: Colors.grey.shade400,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        selectedStudents.isEmpty
                                            ? "Select Students"
                                            : selectedStudents
                                                  .map((s) => s.studentName)
                                                  .join(", "),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Remedial Class Timetable
                      const Text(
                        'Remedial Class Timetable',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E3192),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Column(
                        children: _subjects.map((subject) {
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    subject,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: _weekdayChips.map((day) {
                                        final isSelected =
                                            _selectedDays[subject]?.contains(
                                              day,
                                            ) ??
                                            false;
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            right: 6,
                                          ),
                                          child: ChoiceChip(
                                            label: Text(
                                              day,
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                            selected: isSelected,
                                            selectedColor: Colors.blue.shade100,
                                            onSelected: (selected) {
                                              setState(() {
                                                if (selected) {
                                                  _selectedDays[subject] ??= [];
                                                  _selectedDays[subject]!.add(
                                                    day,
                                                  );
                                                } else {
                                                  _selectedDays[subject]
                                                      ?.remove(day);
                                                }
                                              });
                                            },
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Divider(height: 1, color: Colors.grey),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.schedule,
                                        size: 16,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(width: 6),
                                      GestureDetector(
                                        onTap: () async {
                                          final picked = await showTimePicker(
                                            context: context,
                                            initialTime: _startTimes[subject]!,
                                          );
                                          if (picked != null) {
                                            setState(
                                              () =>
                                                  _startTimes[subject] = picked,
                                            );
                                          }
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade200,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            _startTimes[subject]?.format(
                                                  context,
                                                ) ??
                                                'Start',
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        '-',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: () async {
                                          final picked = await showTimePicker(
                                            context: context,
                                            initialTime: _endTimes[subject]!,
                                          );
                                          if (picked != null) {
                                            setState(
                                              () => _endTimes[subject] = picked,
                                            );
                                          }
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade200,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            _endTimes[subject]?.format(
                                                  context,
                                                ) ??
                                                'End',
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 24),
                      const Text('File Link:', style: TextStyle(fontSize: 16)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: fileLinkController,
                        keyboardType: TextInputType.url,
                        textCapitalization: TextCapitalization.none,
                        autocorrect: false,
                        decoration: InputDecoration(
                          hintText: 'Paste Google Drive / file URL here',
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon: const Icon(Icons.link),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.grey),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('Notes:', style: TextStyle(fontSize: 16)),
                      const SizedBox(height: 8),
                      Container(
                        height: 100,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                          color: Colors.white,
                        ),
                        child: TextField(
                          controller: notesController,
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Enter notes here',
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitSpecialCare,
                          child: _isSubmitting
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Submit'),
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
    );
  }
}
