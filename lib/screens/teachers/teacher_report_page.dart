import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:school_app/screens/teachers/teacher_menu_drawer.dart';
import 'package:school_app/widgets/teacher_app_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/exam_type_model.dart';
import '../../models/teacher_class_student.dart';
import '../../services/exam_type_service.dart';
import '../../services/teacher_class_student_list.dart';
import 'package:school_app/services/teacher_class_section_service.dart';
import 'package:school_app/services/teacher_exam_subject_service.dart';

import 'package:provider/provider.dart';

import '/models/exam_result_detail_model.dart';
import 'package:school_app/providers/exam_result_provider.dart';
import '/models/exam_result_model.dart';
import '/services/teacher_exam_result_detail_service.dart';

final ValueNotifier<String> selectedTerm = ValueNotifier<String>("");

String _formatStudentLabel(String studentName, String? className) {
  final trimmedStudentName = studentName.trim();
  final trimmedClassName = className?.trim() ?? '';
  if (trimmedClassName.isEmpty) {
    return trimmedStudentName;
  }

  return '$trimmedStudentName ($trimmedClassName)';
}

class TeacherReportPage extends StatefulWidget {
  const TeacherReportPage({super.key});

  @override
  State<TeacherReportPage> createState() => _TeacherReportPageState();
}

class _TeacherReportPageState extends State<TeacherReportPage> {
  final TeacherExamResultDetailService _examResultDetailService =
      TeacherExamResultDetailService();
  int? selectedStudentId;
  int? _loadingMarksStudentId;
  bool _isRefreshingClassAverage = false;
  int _classAverageRefreshToken = 0;

  List<ExamType> examTypes = [];
  ExamType? selectedExamType;
  bool isLoadingExamTypes = true;

  List<Student> students = [];
  bool isLoadingStudents = true;

  List<TeacherClass> teacherClasses = [];
  TeacherClass? selectedClass;
  bool isLoadingClasses = true;

  List<String> subjects = [];
  Map<String, int> subjectExamIds = {};
  bool isLoadingSubjects = true;

  // studentId -> subject -> mark
  Map<int, Map<String, String>> studentMarks = {};
  // studentId -> subject -> exam result id
  Map<int, Map<String, int>> studentResultIds = {};

  final TextEditingController searchController = TextEditingController();

  List<Student> get filteredStudents {
    if (searchController.text.isEmpty) return students;
    return students
        .where(
          (s) => s.studentName.toLowerCase().contains(
            searchController.text.toLowerCase(),
          ),
        )
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _initializePage();
  }

  Future<void> _initializePage() async {
    await _loadTeacherClasses();
    await _loadExamTypes();
  }

  String _normalizeSubject(String subject) => subject.trim().toLowerCase();

  String _marksCacheKey(int studentId) {
    final classId = selectedClass?.id ?? 0;
    final examTypeId = selectedExamType?.id ?? 0;
    return 'teacher_report_marks_${classId}_${examTypeId}_$studentId';
  }

  Future<Map<String, String>> _loadCachedMarks(int studentId) async {
    final prefs = await SharedPreferences.getInstance();
    final rawCache = prefs.getString(_marksCacheKey(studentId));
    if (rawCache == null || rawCache.isEmpty) {
      return {};
    }

    try {
      final decoded = jsonDecode(rawCache);
      if (decoded is! Map) {
        return {};
      }
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
      );
    } catch (_) {
      return {};
    }
  }

  Future<void> _cacheMarks(int studentId, Map<String, String> marks) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_marksCacheKey(studentId), jsonEncode(marks));
  }

  String _formatAverageLabel(double? average) {
    if (average == null) {
      return "--";
    }

    final wholeNumber = average.truncateToDouble() == average;
    final formattedValue = wholeNumber
        ? average.toStringAsFixed(0)
        : average.toStringAsFixed(1);
    return "$formattedValue%";
  }

  String? _normalizeValue(String? value) {
    final normalized = _normalizeSubject(value ?? '');
    return normalized.isEmpty ? null : normalized;
  }

  String? _matchSubject(String? rawSubject) {
    final normalized = _normalizeValue(rawSubject);
    if (normalized == null) {
      return null;
    }

    for (final subject in subjects) {
      if (_normalizeSubject(subject) == normalized) {
        return subject;
      }
    }

    return null;
  }

  bool _resultMatchesSelectedExamType(ExamResultItem result) {
    final currentExamIds = _currentSubjectExamIds().values
        .where((examId) => examId > 0)
        .toSet();
    if (result.examId > 0 && currentExamIds.contains(result.examId)) {
      return true;
    }

    final selectedExamTypeName = _normalizeValue(
      selectedExamType?.examType ?? selectedTerm.value,
    );
    if (selectedExamTypeName == null) {
      return true;
    }

    return _normalizeValue(result.examType) == selectedExamTypeName ||
        _normalizeValue(result.term) == selectedExamTypeName;
  }

  String? _subjectForExamId(int examId) {
    String? normalizedSubject;

    for (final entry in subjectExamIds.entries) {
      if (entry.value == examId) {
        normalizedSubject = entry.key;
        break;
      }
    }

    if (normalizedSubject == null) {
      return null;
    }

    for (final subject in subjects) {
      if (_normalizeSubject(subject) == normalizedSubject) {
        return subject;
      }
    }

    return null;
  }

  String? _resolveSubjectForResult(ExamResultItem result) {
    return _subjectForExamId(result.examId) ??
        _matchSubject(result.subject) ??
        _matchSubject(result.examTitle);
  }

  Future<List<ExamResultItem>> _fetchExamResultsForSelectedType(
    int studentId,
  ) async {
    final requests = <Future<ExamResultData?> Function()>[
      () => _examResultDetailService.fetchStudentExamResults(
        studentId,
        examTypeId: selectedExamType?.id,
      ),
      if ((selectedExamType?.id ?? 0) > 0)
        () => _examResultDetailService.fetchStudentExamResults(studentId),
    ];

    Object? lastError;
    StackTrace? lastStackTrace;

    for (var index = 0; index < requests.length; index++) {
      try {
        final resultData = await requests[index]();
        final matchingResults =
            resultData?.examResults
                .where(_resultMatchesSelectedExamType)
                .toList() ??
            <ExamResultItem>[];

        if (matchingResults.isNotEmpty || index == requests.length - 1) {
          return matchingResults;
        }
      } catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
      }
    }

    if (lastError != null && lastStackTrace != null) {
      Error.throwWithStackTrace(lastError, lastStackTrace);
    }

    return <ExamResultItem>[];
  }

  Map<String, int> _currentSubjectExamIds() {
    return {
      for (final subject in subjects)
        subject: subjectExamIds[_normalizeSubject(subject)] ?? 0,
    };
  }

  Map<String, String> _currentMarksForStudent(int studentId) {
    final marks = studentMarks[studentId] ?? const <String, String>{};
    return {for (final subject in subjects) subject: marks[subject] ?? ''};
  }

  Map<String, int> _currentResultIdsForStudent(int studentId) {
    final resultIds = studentResultIds[studentId] ?? const <String, int>{};
    return {for (final subject in subjects) subject: resultIds[subject] ?? 0};
  }

  bool _isSubjectMarkSaved({
    required String subject,
    required Map<String, String> marksBySubject,
    required Map<String, int> resultIdsBySubject,
  }) {
    final resultId = resultIdsBySubject[subject] ?? 0;
    if (resultId > 0) {
      return true;
    }

    final mark = marksBySubject[subject]?.trim() ?? '';
    return mark.isNotEmpty;
  }

  bool _areAllSubjectsSaved({
    required Map<String, String> marksBySubject,
    required Map<String, int> resultIdsBySubject,
  }) {
    if (subjects.isEmpty) {
      return false;
    }

    return subjects.every((subject) {
      return _isSubjectMarkSaved(
        subject: subject,
        marksBySubject: marksBySubject,
        resultIdsBySubject: resultIdsBySubject,
      );
    });
  }

  bool _isMarksEntryLocked(int studentId) {
    return _areAllSubjectsSaved(
      marksBySubject: _currentMarksForStudent(studentId),
      resultIdsBySubject: _currentResultIdsForStudent(studentId),
    );
  }

  double? _calculateClassAveragePercentage() {
    var totalMarks = 0;
    var enteredSubjectsCount = 0;

    for (final student in students) {
      final marksBySubject = _currentMarksForStudent(student.id);
      for (final subject in subjects) {
        final rawMark = marksBySubject[subject]?.trim() ?? '';
        final parsedMark = int.tryParse(rawMark);
        if (parsedMark == null) {
          continue;
        }

        totalMarks += parsedMark;
        enteredSubjectsCount++;
      }
    }

    if (enteredSubjectsCount == 0) {
      return null;
    }

    return totalMarks / enteredSubjectsCount;
  }

  Map<String, String> _normalizeMarksBySubject(Map<String, String> marks) {
    final normalizedMarks = <String, String>{};
    for (final entry in marks.entries) {
      final subject = _normalizeValue(entry.key);
      final mark = entry.value.trim();
      if (subject == null || mark.isEmpty) {
        continue;
      }
      normalizedMarks[subject] = mark;
    }
    return normalizedMarks;
  }

  Student? _studentById(int? studentId) {
    if (studentId == null) {
      return null;
    }

    for (final student in students) {
      if (student.id == studentId) {
        return student;
      }
    }

    return null;
  }

  TeacherClass? _teacherClassForId(int classId) {
    for (final teacherClass in teacherClasses) {
      if (teacherClass.id == classId) {
        return teacherClass;
      }
    }

    return null;
  }

  String _normalizeClassLabel(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  List<Student> _filterStudentsForClass(
    List<Student> studentList,
    TeacherClass? teacherClass,
  ) {
    if (teacherClass == null) {
      return studentList;
    }

    final candidates = <String>{
      _normalizeClassLabel(teacherClass.fullName),
      _normalizeClassLabel('${teacherClass.className}${teacherClass.section}'),
      _normalizeClassLabel('${teacherClass.className} ${teacherClass.section}'),
    }..removeWhere((value) => value.isEmpty);

    if (candidates.isEmpty) {
      return studentList;
    }

    final filtered = studentList
        .where(
          (student) =>
              candidates.contains(_normalizeClassLabel(student.className)),
        )
        .toList();

    return filtered.isNotEmpty ? filtered : studentList;
  }

  Future<_StudentMarksSnapshot> _buildInitialStudentMarksSnapshot(
    int studentId,
  ) async {
    final mergedMarks = {
      for (final subject in subjects)
        subject: studentMarks[studentId]?[subject] ?? '',
    };
    final mergedResultIds = {
      for (final subject in subjects)
        subject: studentResultIds[studentId]?[subject] ?? 0,
    };
    final cachedMarks = _normalizeMarksBySubject(
      await _loadCachedMarks(studentId),
    );
    for (final subject in subjects) {
      final cachedValue = cachedMarks[_normalizeSubject(subject)];
      if (cachedValue != null && cachedValue.isNotEmpty) {
        mergedMarks[subject] = cachedValue;
      }
    }

    return _StudentMarksSnapshot(
      marks: mergedMarks,
      resultIds: mergedResultIds,
    );
  }

  Future<_StudentMarksSnapshot> _resolveStudentMarksSnapshot(
    int studentId, {
    _StudentMarksSnapshot? initialSnapshot,
  }) async {
    final snapshot =
        initialSnapshot ?? await _buildInitialStudentMarksSnapshot(studentId);

    try {
      final results = await _fetchExamResultsForSelectedType(studentId);

      for (final result in results) {
        final subject = _resolveSubjectForResult(result);
        if (subject == null) {
          continue;
        }

        final currentResultId = snapshot.resultIds[subject] ?? 0;
        final canUseResult =
            result.id <= 0 ||
            currentResultId == 0 ||
            result.id >= currentResultId;
        if (!canUseResult) {
          continue;
        }

        if (result.id > 0) {
          snapshot.resultIds[subject] = result.id;
        }

        final marks = result.marks?.trim();
        if (marks == null || marks.isEmpty) {
          continue;
        }
        snapshot.marks[subject] = marks;
      }

      await _cacheMarks(studentId, snapshot.marks);
    } catch (_) {
      // Keep cached/local marks when backend details are unavailable.
    }

    return snapshot;
  }

  Future<void> _refreshAllStudentMarksForAverage() async {
    if (students.isEmpty || subjects.isEmpty) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isRefreshingClassAverage = false;
      });
      return;
    }

    final refreshToken = ++_classAverageRefreshToken;
    if (mounted) {
      setState(() {
        _isRefreshingClassAverage = true;
      });
    }

    try {
      for (final student in students) {
        if (!mounted || refreshToken != _classAverageRefreshToken) {
          return;
        }

        final resolvedSnapshot = await _resolveStudentMarksSnapshot(student.id);
        if (!mounted || refreshToken != _classAverageRefreshToken) {
          return;
        }

        setState(() {
          studentMarks[student.id] = resolvedSnapshot.marks;
          studentResultIds[student.id] = resolvedSnapshot.resultIds;
        });
      }
    } finally {
      if (mounted && refreshToken == _classAverageRefreshToken) {
        setState(() {
          _isRefreshingClassAverage = false;
        });
      }
    }
  }

  Future<void> _loadSavedMarksForStudent(int studentId) async {
    final initialSnapshot = await _buildInitialStudentMarksSnapshot(studentId);

    if (!mounted) {
      return;
    }

    setState(() {
      _loadingMarksStudentId = studentId;
      studentMarks[studentId] = initialSnapshot.marks;
      studentResultIds[studentId] = initialSnapshot.resultIds;
    });

    try {
      final resolvedSnapshot = await _resolveStudentMarksSnapshot(
        studentId,
        initialSnapshot: initialSnapshot,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        studentMarks[studentId] = resolvedSnapshot.marks;
        studentResultIds[studentId] = resolvedSnapshot.resultIds;
      });
    } finally {
      if (mounted) {
        setState(() {
          if (_loadingMarksStudentId == studentId) {
            _loadingMarksStudentId = null;
          }
        });
      }
    }
  }

  Future<void> _selectStudent(Student student) async {
    if (!mounted) {
      return;
    }

    setState(() {
      selectedStudentId = student.id;
    });

    await _loadSavedMarksForStudent(student.id);
  }

  Future<void> _showMarkEntrySheet(Student student) async {
    final isFullyReadOnly = _isMarksEntryLocked(student.id);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;

        return AnimatedPadding(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(
            bottom: bottomInset,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: FractionallySizedBox(
            heightFactor: 0.82,
            child: MarkEntryCard(
              student: student,
              subjectExamIds: _currentSubjectExamIds(),
              subjectsMarks: _currentMarksForStudent(student.id),
              existingResultIds: _currentResultIdsForStudent(student.id),
              isFullyReadOnly: isFullyReadOnly,
              onSave: (updatedMarks, updatedResultIds) {
                setState(() {
                  studentMarks[student.id] = updatedMarks;
                  studentResultIds[student.id] = updatedResultIds;
                });
                unawaited(_cacheMarks(student.id, updatedMarks));
                Navigator.of(sheetContext).pop();
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleStudentEdit(
    Student student, {
    required bool openBottomSheet,
  }) async {
    await _selectStudent(student);
    if (!mounted || !context.mounted) {
      return;
    }

    if (openBottomSheet) {
      await _showMarkEntrySheet(student);
    }
  }

  Future<void> _loadTeacherClasses() async {
    try {
      final classes = await TeacherClassService().fetchTeacherClasses();
      if (!mounted) {
        return;
      }
      setState(() {
        teacherClasses = classes;
        isLoadingClasses = false;
        if (classes.isNotEmpty) selectedClass = classes.first;
      });

      if (classes.isNotEmpty) {
        await _loadSubjectsByClass(classes.first.id);
        await _loadStudentsByClass(classes.first.id);
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => isLoadingClasses = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load teacher classes: $e")),
      );
    }
  }

  Future<void> _loadExamTypes() async {
    try {
      final types = await ExamTypeService().fetchExamTypes();
      if (!mounted) {
        return;
      }
      setState(() {
        examTypes = types;
        if (types.isNotEmpty) {
          selectedExamType = types.first;
          selectedTerm.value = types.first.examType;
        }
        isLoadingExamTypes = false;
      });

      if (types.isNotEmpty && selectedClass != null) {
        await _loadSubjectsByClass(selectedClass!.id);
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => isLoadingExamTypes = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to load exam types: $e")));
    }
  }

  Future<void> _loadStudentsByClass(int classId) async {
    setState(() => isLoadingStudents = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';

      final studentList = await StudentService.fetchStudents(token);
      final classStudents = _filterStudentsForClass(
        studentList,
        selectedClass?.id == classId
            ? selectedClass
            : _teacherClassForId(classId),
      );
      final hasSelectedStudent =
          selectedStudentId != null &&
          classStudents.any((student) => student.id == selectedStudentId);

      if (!mounted) {
        return;
      }

      setState(() {
        students = classStudents;
        isLoadingStudents = false;
        if (!hasSelectedStudent) {
          selectedStudentId = null;
          _loadingMarksStudentId = null;
        }

        // Initialize studentMarks for all students
        for (var st in students) {
          studentMarks[st.id] = {
            for (var subj in subjects) subj: studentMarks[st.id]?[subj] ?? "",
          };
          studentResultIds[st.id] = {
            for (var subj in subjects)
              subj: studentResultIds[st.id]?[subj] ?? 0,
          };
        }
      });

      if (hasSelectedStudent && selectedStudentId != null) {
        await _loadSavedMarksForStudent(selectedStudentId!);
      }
      unawaited(_refreshAllStudentMarksForAverage());
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => isLoadingStudents = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to load students: $e")));
    }
  }

  Future<void> _loadSubjectsByClass(int classId) async {
    setState(() => isLoadingSubjects = true);
    try {
      final allExams = await TeacherExamService().fetchTeacherExams();
      final filteredExams = allExams
          .where(
            (e) =>
                e.classId == classId &&
                (selectedExamType == null ||
                    e.examType == selectedExamType?.examType),
          )
          .toList();
      final subjectList = filteredExams.map((e) => e.subject).toSet().toList();
      final nextSubjectExamIds = <String, int>{};
      for (final exam in filteredExams) {
        nextSubjectExamIds.putIfAbsent(
          _normalizeSubject(exam.subject),
          () => exam.id,
        );
      }

      if (!mounted) {
        return;
      }
      setState(() {
        subjects = subjectList;
        subjectExamIds = nextSubjectExamIds;
        isLoadingSubjects = false;

        // Initialize studentMarks if students already loaded
        for (var st in students) {
          studentMarks[st.id] = {
            for (var s in subjects) s: studentMarks[st.id]?[s] ?? "",
          };
          studentResultIds[st.id] = {
            for (var s in subjects) s: studentResultIds[st.id]?[s] ?? 0,
          };
        }
      });

      if (selectedStudentId != null) {
        await _loadSavedMarksForStudent(selectedStudentId!);
      }
      unawaited(_refreshAllStudentMarksForAverage());
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => isLoadingSubjects = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to load subjects: $e")));
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isWide = MediaQuery.of(context).size.width > 700;
    final selectedStudent = _studentById(selectedStudentId);
    final classAverageLabel = _formatAverageLabel(
      _calculateClassAveragePercentage(),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: TeacherAppBar(),
      drawer: const MenuDrawer(),
      body: Container(
        color: const Color(0xFFFDCFD0),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back button + Title
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Row(
                    children: const [
                      SizedBox(width: 4),
                      Text(
                        "< Back",
                        style: TextStyle(color: Colors.black, fontSize: 16),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Color(0xFF2E3192),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SvgPicture.asset(
                        "assets/icons/reports.svg",
                        height: 36,
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      "Teacher Report",
                      style: TextStyle(
                        color: Color(0xFF2E3192),
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Avg + Dropdowns
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Class Average
                SizedBox(
                  width: 135,
                  height: 100,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade400),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.shade300,
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Total Class Avg %",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF666666),
                          ),
                        ),
                        const SizedBox(height: 4),
                        _isRefreshingClassAverage
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF2E3192),
                                ),
                              )
                            : Text(
                                classAverageLabel,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2E3192),
                                ),
                              ),
                      ],
                    ),
                  ),
                ),

                // Right side → Dropdowns
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Class Dropdown
                    // Class Dropdown
                    // Class Dropdown
                    isLoadingClasses
                        ? const SizedBox(
                            height: 42,
                            width: 42,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Container(
                            height: 42,
                            width:
                                MediaQuery.of(context).size.width *
                                0.4, // 📱 40% of screen width
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade400),
                            ),
                            child: DropdownButton<TeacherClass>(
                              value: selectedClass,
                              isExpanded: true, // 🔑 take full available width
                              underline: const SizedBox(),
                              icon: const Icon(
                                Icons.arrow_drop_down,
                                size: 28,
                                color: Colors.black,
                              ),
                              hint: const Text("Select Class"),
                              items: teacherClasses.map((cls) {
                                return DropdownMenuItem(
                                  value: cls,
                                  child: Text(cls.fullName),
                                );
                              }).toList(),
                              onChanged: (newClass) async {
                                if (newClass != null) {
                                  setState(() {
                                    selectedClass = newClass;
                                    selectedStudentId = null;
                                    _loadingMarksStudentId = null;
                                    isLoadingStudents = true;
                                    isLoadingSubjects = true;
                                    _isRefreshingClassAverage = true;
                                  });
                                  await _loadSubjectsByClass(newClass.id);
                                  await _loadStudentsByClass(newClass.id);
                                }
                              },
                            ),
                          ),

                    const SizedBox(height: 12),

                    // Exam Dropdown
                    ValueListenableBuilder<String>(
                      valueListenable: selectedTerm,
                      builder: (context, value, _) {
                        if (isLoadingExamTypes) {
                          return const SizedBox(
                            height: 42,
                            width: 42,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          );
                        }
                        if (examTypes.isEmpty) {
                          return const Text("No Exam Types");
                        }
                        return Container(
                          height: 42,
                          width:
                              MediaQuery.of(context).size.width *
                              0.4, // 📱 40% of screen width
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade400),
                          ),
                          child: DropdownButton<ExamType>(
                            value: selectedExamType,
                            isExpanded: true,
                            underline: const SizedBox(),
                            icon: const Icon(
                              Icons.arrow_drop_down,
                              size: 28,
                              color: Colors.black,
                            ),
                            items: examTypes.map((exam) {
                              return DropdownMenuItem(
                                value: exam,
                                child: Text(exam.examType),
                              );
                            }).toList(),
                            onChanged: (newVal) async {
                              if (newVal != null) {
                                setState(() {
                                  selectedExamType = newVal;
                                  selectedTerm.value = newVal.examType;
                                  isLoadingSubjects = true;
                                  _isRefreshingClassAverage = true;
                                });
                                if (selectedClass != null) {
                                  await _loadSubjectsByClass(selectedClass!.id);
                                }
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Student + Marks
            Expanded(
              child: isLoadingStudents
                  ? const Center(child: CircularProgressIndicator())
                  : isWide
                  ? Row(
                      children: [
                        // Student List
                        SizedBox(
                          width: 300,
                          child: Column(
                            children: [
                              TextField(
                                controller: searchController,
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(Icons.search),
                                  hintText: "Search students",
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                onChanged: (val) => setState(() {}),
                              ),
                              const SizedBox(height: 12),
                              Expanded(
                                child: ListView.builder(
                                  itemCount: filteredStudents.length,
                                  itemBuilder: (context, index) {
                                    final student = filteredStudents[index];
                                    final isSelected =
                                        student.id == selectedStudentId;
                                    final isLocked = _isMarksEntryLocked(
                                      student.id,
                                    );
                                    return Card(
                                      color: isSelected
                                          ? const Color(0xFFEAEAEA)
                                          : Colors.white,
                                      shape: RoundedRectangleBorder(
                                        side: BorderSide(
                                          color: isSelected
                                              ? const Color(0xFF2E3192)
                                              : Colors.grey.shade300,
                                          width: isSelected ? 2 : 1,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      margin: const EdgeInsets.symmetric(
                                        vertical: 6,
                                      ),
                                      child: ListTile(
                                        title: Text(
                                          _formatStudentLabel(
                                            student.studentName,
                                            student.className,
                                          ),
                                          style: TextStyle(
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            color: isSelected
                                                ? const Color(0xFF2E3192)
                                                : Colors.black87,
                                          ),
                                        ),
                                        trailing:
                                            _loadingMarksStudentId == student.id
                                            ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Color(0xFF2E3192),
                                                    ),
                                              )
                                            : IconButton(
                                                icon: Icon(
                                                  isLocked
                                                      ? Icons.lock_outline
                                                      : Icons.edit,
                                                  color: isLocked
                                                      ? Colors.grey
                                                      : const Color(0xFF2E3192),
                                                ),
                                                tooltip: isLocked
                                                    ? "Marks locked"
                                                    : "Enter marks",
                                                onPressed: isLocked
                                                    ? null
                                                    : () => _handleStudentEdit(
                                                        student,
                                                        openBottomSheet: false,
                                                      ),
                                              ),
                                        onTap: () => _handleStudentEdit(
                                          student,
                                          openBottomSheet: false,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),

                        // Mark Entry
                        Expanded(
                          child: selectedStudent == null
                              ? Center(
                                  child: Text(
                                    "Select a student to enter marks",
                                    style: TextStyle(
                                      fontSize: 20,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                )
                              : _loadingMarksStudentId == selectedStudentId
                              ? const Center(child: CircularProgressIndicator())
                              : MarkEntryCard(
                                  student: selectedStudent,
                                  subjectExamIds: {
                                    for (final entry
                                        in _currentSubjectExamIds().entries)
                                      entry.key: entry.value,
                                  },
                                  subjectsMarks: _currentMarksForStudent(
                                    selectedStudentId!,
                                  ),
                                  existingResultIds:
                                      _currentResultIdsForStudent(
                                        selectedStudentId!,
                                      ),
                                  isFullyReadOnly: _isMarksEntryLocked(
                                    selectedStudentId!,
                                  ),
                                  onSave: (updatedMarks, updatedResultIds) {
                                    setState(() {
                                      studentMarks[selectedStudentId!] =
                                          updatedMarks;
                                      studentResultIds[selectedStudentId!] =
                                          updatedResultIds;
                                    });
                                    unawaited(
                                      _cacheMarks(
                                        selectedStudentId!,
                                        updatedMarks,
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        TextField(
                          controller: searchController,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search),
                            hintText: "Search students",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          onChanged: (val) => setState(() {}),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: ListView.builder(
                            itemCount: filteredStudents.length,
                            itemBuilder: (context, index) {
                              final student = filteredStudents[index];
                              final isLocked = _isMarksEntryLocked(student.id);
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                child: ListTile(
                                  title: Text(
                                    _formatStudentLabel(
                                      student.studentName,
                                      student.className,
                                    ),
                                  ),
                                  trailing: _loadingMarksStudentId == student.id
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFF2E3192),
                                          ),
                                        )
                                      : IconButton(
                                          icon: Icon(
                                            isLocked
                                                ? Icons.lock_outline
                                                : Icons.edit,
                                            color: isLocked
                                                ? Colors.grey
                                                : const Color(0xFF2E3192),
                                          ),
                                          tooltip: isLocked
                                              ? "Marks locked"
                                              : "Enter marks",
                                          onPressed: isLocked
                                              ? null
                                              : () => _handleStudentEdit(
                                                  student,
                                                  openBottomSheet: true,
                                                ),
                                        ),
                                  onTap: () => _handleStudentEdit(
                                    student,
                                    openBottomSheet: true,
                                  ),
                                ),
                              );
                            },
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

class MarkEntryCard extends StatefulWidget {
  final Student student;
  final Map<String, int> subjectExamIds;
  final Map<String, String> subjectsMarks;
  final Map<String, int> existingResultIds;
  final bool isFullyReadOnly;
  final void Function(Map<String, String>, Map<String, int>) onSave;

  const MarkEntryCard({
    required this.student,
    required this.subjectExamIds,
    required this.subjectsMarks,
    required this.existingResultIds,
    this.isFullyReadOnly = false,
    required this.onSave,
    super.key,
  });

  @override
  State<MarkEntryCard> createState() => _MarkEntryCardState();
}

class _MarkEntryCardState extends State<MarkEntryCard> {
  static final List<TextInputFormatter> _markInputFormatters = [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(3),
    const _MarkRangeInputFormatter(maxValue: 100),
  ];
  late Map<String, TextEditingController> controllers;
  late Map<String, FocusNode> _focusNodes;
  late Map<String, GlobalKey> _fieldKeys;
  final ScrollController _listScrollController = ScrollController();
  bool _isSaving = false;

  Map<String, TextEditingController> _buildControllers(
    Map<String, String> marks,
  ) {
    return {
      for (final entry in marks.entries)
        entry.key: TextEditingController(text: entry.value),
    };
  }

  Map<String, FocusNode> _buildFocusNodes(Iterable<String> subjects) {
    final nodes = <String, FocusNode>{};
    for (final subject in subjects) {
      final focusNode = FocusNode();
      focusNode.addListener(() {
        if (focusNode.hasFocus) {
          _scrollFieldToTop(subject);
        }
      });
      nodes[subject] = focusNode;
    }
    return nodes;
  }

  Map<String, GlobalKey> _buildFieldKeys(Iterable<String> subjects) {
    return {for (final subject in subjects) subject: GlobalKey()};
  }

  void _initializeFieldState(Map<String, String> marks) {
    controllers = _buildControllers(marks);
    _focusNodes = _buildFocusNodes(marks.keys);
    _fieldKeys = _buildFieldKeys(marks.keys);
  }

  void _disposeFieldState() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes.values) {
      focusNode.dispose();
    }
  }

  void _scrollFieldToTop(String subject) {
    Future.delayed(const Duration(milliseconds: 250), () {
      if (!mounted) {
        return;
      }

      final fieldContext = _fieldKeys[subject]?.currentContext;
      if (fieldContext == null || !fieldContext.mounted) {
        return;
      }

      Scrollable.ensureVisible(
        fieldContext,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        alignment: 0.08,
      );
    });
  }

  void _showBottomPopup(String message, {bool isError = false}) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      return;
    }

    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError
              ? Colors.red.shade700
              : const Color(0xFF2E3192),
          margin: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            MediaQuery.of(context).padding.bottom + 16,
          ),
        ),
      );
  }

  String _readableError(Object error) {
    final message = error.toString().trim();
    if (message.startsWith('Exception: ')) {
      return message.substring('Exception: '.length).trim();
    }
    return message;
  }

  bool _isSubjectReadOnly(String subject) {
    final resultId = widget.existingResultIds[subject] ?? 0;
    if (resultId > 0) {
      return true;
    }

    final currentValue = widget.subjectsMarks[subject]?.trim() ?? '';
    return currentValue.isNotEmpty;
  }

  bool get _hasLockedSubjects {
    return widget.subjectsMarks.keys.any(_isSubjectReadOnly);
  }

  void _focusNextEditableField(
    int currentIndex,
    List<MapEntry<String, TextEditingController>> subjectEntries,
  ) {
    for (
      var nextIndex = currentIndex + 1;
      nextIndex < subjectEntries.length;
      nextIndex++
    ) {
      final nextSubject = subjectEntries[nextIndex].key;
      if (_isSubjectReadOnly(nextSubject)) {
        continue;
      }

      _focusNodes[nextSubject]?.requestFocus();
      return;
    }

    FocusScope.of(context).unfocus();
  }

  @override
  void initState() {
    super.initState();
    _initializeFieldState(widget.subjectsMarks);
  }

  @override
  void didUpdateWidget(covariant MarkEntryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final isDifferentStudent = oldWidget.student.id != widget.student.id;
    final isDifferentMarks =
        oldWidget.subjectsMarks.length != widget.subjectsMarks.length ||
        widget.subjectsMarks.entries.any(
          (entry) => oldWidget.subjectsMarks[entry.key] != entry.value,
        );

    if (isDifferentStudent || isDifferentMarks) {
      _disposeFieldState();
      _initializeFieldState(widget.subjectsMarks);
    }
  }

  @override
  void dispose() {
    _disposeFieldState();
    _listScrollController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving || widget.isFullyReadOnly) {
      if (widget.isFullyReadOnly) {
        _showBottomPopup(
          "Marks already saved for ${widget.student.studentName}. Editing is disabled.",
          isError: true,
        );
      }
      return;
    }

    final updatedMarks = {
      for (var entry in controllers.entries) entry.key: entry.value.text.trim(),
    };
    final updatedResultIds = {
      for (final subject in widget.subjectsMarks.keys)
        subject: widget.existingResultIds[subject] ?? 0,
    };

    final provider = Provider.of<ExamResultProvider>(context, listen: false);
    final resultsToSave = <_PendingResultSave>[];

    for (final entry in updatedMarks.entries.toList()) {
      if (_isSubjectReadOnly(entry.key)) {
        final previousMark = widget.subjectsMarks[entry.key] ?? '';
        updatedMarks[entry.key] = previousMark;
        controllers[entry.key]?.text = previousMark;
        continue;
      }

      final examId = widget.subjectExamIds[entry.key] ?? 0;
      if (examId <= 0) {
        _showBottomPopup(
          "Exam mapping missing for ${entry.key}",
          isError: true,
        );
        return;
      }

      final existingResultId = updatedResultIds[entry.key] ?? 0;
      if (entry.value.isEmpty) {
        if (existingResultId > 0) {
          final previousMark = widget.subjectsMarks[entry.key] ?? '';
          updatedMarks[entry.key] = previousMark;
          controllers[entry.key]?.text = previousMark;
        }
        continue;
      }

      final marks = int.tryParse(entry.value);
      if (marks == null) {
        _showBottomPopup(
          "Enter a valid number for ${entry.key}",
          isError: true,
        );
        return;
      }

      if (marks > 100) {
        _showBottomPopup(
          "${entry.key} mark must be between 0 and 100",
          isError: true,
        );
        return;
      }

      resultsToSave.add(
        _PendingResultSave(
          subject: entry.key,
          resultId: existingResultId > 0 ? existingResultId : null,
          result: ExamResult(
            examId: examId,
            studentId: widget.student.id,
            marks: marks,
            percentage: marks.toDouble(),
            grade: _calculateGrade(marks),
            term: selectedTerm.value,
            isFinal: true,
            classRank: 1,
          ),
        ),
      );
    }

    if (resultsToSave.isEmpty) {
      _showBottomPopup("Enter at least one mark to save", isError: true);
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      for (final pendingSave in resultsToSave) {
        final savedResultId = await provider.saveResult(
          pendingSave.result,
          resultId: pendingSave.resultId,
        );
        if (savedResultId != null && savedResultId > 0) {
          updatedResultIds[pendingSave.subject] = savedResultId;
        }
      }

      if (!mounted) {
        return;
      }

      FocusScope.of(context).unfocus();
      _showBottomPopup("Marks saved for ${widget.student.studentName}");
      widget.onSave(updatedMarks, updatedResultIds);
    } catch (e) {
      if (!mounted) {
        return;
      }
      _showBottomPopup(
        "Failed to save marks: ${_readableError(e)}",
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // Example grade calculation
  String _calculateGrade(int marks) {
    if (marks >= 90) return "A+";
    if (marks >= 80) return "A";
    if (marks >= 70) return "B";
    if (marks >= 60) return "C";
    return "D";
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final subjectEntries = controllers.entries.toList();
    final isFullyReadOnly = widget.isFullyReadOnly;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20, top: 10, left: 4, right: 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableHeight =
              screenHeight -
              MediaQuery.of(context).padding.vertical -
              viewInsets -
              48;
          final targetHeight = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : availableHeight * 0.72;
          final cardHeight = targetHeight.clamp(320.0, availableHeight);

          return Card(
            elevation: 5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: SizedBox(
              height: cardHeight.toDouble(),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${isFullyReadOnly ? 'Marks for' : 'Enter Marks for'} ${_formatStudentLabel(widget.student.studentName, widget.student.className)}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        color: Color(0xFF2E3192),
                      ),
                    ),
                    if (isFullyReadOnly) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F3D1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          "All subjects already saved. Editing is disabled.",
                          style: TextStyle(
                            color: Color(0xFF5C4B00),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ] else if (_hasLockedSubjects) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF4FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          "Saved subjects are locked. Enter marks only for empty subjects.",
                          style: TextStyle(
                            color: Color(0xFF184A8B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Expanded(
                      child: subjectEntries.isEmpty
                          ? const Center(
                              child: Text(
                                "No subjects available",
                                style: TextStyle(color: Colors.black54),
                              ),
                            )
                          : Scrollbar(
                              controller: _listScrollController,
                              child: ListView.separated(
                                controller: _listScrollController,
                                padding: const EdgeInsets.only(bottom: 12),
                                keyboardDismissBehavior:
                                    ScrollViewKeyboardDismissBehavior.onDrag,
                                itemCount: subjectEntries.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 20),
                                itemBuilder: (context, index) {
                                  final entry = subjectEntries[index];
                                  final isSubjectReadOnly = _isSubjectReadOnly(
                                    entry.key,
                                  );
                                  return Container(
                                    key: _fieldKeys[entry.key],
                                    child: TextField(
                                      controller: entry.value,
                                      focusNode: _focusNodes[entry.key],
                                      readOnly: isSubjectReadOnly,
                                      showCursor: !isSubjectReadOnly,
                                      decoration: InputDecoration(
                                        labelText: entry.key,
                                        hintText: "0 - 100",
                                        filled: isSubjectReadOnly,
                                        fillColor: isSubjectReadOnly
                                            ? Colors.grey.shade100
                                            : null,
                                        suffixIcon: isSubjectReadOnly
                                            ? const Icon(
                                                Icons.lock_outline,
                                                size: 18,
                                              )
                                            : null,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      keyboardType: TextInputType.number,
                                      inputFormatters: _markInputFormatters,
                                      textInputAction:
                                          index == subjectEntries.length - 1
                                          ? TextInputAction.done
                                          : TextInputAction.next,
                                      scrollPadding: EdgeInsets.only(
                                        top: 24,
                                        bottom: viewInsets + 120,
                                      ),
                                      onTap: isSubjectReadOnly
                                          ? null
                                          : () => _scrollFieldToTop(entry.key),
                                      onSubmitted: isSubjectReadOnly
                                          ? null
                                          : (_) {
                                              _focusNextEditableField(
                                                index,
                                                subjectEntries,
                                              );
                                            },
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
                    const SizedBox(height: 10),
                    SafeArea(
                      top: false,
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSaving || isFullyReadOnly
                              ? null
                              : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isFullyReadOnly
                                ? Colors.grey.shade400
                                : Colors.grey,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  isFullyReadOnly
                                      ? "Marks Locked"
                                      : "Save Marks",
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Color(0xFF2E3192),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StudentMarksSnapshot {
  final Map<String, String> marks;
  final Map<String, int> resultIds;

  const _StudentMarksSnapshot({required this.marks, required this.resultIds});
}

class _PendingResultSave {
  final String subject;
  final int? resultId;
  final ExamResult result;

  const _PendingResultSave({
    required this.subject,
    required this.resultId,
    required this.result,
  });
}

class _MarkRangeInputFormatter extends TextInputFormatter {
  final int maxValue;

  const _MarkRangeInputFormatter({required this.maxValue});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.trim();
    if (text.isEmpty) {
      return newValue;
    }

    final mark = int.tryParse(text);
    if (mark == null || mark > maxValue) {
      return oldValue;
    }

    return newValue;
  }
}
