import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:school_app/screens/teachers/teacher_menu_drawer.dart';
import 'package:school_app/widgets/teacher_app_bar.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/teacher_resource_class_model.dart';
import '../../models/teacher_resource_model.dart';
import '../../models/teacher_resource_subject_model.dart';
import '../../services/teacher_resource_classsection_service.dart';
import '../../services/teacher_resource_service.dart';
import '../../services/teacher_resource_subject_service.dart';
import 'teacher_resource_addpage.dart';

class TeacherResourcePage extends StatefulWidget {
  const TeacherResourcePage({super.key});

  @override
  State<TeacherResourcePage> createState() => _TeacherResourcePageState();
}

class _TeacherResourcePageState extends State<TeacherResourcePage> {
  TeacherClassModel? selectedClass;
  TeacherSubjectModel? selectedSubject;

  List<TeacherClassModel> classList = [];
  List<TeacherSubjectModel> subjectList = [];
  List<TeacherResourceModel> resources = [];

  bool isClassLoading = true;
  bool isSubjectLoading = true;
  bool isResourceLoading = true;

  TeacherResourceModel? selectedResource;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    List<TeacherClassModel> fetchedClasses = [];
    List<TeacherSubjectModel> fetchedSubjects = [];

    try {
      fetchedClasses = await TeacherResourceService.fetchTeacherClasses();
    } catch (e) {
      debugPrint("Error fetching classes: $e");
    }

    try {
      fetchedSubjects = await SubjectResourceService.fetchTeacherSubjects();
    } catch (e) {
      debugPrint("Error fetching subjects: $e");
    }

    if (!mounted) return;

    setState(() {
      classList = fetchedClasses;
      subjectList = fetchedSubjects;
      selectedClass = fetchedClasses.isNotEmpty ? fetchedClasses.first : null;
      selectedSubject = fetchedSubjects.isNotEmpty
          ? fetchedSubjects.first
          : null;
      isClassLoading = false;
      isSubjectLoading = false;
    });

    await loadResources();
  }

  Future<void> _openAddPage() async {
    final result = await Navigator.push<TeacherResourceAddResult>(
      context,
      MaterialPageRoute(
        builder: (_) => TeacherResourceAddPage(
          initialClassId: selectedClass?.classId,
          initialSubjectId: selectedSubject?.subjectId,
        ),
      ),
    );

    if (result?.didAdd != true || !mounted) return;

    setState(() {
      if (result?.classId != null) {
        selectedClass = classList.cast<TeacherClassModel?>().firstWhere(
          (cls) => cls?.classId == result!.classId,
          orElse: () => selectedClass,
        );
      }

      if (result?.subjectId != null) {
        selectedSubject = subjectList.cast<TeacherSubjectModel?>().firstWhere(
          (subj) => subj?.subjectId == result!.subjectId,
          orElse: () => selectedSubject,
        );
      }

      selectedResource = null;
      isResourceLoading = true;
    });

    await loadResources();
  }

  Future<void> loadResources() async {
    if (selectedClass == null || selectedSubject == null) {
      if (!mounted) return;
      setState(() {
        resources = [];
        isResourceLoading = false;
      });
      return;
    }

    try {
      final res = await TeacherResourceMainService.fetchResources(
        classId: selectedClass!.classId,
        subjectId: selectedSubject!.subjectId,
      );

      if (!mounted) return;
      setState(() {
        resources = res;
        isResourceLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isResourceLoading = false);
      debugPrint("Error fetching resources: $e");
    }
  }

  Uri? _buildResourceUri(String rawLink) {
    final trimmed = rawLink.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final normalized =
        trimmed.startsWith('http://') || trimmed.startsWith('https://')
        ? trimmed
        : 'https://$trimmed';

    return Uri.tryParse(normalized);
  }

  Future<void> _openResourceLink(String rawLink) async {
    final uri = _buildResourceUri(rawLink);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Cannot open link")));
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!launched && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Cannot open link")));
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color backgroundColor = Color(0xFFD3C4D6);
    const Color headerTextColor = Color(0xFF2D3E9A);

    return WillPopScope(
      onWillPop: () async {
        if (selectedResource != null) {
          setState(() {
            selectedResource = null; // go back to list view
          });
          return false; // ❌ prevent page pop
        }
        return true; // ✅ allow normal back (dashboard)
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: TeacherAppBar(),
        drawer: MenuDrawer(),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Text(
                            '< Back',
                            style: TextStyle(color: Colors.black, fontSize: 14),
                          ),
                        ),
                        GestureDetector(
                          onTap: _openAddPage,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 7,
                              horizontal: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF29ABE2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.add, color: Colors.white),
                                SizedBox(width: 4),
                                Text(
                                  "Add",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFF2E3192),
                          ),
                          child: SvgPicture.asset(
                            'assets/icons/resources.svg',
                            height: 20,
                            width: 20,
                            colorFilter: const ColorFilter.mode(
                              Colors.white,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Resources',
                          style: TextStyle(
                            color: headerTextColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 28,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    padding: selectedResource == null
                        ? const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 16,
                          )
                        : const EdgeInsets.only(
                            left: 13,
                            right: 13,
                            top: 16,
                            bottom: 16,
                          ),
                    child: selectedResource == null
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Select Class',
                                          style: TextStyle(fontSize: 14),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                          ),
                                          height: 40,
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: Colors.grey,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: isClassLoading
                                              ? const Center(
                                                  child: SizedBox(
                                                    height: 16,
                                                    width: 16,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                        ),
                                                  ),
                                                )
                                              : DropdownButton<
                                                  TeacherClassModel
                                                >(
                                                  value: selectedClass,
                                                  isExpanded: true,
                                                  underline: const SizedBox(),
                                                  items: classList.map((cls) {
                                                    return DropdownMenuItem(
                                                      value: cls,
                                                      child: Text(
                                                        cls.className,
                                                        style: const TextStyle(
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                    );
                                                  }).toList(),
                                                  onChanged: (val) async {
                                                    if (val == null) return;
                                                    setState(() {
                                                      selectedClass = val;
                                                      selectedResource = null;
                                                      isResourceLoading = true;
                                                    });
                                                    await loadResources();
                                                  },
                                                ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 32),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Select Subject',
                                          style: TextStyle(fontSize: 14),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                          ),
                                          height: 40,
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: Colors.grey,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: isSubjectLoading
                                              ? const Center(
                                                  child: SizedBox(
                                                    height: 16,
                                                    width: 16,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                        ),
                                                  ),
                                                )
                                              : DropdownButton<
                                                  TeacherSubjectModel
                                                >(
                                                  value: selectedSubject,
                                                  isExpanded: true,
                                                  underline: const SizedBox(),
                                                  items: subjectList.map((
                                                    subj,
                                                  ) {
                                                    return DropdownMenuItem(
                                                      value: subj,
                                                      child: Text(
                                                        subj.subjectName,
                                                        style: const TextStyle(
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                    );
                                                  }).toList(),
                                                  onChanged: (val) async {
                                                    if (val == null) return;
                                                    setState(() {
                                                      selectedSubject = val;
                                                      selectedResource = null;
                                                      isResourceLoading = true;
                                                    });
                                                    await loadResources();
                                                  },
                                                ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Expanded(child: _buildResourceListView()),
                            ],
                          )
                        : _buildResourceDetailView(selectedResource!),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResourceListView() {
    if (isResourceLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (resources.isEmpty) {
      return const Center(child: Text("No resources available"));
    }

    return SingleChildScrollView(
      key: const PageStorageKey('resourceList'), // 👈 ADD THIS
      controller: _scrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: resources.map((res) {
          return _buildResourceItem(
            title: res.title,
            description: res.description,
            linkText: res.webLinks.isNotEmpty ? res.webLinks.first : "",
            onTap: () {
              if (res.webLinks.isEmpty) return;
              _openResourceLink(res.webLinks.first);
            },
            onDetailsTap: () {
              setState(() {
                selectedResource = res;
              });
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildResourceDetailView(TeacherResourceModel res) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(left: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF2E3192)),
                  onPressed: () {
                    setState(() {
                      selectedResource = null;
                    });
                  },
                ),
                Expanded(
                  child: Text(
                    res.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E3192),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              res.description,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                height: 1.8,
              ),
            ),
            const SizedBox(height: 20),
            if (res.webLinks.isNotEmpty) ...[
              const Text(
                "Links:",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: res.webLinks.map((link) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GestureDetector(
                      onTap: () {
                        _openResourceLink(link);
                      },
                      child: Text(
                        link,
                        style: const TextStyle(
                          color: Colors.blue,
                          decoration: TextDecoration.none,
                          height: 1.6,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResourceItem({
    required String title,
    required String description,
    required String linkText,
    required VoidCallback onTap,
    required VoidCallback onDetailsTap,
  }) {
    return Container(
      padding: const EdgeInsets.only(bottom: 12, top: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey, width: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E3192),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: onTap,
                  child: Text(
                    linkText,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.blue,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, size: 18),
            onPressed: onDetailsTap,
          ),
        ],
      ),
    );
  }
}
