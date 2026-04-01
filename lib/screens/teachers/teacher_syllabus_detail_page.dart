import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:school_app/widgets/teacher_app_bar.dart';
import 'teacher_menu_drawer.dart';
import '../../services/teacher_syllabus_service_page2.dart';

class SyllabusDetailPage extends StatefulWidget {
  final String selectedClass;
  final int classId;
  final int subjectId;
  final String subject;
  final String academicYear;

  const SyllabusDetailPage({
    super.key,
    required this.selectedClass,
    required this.classId,
    required this.subjectId,
    required this.subject,
    this.academicYear = "2025-2026",
  });

  @override
  State<SyllabusDetailPage> createState() => _SyllabusDetailPageState();
}

class _SyllabusDetailPageState extends State<SyllabusDetailPage> {
  final SyllabusService syllabusService = SyllabusService();
  late Future<List<SyllabusTerm>> syllabusFuture;

  bool isAdding = false;
  int? selectedSyllabusId;
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final sequenceController = TextEditingController();

  SyllabusTerm? _selectedTerm; // selected term for detail view

  @override
  void initState() {
    super.initState();
    syllabusFuture = syllabusService.fetchSyllabus(
      widget.classId,
      widget.subjectId,
      widget.academicYear,
    );
  }

  void _resetForm() {
    selectedSyllabusId = null;
    titleController.clear();
    descriptionController.clear();
    sequenceController.clear();
    isAdding = false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (isAdding) {
          setState(() => _resetForm());
          return false; // ❌ prevent pop
        } else if (_selectedTerm != null) {
          setState(() => _selectedTerm = null);
          return false; // ❌ prevent pop
        }
        return true; // ✅ allow pop
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFA7D7A7),
        appBar: TeacherAppBar(),
        drawer: MenuDrawer(),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🔙 Back
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: GestureDetector(
                  onTap: () {
                    if (isAdding) {
                      setState(() => _resetForm());
                    } else if (_selectedTerm != null) {
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

              // 📘 Header
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
                        widget.subject,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E3192),
                        ),
                      ),
                    ),
                    // Add button
                    ElevatedButton.icon(
                      onPressed: () => setState(() => isAdding = true),
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text("Add"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF29ABE2),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 🔹 List / Detail / Add Form
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: isAdding
                      ? _buildAddForm()
                      : (_selectedTerm != null
                            ? _buildDetailView(_selectedTerm!)
                            : _buildSyllabusList()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 🔹 Detail view of selected term
  Widget _buildDetailView(SyllabusTerm term) {
    final sortedItems = [...term.items]
      ..sort((a, b) => (a.sequence ?? 0).compareTo(b.sequence ?? 0));

    return Container(
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
            ...sortedItems.asMap().entries.map((entry) {
              final index = entry.key + 1;
              final item = entry.value;
              final title = item.title?.trim() ?? '';
              final desc = item.description?.trim() ?? '';

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "$index. ${title.isNotEmpty ? title : 'No title'}",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (desc.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(desc, style: const TextStyle(fontSize: 14)),
                      ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  /// 🔹 List of terms only (student-style)
  Widget _buildSyllabusList() {
    return FutureBuilder<List<SyllabusTerm>>(
      future: syllabusFuture,
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
          return const Center(child: Text("No syllabus details found"));
        }

        final terms = snapshot.data!;
        return ListView.builder(
          itemCount: terms.length,
          itemBuilder: (context, index) {
            final term = terms[index];
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
      },
    );
  }

  /// 🔹 Add form
  Widget _buildAddForm() {
    return FutureBuilder<List<SyllabusTerm>>(
      future: syllabusFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final terms = snapshot.data!;

        return Container(
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
            children: [
              Expanded(
                child: ListView(
                  children: [
                    DropdownButtonFormField<int>(
                      decoration: const InputDecoration(
                        labelText: "Select Term",
                        border: OutlineInputBorder(),
                      ),
                      value: selectedSyllabusId,
                      items: terms.map((term) {
                        return DropdownMenuItem(
                          value: term.id,
                          child: Text("${term.term} (${term.academicYear})"),
                        );
                      }).toList(),
                      onChanged: (val) =>
                          setState(() => selectedSyllabusId = val),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: "Title",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: "Description",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: sequenceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Sequence",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _resetForm()),
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Center(
                          child: Text(
                            "Cancel",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        if (selectedSyllabusId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Please select a term"),
                            ),
                          );
                          return;
                        }
                        try {
                          await syllabusService.addSyllabusItem(
                            syllabusId: selectedSyllabusId!,
                            title: titleController.text,
                            description: descriptionController.text,
                            sequence:
                                int.tryParse(sequenceController.text) ?? 0,
                          );
                          setState(() {
                            syllabusFuture = syllabusService.fetchSyllabus(
                              widget.classId,
                              widget.subjectId,
                              widget.academicYear,
                            );
                            _resetForm();
                          });
                        } catch (e) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text("Error: $e")));
                        }
                      },
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF29ABE2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Center(
                          child: Text(
                            "Save",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}
