import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:school_app/config/config.dart';
import 'package:school_app/screens/students/student_notifiction_page.dart';
import 'package:school_app/screens/students/student_profile_page.dart';

class StudentService {
  static String get baseUrl => AppConfig.baseUrl;

  static Future<String?> getProfileImage(int studentId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.get(
        AppConfig.apiUri('/student/students/$studentId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final profileImagePath = _extractProfileImagePath(data);
        if (profileImagePath != null && profileImagePath.isNotEmpty) {
          return AppConfig.absoluteUrl(profileImagePath);
        }
      }
    } catch (_) {}

    return null;
  }

  static String? _extractProfileImagePath(dynamic data) {
    if (data is! Map) {
      return null;
    }

    for (final key in const [
      'profile_img',
      'profileImage',
      'profile_image',
      'image',
    ]) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    return null;
  }

  static Future<int?> getLoggedInStudentId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('student_id');
  }
}

class StudentAppBar extends StatefulWidget implements PreferredSizeWidget {
  final VoidCallback? onMenuPressed;
  final VoidCallback? onProfileTap;
  final Object? refreshToken;

  const StudentAppBar({
    super.key,
    this.onMenuPressed,
    this.onProfileTap,
    this.refreshToken,
  });

  @override
  State<StudentAppBar> createState() => _StudentAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(63);
}

class _StudentAppBarState extends State<StudentAppBar> {
  late Future<_StudentHeaderData> _headerDataFuture;

  @override
  void initState() {
    super.initState();
    _headerDataFuture = _getHeaderData();
  }

  @override
  void didUpdateWidget(covariant StudentAppBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.refreshToken != widget.refreshToken) {
      _refreshHeaderData();
    }
  }

  void _refreshHeaderData() {
    if (!mounted) {
      return;
    }

    setState(() {
      _headerDataFuture = _getHeaderData();
    });
  }

  Widget _buildProfileAvatar(String? imageUrl) {
    final normalizedUrl = imageUrl?.trim();
    final hasImage = normalizedUrl != null && normalizedUrl.isNotEmpty;

    return SizedBox(
      width: 36,
      height: 36,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Icon(Icons.account_circle, color: Colors.black54, size: 30),
          if (hasImage)
            Positioned.fill(
              child: ClipOval(
                child: Image.network(
                  normalizedUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PreferredSize(
      preferredSize: widget.preferredSize,
      child: FutureBuilder<_StudentHeaderData>(
        future: _headerDataFuture,
        builder: (context, snapshot) {
          final headerData = snapshot.data ?? const _StudentHeaderData();
          final studentId = headerData.studentId;
          final profileImgUrl = headerData.profileImageUrl;

          return AppBar(
            backgroundColor: Colors.white,
            automaticallyImplyLeading: false,
            leading: Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu, color: Colors.black),
                onPressed:
                    widget.onMenuPressed ??
                    () => Scaffold.of(context).openDrawer(),
              ),
            ),
            title: Row(
              children: [
                const Text(
                  'Ed',
                  style: TextStyle(
                    color: Colors.indigo,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
                const Text(
                  'Live',
                  style: TextStyle(
                    color: Colors.lightBlue,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const StudentNotificationPage(),
                      ),
                    );
                  },
                  child: SvgPicture.asset(
                    'assets/icons/notification.svg',
                    height: 24,
                    width: 24,
                    colorFilter: const ColorFilter.mode(
                      Colors.black,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () async {
                    if (widget.onProfileTap != null) {
                      widget.onProfileTap!();
                      return;
                    }

                    if (studentId == null) {
                      return;
                    }

                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            StudentProfilePage(studentId: studentId),
                      ),
                    );

                    _refreshHeaderData();
                  },
                  child: _buildProfileAvatar(profileImgUrl),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<_StudentHeaderData> _getHeaderData() async {
    final prefs = await SharedPreferences.getInstance();
    final childData = _readUserData(prefs.getString('selected_child'));
    final studentId =
        _extractPositiveInt(childData?['id']) ?? prefs.getInt('student_id');
    var profileImagePath =
        _extractString(childData?['image']) ??
        _extractString(childData?['profile_img']) ??
        _extractString(childData?['profileImage']) ??
        _extractString(childData?['profile_image']);

    if (_isBlank(profileImagePath) && studentId != null) {
      profileImagePath = await StudentService.getProfileImage(studentId);
      if (!_isBlank(profileImagePath)) {
        await _persistSelectedChildImage(
          prefs,
          childData,
          studentId,
          profileImagePath!,
        );
      }
    }

    final version = prefs.getInt('student_profile_student_id') == studentId
        ? prefs.getInt('student_profile_image_version')
        : null;

    return _StudentHeaderData(
      studentId: studentId,
      profileImageUrl: _buildImageUrl(profileImagePath, version: version),
    );
  }

  Map<String, dynamic>? _readUserData(String? rawValue) {
    if (rawValue == null || rawValue.isEmpty) {
      return null;
    }

    try {
      return jsonDecode(rawValue) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistSelectedChildImage(
    SharedPreferences prefs,
    Map<String, dynamic>? childData,
    int studentId,
    String imagePath,
  ) async {
    if (childData == null) {
      return;
    }

    childData['profile_img'] = imagePath;
    childData['profileImage'] = imagePath;
    childData['profile_image'] = imagePath;
    childData['image'] = imagePath;

    await prefs.setString('selected_child', jsonEncode(childData));
    await prefs.setInt('student_profile_student_id', studentId);
  }

  int? _extractPositiveInt(dynamic value) {
    if (value is int && value > 0) {
      return value;
    }
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null && parsed > 0) {
        return parsed;
      }
    }
    if (value is List && value.isNotEmpty) {
      return _extractPositiveInt(value.first);
    }
    return null;
  }

  String? _extractString(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    if (value is List && value.isNotEmpty) {
      return _extractString(value.first);
    }
    return null;
  }

  bool _isBlank(String? value) => value == null || value.trim().isEmpty;

  String? _buildImageUrl(String? imagePath, {int? version}) {
    if (_isBlank(imagePath)) {
      return null;
    }

    var imageUrl = imagePath!.startsWith('http')
        ? imagePath
        : AppConfig.absoluteUrl(imagePath);

    if (version != null) {
      final separator = imageUrl.contains('?') ? '&' : '?';
      imageUrl = '$imageUrl${separator}v=$version';
    }

    return imageUrl;
  }
}

class _StudentHeaderData {
  final int? studentId;
  final String? profileImageUrl;

  const _StudentHeaderData({this.studentId, this.profileImageUrl});
}
