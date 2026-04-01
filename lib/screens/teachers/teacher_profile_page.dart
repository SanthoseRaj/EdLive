import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import 'package:school_app/config/config.dart';
import 'package:school_app/screens/document_preview_page.dart';

import 'teacher_menu_drawer.dart';
import 'package:school_app/widgets/teacher_app_bar.dart';

import 'package:school_app/services/teacher_profile_service.dart';

class TeacherProfilePage extends StatefulWidget {
  final int staffId; // 👈 pass staffId of logged-in teacher
  const TeacherProfilePage({super.key, required this.staffId});

  @override
  State<TeacherProfilePage> createState() => _TeacherProfilePageState();
}

class _TeacherProfilePageState extends State<TeacherProfilePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  File? _selectedImage;

  final List<String> _tabs = [
    "Basic",
    "Responsibilities",
    "Service",
    "Education",
    "Family",
    "Documents",
  ];

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "";
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('yyyy-MM-dd').format(dt); // 👈 only date part
    } catch (e) {
      return dateStr; // fallback
    }
  }

  Map<String, dynamic>? teacherData;
  bool isLoading = true;
  String? errorMsg;

  String? _buildDocumentUrl(String? rawPath) {
    final trimmed = rawPath?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }

    var normalized = trimmed.replaceAll('\\', '/');
    if (!normalized.startsWith('/')) {
      normalized = '/$normalized';
    }

    if (normalized.startsWith('/content/uploads/') ||
        normalized.startsWith('/uploads/') ||
        normalized.startsWith('/content/')) {
      return AppConfig.absoluteUrl(normalized);
    }

    return AppConfig.absoluteUrl('/content/uploads$normalized');
  }

  String _documentTitle(String? rawPath, {String fallback = 'Document'}) {
    final path = Uri.tryParse(rawPath ?? '')?.path ?? rawPath ?? '';
    final segments = path.split('/').where((segment) => segment.isNotEmpty);
    if (segments.isEmpty) {
      return fallback;
    }
    return segments.last;
  }

  Future<void> _previewDocument(String? rawPath, {String? title}) async {
    final fileUrl = _buildDocumentUrl(rawPath);
    if (fileUrl == null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Cannot open document")));
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentPreviewPage(
          fileUrl: fileUrl,
          title: title ?? _documentTitle(rawPath),
        ),
      ),
    );
  }

  Future<void> _openDocumentExternally(String? rawPath) async {
    final fileUrl = _buildDocumentUrl(rawPath);
    if (fileUrl == null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Cannot open document")));
      return;
    }

    final launched = await launchUrl(
      Uri.parse(fileUrl),
      mode: LaunchMode.externalApplication,
    );

    if (!launched && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Cannot open document")));
    }
  }

  dynamic _documentValue(String? path, {String? title}) {
    final trimmed = path?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return "-";
    }
    return _ProfileDocumentLink(path: trimmed, title: title);
  }

  IconData _documentIcon(String? rawPath) {
    final path = (Uri.tryParse(rawPath ?? '')?.path ?? rawPath ?? '')
        .toLowerCase();
    if (path.endsWith('.pdf')) {
      return Icons.picture_as_pdf;
    }
    if (path.endsWith('.png') ||
        path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.gif') ||
        path.endsWith('.webp') ||
        path.endsWith('.bmp')) {
      return Icons.image_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    fetchTeacherProfile();
  }

  Future<void> _cacheTeacherProfileImage(
    String? imagePath, {
    bool forceRefresh = false,
  }) async {
    if (imagePath == null || imagePath.trim().isEmpty) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final trimmedPath = imagePath.trim();
    final cachedStaffId = prefs.getInt('teacher_profile_staff_id');
    final cachedImagePath = prefs.getString('teacher_profile_image');
    final shouldRefresh =
        forceRefresh ||
        cachedStaffId != widget.staffId ||
        cachedImagePath != trimmedPath;

    await prefs.setInt('teacher_profile_staff_id', widget.staffId);
    await prefs.setString('teacher_profile_image', trimmedPath);

    if (shouldRefresh) {
      await prefs.setInt(
        'teacher_profile_image_version',
        DateTime.now().millisecondsSinceEpoch,
      );
    }
  }

  Future<void> pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    setState(() {
      _selectedImage = File(pickedFile.path);
    });

    try {
      final newImagePath = await TeacherProfileService().updateProfileImage(
        staffId: widget.staffId,
        imageFile: _selectedImage!,
      );

      if (newImagePath != null) {
        await _cacheTeacherProfileImage(newImagePath, forceRefresh: true);
        if (!mounted) return;
        setState(() {
          teacherData?['profile_image'] = newImagePath;
          _selectedImage = null; // clear temporary file
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile image updated successfully")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> fetchTeacherProfile() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) {
        setState(() {
          errorMsg = "No token found. Please login again.";
          isLoading = false;
        });
        return;
      }

      final url = "${AppConfig.baseUrl}/staff/Staff/${widget.staffId}";
      final response = await http.get(
        Uri.parse(url),
        headers: {
          "Authorization": "Bearer $token",
          "Accept": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _cacheTeacherProfileImage(data['profile_image']?.toString());
        setState(() {
          teacherData = data;
          isLoading = false;
        });
      } else {
        setState(() {
          errorMsg = "Failed to fetch staff. (${response.statusCode})";
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMsg = "Error: $e";
        isLoading = false;
      });
    }
  }

  Widget _buildHeaderWithProfile() {
    return Container(
      width: double.infinity,
      color: const Color(0xFF29ABE2),
      padding: const EdgeInsets.only(top: 20, bottom: 16, left: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔙 Back Button
          Padding(
            padding: const EdgeInsets.only(left: 16.0, bottom: 0),
            child: GestureDetector(
              onTap: () {
                Navigator.pop(context);
              },
              child: const Text(
                '< Back',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ),
          ),

          // 👤 Profile Picture & Name Centered
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: _selectedImage != null
                      ? FileImage(_selectedImage!)
                      : (teacherData?['profile_image'] != null &&
                            teacherData!['profile_image'].toString().isNotEmpty)
                      ? NetworkImage(
                          "${AppConfig.serverOrigin}${teacherData!['profile_image']}?v=${DateTime.now().millisecondsSinceEpoch}",
                        )
                      : null,
                  child:
                      (teacherData?['profile_image'] == null ||
                          teacherData!['profile_image'].toString().isEmpty)
                      ? const Icon(Icons.person, size: 70, color: Colors.white)
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: pickAndUploadImage,
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.white,
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.blue,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 🧭 Tab Bar
          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: Colors.deepPurple,
            unselectedLabelColor: Colors.white,
            indicatorColor: Colors.deepPurple,
            tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    if (label.toLowerCase().contains("phone") && value.isNotEmpty) {
      // Make phone numbers clickable
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: RichText(
          text: TextSpan(
            style: const TextStyle(color: Colors.black, fontSize: 14),
            children: [
              TextSpan(
                text: "$label ",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              WidgetSpan(
                child: GestureDetector(
                  onTap: () async {
                    final phoneNumbers = value.split(
                      ',',
                    ); // if multiple numbers
                    final url = Uri.parse('tel:${phoneNumbers[0].trim()}');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url);
                    }
                  },
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else if (label.toLowerCase().contains("email") && value.isNotEmpty) {
      // Make email clickable
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: RichText(
          text: TextSpan(
            style: const TextStyle(color: Colors.black, fontSize: 14),
            children: [
              TextSpan(
                text: "$label ",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              WidgetSpan(
                child: GestureDetector(
                  onTap: () async {
                    final url = Uri.parse('mailto:$value');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url);
                    }
                  },
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Default plain text
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black, fontSize: 14),
          children: [
            TextSpan(
              text: "$label ",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard({
    required String title,
    required Map<String, dynamic> items,
  }) {
    return Card(
      elevation: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          ...items.entries.map((e) => _buildDetailRow(e.key, e.value)).toList(),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, dynamic value) {
    final documentLink = value is _ProfileDocumentLink ? value : null;
    final displayValue = value?.toString() ?? "";

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 3,
            child: documentLink != null
                ? GestureDetector(
                    onTap: () => _previewDocument(
                      documentLink.path,
                      title: documentLink.title,
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.picture_as_pdf, color: Colors.red),
                        SizedBox(width: 6),
                        Text(
                          "View",
                          style: TextStyle(
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  )
                : Text(displayValue.isEmpty ? "-" : displayValue),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    teacherData?['full_name'] ?? "",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    teacherData?['degree'] ?? "",
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 6),
                  _buildInfoRow("ID No:", teacherData?['staff_id_no'] ?? ""),
                  _buildInfoRow("Gender:", teacherData?['gender'] ?? ""),
                  _buildInfoRow(
                    "Phone:",
                    "${teacherData?['phone'] ?? ''}, ${teacherData?['alt_phone'] ?? ''}",
                  ),
                  _buildInfoRow("Email:", teacherData?['email'] ?? ""),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildProfileCard(),
          const SizedBox(height: 16),
          _buildDetailCard(
            title: "Personal Information",
            items: {
              "Date of Birth": _formatDate(teacherData?['dob']),

              "Age": teacherData?['age']?.toString() ?? "",
              "Blood Group": teacherData?['blood_group'] ?? "",
              "Account No.": teacherData?['account_no'] ?? "",
              "PAN": teacherData?['pan_no'] ?? "",
              "Aadhaar No.": teacherData?['aadhaar_no'] ?? "",
            },
          ),
        ],
      ),
    );
  }

  // Your other tabs remain unchanged
  Widget _buildResponsibilitiesTab() {
    final responsibilities =
        teacherData?['classResponsibilities'] as List<dynamic>? ?? [];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSectionHeader("Class Responsibilities"),
          Card(
            elevation: 3,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text("Class")),
                  DataColumn(label: Text("Subject")),
                  DataColumn(label: Text("Mon")),
                  DataColumn(label: Text("Tue")),
                  DataColumn(label: Text("Wed")),
                  DataColumn(label: Text("Thu")),
                  DataColumn(label: Text("Fri")),
                  DataColumn(label: Text("Sat")),
                ],
                rows: responsibilities.map((resp) {
                  return DataRow(
                    cells: [
                      DataCell(Text(resp['class_name'].toString())),
                      DataCell(Text(resp['subject'].toString())),
                      DataCell(Text(resp['monday']?.toString() ?? "-")),
                      DataCell(Text(resp['tuesday']?.toString() ?? "-")),
                      DataCell(Text(resp['wednesday']?.toString() ?? "-")),
                      DataCell(Text(resp['thursday']?.toString() ?? "-")),
                      DataCell(Text(resp['friday']?.toString() ?? "-")),
                      DataCell(Text(resp['saturday']?.toString() ?? "-")),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceTab() {
    final services = teacherData?['service'] as List<dynamic>? ?? [];
    final experience = teacherData?['experience'] as List<dynamic>? ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSectionHeader("Service Information"),
          ...services.map(
            (srv) => _buildDetailCard(
              title: "Service #${srv['id']}",
              items: {
                "Joining Date": _formatDate(srv['joining_date']),
                "Total Leaves": srv['total_leaves'].toString(),
                "Used Leaves": srv['used_leaves'].toString(),
                "PF Number": srv['pf_number'] ?? "",
                "PF Doc": _documentValue(
                  srv['pf_doc']?.toString(),
                  title: "PF Document",
                ),
              },
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionHeader("Experience"),
          ...experience.map(
            (exp) => _buildDetailCard(
              title: exp['organization'] ?? "Experience",
              items: {
                "Designation": exp['designation'] ?? "",
                "From": _formatDate(exp['from_date']),
                "To": _formatDate(exp['to_date']),
                "Docs": _documentValue(
                  exp['exp_docs']?.toString(),
                  title: "Experience Document",
                ),
              },
            ),
          ),
        ],
      ),
    );
  }

  // import 'package:url_launcher/url_launcher.dart';

  Widget _buildEducationTab() {
    final education = teacherData?['education'] as List<dynamic>? ?? [];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSectionHeader("Education History"),
          Card(
            elevation: 3,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text("Degree")),
                  DataColumn(label: Text("University")),
                  DataColumn(label: Text("Year")),
                  DataColumn(label: Text("Certificate")),
                ],
                rows: education.map((edu) {
                  return DataRow(
                    cells: [
                      DataCell(Text(edu['degree'] ?? "")),
                      DataCell(Text(edu['university'] ?? "")),
                      DataCell(Text(edu['year']?.toString() ?? "")),
                      DataCell(
                        (edu['certificate'] != null && edu['certificate'] != "")
                            ? GestureDetector(
                                onTap: () => _previewDocument(
                                  edu['certificate']?.toString(),
                                  title: _documentTitle(
                                    edu['certificate']?.toString(),
                                    fallback: "Certificate",
                                  ),
                                ),
                                child: Row(
                                  children: const [
                                    Icon(
                                      Icons.picture_as_pdf,
                                      color: Colors.red,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      "View",
                                      style: TextStyle(color: Colors.blue),
                                    ),
                                  ],
                                ),
                              )
                            : const Text("-"),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFamilyTab() {
    final family = teacherData?['family'] as List<dynamic>? ?? [];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildDetailCard(
            title: "Address Information",
            items: {
              "Current Address": teacherData?['current_address'] ?? "",
              "Permanent Address": teacherData?['permanent_address'] ?? "",
            },
          ),
          const SizedBox(height: 16),
          _buildSectionHeader("Family Members"),
          ...family.map(
            (fam) => _buildDetailCard(
              title: fam['family_name'] ?? "Family Member",
              items: {
                "Relation": fam['relation'] ?? "",
                "Contact": fam['family_contact'] ?? "",
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsTab() {
    final documents = teacherData?['documents'] as List<dynamic>? ?? [];
    if (documents.isEmpty) {
      return const Center(child: Text("No documents uploaded."));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: documents.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final doc = documents[index] as Map<String, dynamic>;
        final rawPath = doc['document_path']?.toString();
        final docTitle = doc['document_name']?.toString().trim();
        final displayTitle = docTitle != null && docTitle.isNotEmpty
            ? docTitle
            : _documentTitle(rawPath);

        return Card(
          elevation: 2,
          child: ListTile(
            onTap: () => _previewDocument(rawPath, title: displayTitle),
            leading: Icon(_documentIcon(rawPath), color: Colors.blue),
            title: Text(
              displayTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              rawPath?.trim().isNotEmpty == true
                  ? rawPath!.trim()
                  : "Tap to preview",
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              icon: const Icon(Icons.open_in_new),
              onPressed: () => _openDocumentExternally(rawPath),
              tooltip: "Open externally",
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (errorMsg != null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: Text(errorMsg!)),
      );
    }

    return Column(
      children: [
        Expanded(
          child: Scaffold(
            backgroundColor: const Color(0xFF29ABE2),
            drawer: const MenuDrawer(),
            appBar: TeacherAppBar(),
            body: Column(
              children: [
                _buildHeaderWithProfile(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildBasicTab(),
                      _buildResponsibilitiesTab(),
                      _buildServiceTab(),
                      _buildEducationTab(),
                      _buildFamilyTab(),
                      _buildDocumentsTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileDocumentLink {
  final String path;
  final String? title;

  const _ProfileDocumentLink({required this.path, this.title});
}
