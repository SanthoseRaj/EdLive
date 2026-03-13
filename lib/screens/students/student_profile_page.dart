  import 'dart:convert';
  import 'package:flutter/material.dart';
  import 'package:http/http.dart' as http;
  import 'package:shared_preferences/shared_preferences.dart';
  import 'package:flutter_svg/flutter_svg.dart';
  import 'package:image_picker/image_picker.dart';
  import 'package:cached_network_image/cached_network_image.dart';

  import 'dart:io';
  import 'dart:io' show File; // <-- needed for Image.file on mobile/desktop


  import 'package:school_app/widgets/student_app_bar.dart';
  import 'package:school_app/screens/students/student_menu_drawer.dart';

  import 'package:school_app/services/student_profile_img_change.dart';

  class StudentProfilePage extends StatefulWidget {
    final int studentId;
    const StudentProfilePage({super.key, required this.studentId});

    @override
    State<StudentProfilePage> createState() => _StudentProfilePageState();
  }

  class _StudentProfilePageState extends State<StudentProfilePage> {
    bool loading = true;
    Map<String, dynamic>? data;


    final uploader = StudentProfileImageUploader();


    @override
    void initState() {
      super.initState();
      _load();
    }

    Future<void> _load() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('auth_token') ?? '';

        final url = Uri.parse(
          'https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api/student/students/${widget.studentId}',
        );
        final res = await http.get(url, headers: {
          'Authorization': 'Bearer $token',
          'accept': '*/*',
        });

        if (res.statusCode == 200) {
          setState(() {
            data = jsonDecode(res.body);
            loading = false;
          });
        } else {
          throw Exception('status ${res.statusCode}');
        }
      } catch (e) {
        debugPrint('❌ $e');
        setState(() => loading = false);
      }
    }

    // ---------- helpers ----------
    Widget _info(String k, String? v) => _row(k, v ?? 'N/A');
    Widget _row(String k, String v) {
      final blue = k.toLowerCase().contains('mobile') || k.toLowerCase().contains('email');
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$k ',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Color(0xFF4D4D4D))),
            Expanded(
              child: Text(
                v,
                style: TextStyle(
                  color: blue ? const Color(0xFF29ABE2) : const Color(0xFF4D4D4D),
                ),
              ),
            ),
          ],
        ),
      );
    }

  final String _imgBase = 'http://schoolmanagement.canadacentral.cloudapp.azure.com:443';


  Widget _networkImage(String? imageUrl, {double size = 120}) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return _placeholderImage(size);
    }

    final String imgBase = 'http://schoolmanagement.canadacentral.cloudapp.azure.com:443';
    String fullUrl;

    if (imageUrl.startsWith('/data/user/') || imageUrl.startsWith('C:')) {
      return ClipOval(
        child: Image.file(
          File(imageUrl),
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }

    if (imageUrl.startsWith('/')) {
      fullUrl = '$imgBase$imageUrl';
    } else if (imageUrl.startsWith('http')) {
      fullUrl = imageUrl;
    } else {
      fullUrl = '$imgBase/$imageUrl';
    }

    debugPrint('🖼️ Loading image from: $fullUrl');

    // 🔥 Add random query to break cache
    final noCacheUrl = '$fullUrl?ts=${DateTime.now().millisecondsSinceEpoch}';

    return ClipOval(
    child: CachedNetworkImage(
      imageUrl: fullUrl,
      width: size,
      height: size,
      fit: BoxFit.cover,
      placeholder: (_, __) => const CircularProgressIndicator(),
      errorWidget: (_, __, ___) => _placeholderImage(size),
    ),
  );
  }

  
  
    Widget _placeholderImage(double size) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.person, size: 50, color: Colors.white),
      );
    }

    @override
    Widget build(BuildContext context) {
      if (loading) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (data == null) {
        return const Scaffold(body: Center(child: Text('Error loading student')));
      }

      final basic = data!['basic_info'] ?? {};
      final school = data!['school_info'] ?? {};
      final parent = data!['parent'] ?? {};
      final health = data!['health'] ?? {};
      final caste = data!['caste_religion'] ?? {};
  final imgBase = 'http://schoolmanagement.canadacentral.cloudapp.azure.com:443';


      return DefaultTabController(
        length: 3,
        child: Scaffold(
          drawer: const StudentMenuDrawer(),
          appBar: StudentAppBar(
            onProfileTap: () => Navigator.pop(context),
          ),
          body: Column(
            children: [
              // ----- header -----
              Container(
                width: double.infinity,
                color: const Color(0xFF2E99EF),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text('< Back',
                          style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                    const SizedBox(height: 6),
  Center(
    child: Column(
      children: [

  GestureDetector(
    onTap: () => uploader.pickImage(
      widget.studentId,
      onSuccess: () => _load(),
      onError: () => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image upload failed')),
      ),
    ),
    child: _networkImage(uploader.selectedImage?.path ?? data!['profile_img']),
  ),

  
  
  const SizedBox(height: 6),
        Text(
          data!['full_name'] ?? '',
          style: const TextStyle(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.w600),
        ),
      ],
    ),
  ),
    ],
                ),
              ),

              // ----- tabs -----
              const TabBar(
                labelColor: Color(0xFF29ABE2),
                unselectedLabelColor: Colors.black54,
                indicatorColor: Color(0xFF29ABE2),
                labelStyle: TextStyle(fontWeight: FontWeight.bold),
                tabs: [
                  Tab(text: 'Basic Info'),
                  Tab(text: 'Parent/Guardian'),
                  Tab(text: 'Documents'),
                ],
              ),

              // ----- tab views -----
              Expanded(
                child: TabBarView(
                  children: [
                    // ---------- Basic ----------
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _info('Gender : ', basic['gender']),
                          _info('DOB : ', basic['date_of_birth']?.split('T').first),
                          _info('Blood Group : ', basic['blood_group']),
                          _info('Contact : ', basic['contact_number']),
                          const SizedBox(height: 16),
                          const Divider(),
                          const Text('School Info',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          _info('Admission No : ', data!['admission_no']),
                          _info('Class Joined : ', school['class_joined']),
                          _info('Class Teacher : ', school['class_teacher']),
                          _info('Previous School : ', school['prev_school']),
                          const SizedBox(height: 16),
                          const Divider(),
                          const Text('Health',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          _info('Disability : ', health['disability'] == true ? 'Yes' : 'No'),
                          _info('Disability Details : ', health['disability_details']),
                          _info('Disease : ', health['disease'] == true ? 'Yes' : 'No'),
                          _info('Disease Details : ', health['disease_details']),
                          const SizedBox(height: 16),
                          const Divider(),
                          const Text('Caste & Religion',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          _info('Caste : ', caste['caste']),
                          _info('Religion : ', caste['religion']),
                        ],
                      ),
                    ),

                    // ---------- Parent ----------
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _parentCard(
                              parent['father_name'],
                              'Father',
                              parent['father_img'] != null
                                  ? '$imgBase${parent['father_img']}'
                                  : null,
                              parent),
                          _parentCard(
                              parent['mother_name'],
                              'Mother',
                              parent['mother_img'] != null
                                  ? '$imgBase${parent['mother_img']}'
                                  : null,
                              parent),
                        ],
                      ),
                    ),

                    // ---------- Documents ----------
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _info('Student ID / Passport', data!['student_id']),
                          const SizedBox(height: 24),
                          _info('Admission No', data!['admission_no']),
                        ],
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

    // ----- Parent card -----
    Widget _parentCard(String? name, String role, String? imageUrl, Map parent) {
      if (name == null) return const SizedBox.shrink();
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.fromLTRB(8, 20, 8, 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
                color: role == 'Father' ? Colors.grey : Colors.transparent),
          ),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 24),
                _networkImage(imageUrl, size: 110),
                const SizedBox(height: 10),
                Text(name,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2E3192))),
                Text('($role)',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 12),
                _info('Mobile',
                    role == 'Father' ? parent['father_contact'] : parent['mother_contact']),
                _info('Email',
                    role == 'Father' ? parent['father_email'] : parent['mother_email']),
              ],
            ),

            // edit icon
            Positioned(
              top: 0,
              right: 0,
              child: GestureDetector(
                onTap: () => debugPrint('Edit $role'),
                child: SvgPicture.asset(
                  'assets/icons/pencil.svg',
                  height: 20,
                  width: 20,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }
