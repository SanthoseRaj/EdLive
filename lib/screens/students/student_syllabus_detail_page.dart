import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:school_app/screens/students/student_menu_drawer.dart';
import 'package:school_app/widgets/student_app_bar.dart';
import '../../models/student_syllabus_detail_model.dart';
import '../../services/student_syllabus_detail_service.dart';
import 'dart:async';

class SyllabusDetailPage extends StatefulWidget {
  final int classId;
  final int subjectId;
  final String academicYear;
  final String subjectName;

  const SyllabusDetailPage({
    super.key,
    required this.classId,
    required this.subjectId,
    required this.academicYear,
    required this.subjectName,
  });

  @override
  State<SyllabusDetailPage> createState() => _SyllabusDetailPageState();
}

class _SyllabusDetailPageState extends State<SyllabusDetailPage> {
  List<SyllabusDetail>? _currentData;
  SyllabusDetail? _selectedTerm;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchData();

    // Auto-check every 10 seconds (adjust as needed)
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _fetchData(checkForChanges: true);
    });
  }

  Future<void> _fetchData({bool checkForChanges = false}) async {
    try {
      final newData = await SyllabusService().fetchSyllabusDetail(
        widget.classId,
        widget.subjectId,
        widget.academicYear,
      );

      // Only update UI if new data differs from current
      if (!checkForChanges || _hasDataChanged(newData)) {
        setState(() {
          _currentData = newData;
          if (_selectedTerm != null) {
            // Keep selected term updated
            _selectedTerm = newData.firstWhere(
              (term) => term.term == _selectedTerm!.term,
              orElse: () => _selectedTerm!, // fallback to old value
            );
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching syllabus: $e");
    }
  }

  bool _hasDataChanged(List<SyllabusDetail> newData) {
    if (_currentData == null) return true;
    if (_currentData!.length != newData.length) return true;

    for (int i = 0; i < newData.length; i++) {
      final oldTerm = _currentData![i];
      final newTerm = newData[i];

      if (oldTerm.term != newTerm.term) return true;
      if (oldTerm.items.length != newTerm.items.length) return true;

      for (int j = 0; j < newTerm.items.length; j++) {
        final oldItem = oldTerm.items[j];
        final newItem = newTerm.items[j];

        if (oldItem.title != newItem.title ||
            oldItem.description != newItem.description) {
          return true;
        }
      }
    }

    return false; // No changes detected
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentData == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final details = _currentData!;

    return WillPopScope(
      onWillPop: () async {
        if (_selectedTerm != null) {
          setState(() => _selectedTerm = null);
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF91C1BC),
        appBar: StudentAppBar(),
        drawer: const StudentMenuDrawer(),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: GestureDetector(
                  onTap: () {
                    if (_selectedTerm != null) {
                      setState(() => _selectedTerm = null);
                    } else {
                      Navigator.pop(context);
                    }
                  },
                  child: const Text(
                    '< Back',
                    style: TextStyle(fontSize: 14, color: Colors.black),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
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
                    Expanded(
                      child: Text(
                        widget.subjectName,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E3192),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // List or Detail
              Expanded(
                child: _selectedTerm != null
                    ? _buildDetailView(_selectedTerm!)
                    : _buildListView(details),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailView(SyllabusDetail term) {
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
                term.term,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E3192),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ...term.items.asMap().entries.map((entry) {
              final itemIndex = entry.key + 1;
              final item = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "$itemIndex. ${item.title.isNotEmpty ? item.title : 'No title'}",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.description.isNotEmpty
                          ? item.description
                          : "No description",
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildListView(List<SyllabusDetail> details) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: details.length,
      itemBuilder: (context, index) {
        final term = details[index];
        return GestureDetector(
          onTap: () => setState(() => _selectedTerm = term),
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
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
            child: Text(
              term.term,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E3192),
              ),
            ),
          ),
        );
      },
    );
  }
}
