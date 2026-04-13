import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:school_app/config/config.dart';
import 'package:school_app/screens/students/student_menu_drawer.dart';
import 'package:school_app/screens/teachers/teacher_menu_drawer.dart';
import 'package:school_app/services/student_profile_img_change.dart';
import 'package:school_app/widgets/student_app_bar.dart';
import 'package:school_app/widgets/teacher_app_bar.dart';

class StudentProfilePage extends StatefulWidget {
  final int studentId;
  final bool isTeacherView;

  const StudentProfilePage({
    super.key,
    required this.studentId,
    this.isTeacherView = false,
  });

  @override
  State<StudentProfilePage> createState() => _StudentProfilePageState();
}

class _StudentProfilePageState extends State<StudentProfilePage> {
  final uploader = StudentProfileImageUploader();

  bool loading = true;
  bool _isUploading = false;
  int _appBarRefreshToken = 0;
  int _profileImageRefreshToken = 0;
  Map<String, dynamic>? data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';

      final response = await http.get(
        AppConfig.apiUri('/student/students/${widget.studentId}'),
        headers: {'Authorization': 'Bearer $token', 'accept': '*/*'},
      );

      if (response.statusCode != 200) {
        throw Exception('status ${response.statusCode}');
      }

      if (!mounted) {
        return;
      }

      final profileData = jsonDecode(response.body) as Map<String, dynamic>;
      _applyProfileImagePath(
        profileData,
        _extractProfileImagePath(profileData),
      );
      await _syncSelectedChildProfile(profileData);

      setState(() {
        data = profileData;
        loading = false;
      });
    } catch (e) {
      debugPrint('Failed to load student profile: $e');
      if (!mounted) {
        return;
      }
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> _launchActionUri(Uri uri, String errorMessage) async {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!launched && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage)));
    }
  }

  void _openPhone(String value) {
    final phoneNumber = value.split(',').first.trim();
    if (phoneNumber.isEmpty || phoneNumber.toLowerCase() == 'n/a') {
      return;
    }

    _launchActionUri(Uri.parse('tel:$phoneNumber'), 'Could not open phone app');
  }

  void _openEmail(String value) {
    final email = value.trim();
    if (email.isEmpty || email.toLowerCase() == 'n/a') {
      return;
    }

    _launchActionUri(
      Uri(scheme: 'mailto', path: email),
      'Could not open email app',
    );
  }

  Widget _info(String key, String? value) => _row(key, value ?? 'N/A');

  Widget _row(String key, String value) {
    final lowerKey = key.toLowerCase();
    final isPhone = lowerKey.contains('mobile') || lowerKey.contains('contact');
    final isEmail = lowerKey.contains('email');
    final isActionable =
        (isPhone || isEmail) &&
        value.trim().isNotEmpty &&
        value.trim().toLowerCase() != 'n/a';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$key ',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF4D4D4D),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: !isActionable
                  ? null
                  : () {
                      if (isPhone) {
                        _openPhone(value);
                        return;
                      }
                      _openEmail(value);
                    },
              child: Text(
                value,
                style: TextStyle(
                  color: isActionable
                      ? const Color(0xFF29ABE2)
                      : const Color(0xFF4D4D4D),
                  decoration: isActionable
                      ? TextDecoration.underline
                      : TextDecoration.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _networkImage(
    String? imageUrl, {
    double size = 120,
    int cacheBustToken = 0,
  }) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return _placeholderImage(size);
    }

    final fullUrl = AppConfig.absoluteUrl(imageUrl);
    final imageUrlWithCacheToken = cacheBustToken > 0
        ? '$fullUrl${fullUrl.contains('?') ? '&' : '?'}ts=$cacheBustToken'
        : fullUrl;

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: imageUrlWithCacheToken,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, progress) =>
            const Center(child: CircularProgressIndicator()),
        errorWidget: (_, url, error) => _placeholderImage(size),
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

  Future<void> _syncSelectedChildProfile(
    Map<String, dynamic> profileData, {
    String? overrideProfilePath,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final childString = prefs.getString('selected_child');
    if (childString == null || childString.isEmpty) {
      return;
    }

    try {
      final selectedChild = jsonDecode(childString) as Map<String, dynamic>;
      if (selectedChild['id']?.toString() != widget.studentId.toString()) {
        return;
      }

      final currentProfilePath =
          selectedChild['profile_img']?.toString() ??
          selectedChild['profileImage']?.toString() ??
          selectedChild['profile_image']?.toString() ??
          selectedChild['image']?.toString();

      final nextProfilePath =
          overrideProfilePath ??
          profileData['profile_img']?.toString() ??
          profileData['profileImage']?.toString() ??
          profileData['profile_image']?.toString() ??
          profileData['image']?.toString();
      final normalizedCurrentPath = currentProfilePath?.trim() ?? '';
      final normalizedNextPath = nextProfilePath?.trim() ?? '';
      final shouldRefreshHeaderImage =
          overrideProfilePath != null ||
          (normalizedNextPath.isNotEmpty &&
              normalizedNextPath != normalizedCurrentPath);

      if (nextProfilePath != null && nextProfilePath.trim().isNotEmpty) {
        selectedChild['profile_img'] = nextProfilePath;
        selectedChild['profileImage'] = nextProfilePath;
        selectedChild['profile_image'] = nextProfilePath;
        selectedChild['image'] = AppConfig.absoluteUrl(nextProfilePath);
      }

      selectedChild['name'] =
          profileData['full_name']?.toString() ??
          selectedChild['name']?.toString() ??
          '';

      await prefs.setString('selected_child', jsonEncode(selectedChild));

      if (normalizedNextPath.isNotEmpty) {
        await prefs.setInt('student_profile_student_id', widget.studentId);
      }

      if (shouldRefreshHeaderImage) {
        await prefs.setInt(
          'student_profile_image_version',
          DateTime.now().millisecondsSinceEpoch,
        );
      }
    } catch (_) {}
  }

  Widget _buildEditableProfileImage() {
    final profileImagePath = _extractProfileImagePath(data!);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        _networkImage(
          profileImagePath,
          cacheBustToken: _profileImageRefreshToken,
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: GestureDetector(
            onTap: _isUploading ? null : _pickAndUploadImage,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF2E99EF), width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: _isUploading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF2E99EF),
                        ),
                      )
                    : const Icon(
                        Icons.camera_alt,
                        color: Color(0xFF2E99EF),
                        size: 18,
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickAndUploadImage() async {
    if (_isUploading) {
      return;
    }

    try {
      final imageSelected = await uploader.selectImage();
      if (!imageSelected || !mounted) {
        return;
      }

      setState(() {
        _isUploading = true;
      });

      final uploadedPath = await uploader.uploadImage(widget.studentId);
      if (!mounted) {
        return;
      }

      if (uploadedPath != null && uploadedPath.trim().isNotEmpty) {
        _applyProfileImagePath(data, uploadedPath);
        await _syncSelectedChildProfile(
          data!,
          overrideProfilePath: uploadedPath,
        );
        if (mounted) {
          setState(() {
            _appBarRefreshToken = DateTime.now().millisecondsSinceEpoch;
            _profileImageRefreshToken = _appBarRefreshToken;
          });
        }
      }

      await _load();
      if (mounted) {
        setState(() {
          _appBarRefreshToken = DateTime.now().millisecondsSinceEpoch;
          _profileImageRefreshToken = _appBarRefreshToken;
        });
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile image updated successfully')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      uploader.clearSelection();
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  String? _extractProfileImagePath(Map<String, dynamic> source) {
    for (final key in const [
      'profile_img',
      'profileImage',
      'profile_image',
      'image',
    ]) {
      final value = source[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    return null;
  }

  void _applyProfileImagePath(
    Map<String, dynamic>? target,
    String? profileImagePath,
  ) {
    if (target == null ||
        profileImagePath == null ||
        profileImagePath.isEmpty) {
      return;
    }

    target['profile_img'] = profileImagePath;
    target['profileImage'] = profileImagePath;
    target['profile_image'] = profileImagePath;
    target['image'] = profileImagePath;
  }

  String? _dateOnly(dynamic value) {
    final rawValue = value?.toString();
    if (rawValue == null || rawValue.isEmpty) {
      return null;
    }
    return rawValue.split('T').first;
  }

  Widget _buildProfileHeaderImage() {
    final profileImagePath = _extractProfileImagePath(data!);
    if (widget.isTeacherView) {
      return _networkImage(profileImagePath);
    }
    return _buildEditableProfileImage();
  }

  Widget _buildBasicInfoTab() {
    final basic = data!['basic_info'] ?? {};
    final school = data!['school_info'] ?? {};
    final health = data!['health'] ?? {};
    final caste = data!['caste_religion'] ?? {};

    if (widget.isTeacherView) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _info('Gender:', basic['gender']?.toString()),
            _info('DOB:', _dateOnly(basic['date_of_birth'])),
            _info('Blood Group:', basic['blood_group']?.toString()),
            _info('Contact:', basic['contact_number']?.toString()),
            const SizedBox(height: 16),
            const Divider(),
            const Text(
              'School Info',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            _info('Admission Date:', _dateOnly(school['admission_date'])),
            _info('Class Joined:', school['class_joined']?.toString()),
            _info('Previous School:', school['prev_school']?.toString()),
            _info('Class Teacher:', school['class_teacher']?.toString()),
            const SizedBox(height: 16),
            const Divider(),
            const Text(
              'Health Details',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            _info('Disability:', health['disability'] == true ? 'Yes' : 'No'),
            _info(
              'Disability Details:',
              health['disability_details']?.toString(),
            ),
            _info('Disease:', health['disease'] == true ? 'Yes' : 'No'),
            _info('Disease Details:', health['disease_details']?.toString()),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _info('Gender:', basic['gender']?.toString()),
          _info('DOB:', _dateOnly(basic['date_of_birth'])),
          _info('Blood Group:', basic['blood_group']?.toString()),
          _info('Contact:', basic['contact_number']?.toString()),
          const SizedBox(height: 16),
          const Divider(),
          const Text(
            'School Info',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          _info('Admission No:', data!['admission_no']?.toString()),
          _info('Class Joined:', school['class_joined']?.toString()),
          _info('Class Teacher:', school['class_teacher']?.toString()),
          _info('Previous School:', school['prev_school']?.toString()),
          const SizedBox(height: 16),
          const Divider(),
          const Text(
            'Health',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          _info('Disability:', health['disability'] == true ? 'Yes' : 'No'),
          _info(
            'Disability Details:',
            health['disability_details']?.toString(),
          ),
          _info('Disease:', health['disease'] == true ? 'Yes' : 'No'),
          _info('Disease Details:', health['disease_details']?.toString()),
          const SizedBox(height: 16),
          const Divider(),
          const Text(
            'Caste & Religion',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          _info('Caste:', caste['caste']?.toString()),
          _info('Religion:', caste['religion']?.toString()),
        ],
      ),
    );
  }

  Widget _buildParentTab() {
    final parent = data!['parent'] ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _parentCard(
            parent['father_name']?.toString(),
            'Father',
            parent['father_img']?.toString(),
            parent,
          ),
          _parentCard(
            parent['mother_name']?.toString(),
            'Mother',
            parent['mother_img']?.toString(),
            parent,
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsTab() {
    if (widget.isTeacherView) {
      return const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 24),
            Text(
              'Student ID/Passport',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text(
              'No: 45675789790898',
              style: TextStyle(color: Color(0xFF29ABE2)),
            ),
            SizedBox(height: 24),
            Text(
              'Parent ID/Passport',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text(
              'No: 45675789790898',
              style: TextStyle(color: Color(0xFF29ABE2)),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _info('Student ID / Passport', data!['student_id']?.toString()),
          const SizedBox(height: 24),
          _info('Admission No', data!['admission_no']?.toString()),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (data == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: Text('Error loading student')),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        drawer: widget.isTeacherView
            ? const MenuDrawer()
            : const StudentMenuDrawer(),
        appBar: widget.isTeacherView
            ? const TeacherAppBar()
            : StudentAppBar(
                onProfileTap: () => Navigator.pop(context),
                refreshToken: _appBarRefreshToken,
              ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              color: const Color(0xFF2E99EF),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text(
                      '< Back',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Column(
                      children: [
                        _buildProfileHeaderImage(),
                        const SizedBox(height: 6),
                        Text(
                          data!['full_name']?.toString() ?? '',
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
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
            Expanded(
              child: TabBarView(
                children: [
                  _buildBasicInfoTab(),
                  _buildParentTab(),
                  _buildDocumentsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _parentCard(
    String? name,
    String role,
    String? imageUrl,
    Map<String, dynamic> parent,
  ) {
    if (name == null) {
      return const SizedBox.shrink();
    }

    final isFather = role == 'Father';
    final age = isFather
        ? parent['father_age']?.toString()
        : parent['mother_age']?.toString();
    final occupation = isFather
        ? parent['father_occupation']?.toString()
        : parent['mother_occupation']?.toString();
    final mobile = isFather
        ? parent['father_contact']?.toString()
        : parent['mother_contact']?.toString();
    final email = isFather
        ? parent['father_email']?.toString()
        : parent['mother_email']?.toString();
    final address = isFather
        ? parent['father_address']?.toString()
        : parent['mother_address']?.toString();

    if (widget.isTeacherView) {
      return Container(
        padding: const EdgeInsets.fromLTRB(8, 20, 8, 16),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const CircleAvatar(
              radius: 50,
              backgroundColor: Colors.grey,
              child: Icon(Icons.person, color: Colors.white, size: 60),
            ),
            const SizedBox(height: 10),
            Text(
              name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E3192),
              ),
            ),
            Text(
              '($role)',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            _info('Age:', age),
            _info('Occupation:', occupation),
            _info('Mobile:', mobile),
            _info('Email:', email),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Address',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(address ?? 'N/A'),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(8, 20, 8, 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: role == 'Father' ? Colors.grey : Colors.transparent,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 24),
          _networkImage(imageUrl, size: 110),
          const SizedBox(height: 10),
          Text(
            name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2E3192),
            ),
          ),
          Text(
            '($role)',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          _info('Mobile', mobile),
          _info('Email', email),
        ],
      ),
    );
  }
}
