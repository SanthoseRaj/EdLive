import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:school_app/config/config.dart';
import 'package:school_app/screens/teachers/teacher_notifiction_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TeacherAppBar extends StatefulWidget implements PreferredSizeWidget {
  final VoidCallback? onMenuPressed;
  final VoidCallback? onProfileTap;
  final Object? refreshToken;

  const TeacherAppBar({
    super.key,
    this.onMenuPressed,
    this.onProfileTap,
    this.refreshToken,
  });

  @override
  State<TeacherAppBar> createState() => _TeacherAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(63);
}

class _TeacherAppBarState extends State<TeacherAppBar> {
  late Future<_TeacherHeaderData> _headerDataFuture;

  @override
  void initState() {
    super.initState();
    _headerDataFuture = _getTeacherHeaderData();
  }

  @override
  void didUpdateWidget(covariant TeacherAppBar oldWidget) {
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
      _headerDataFuture = _getTeacherHeaderData();
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
      child: FutureBuilder<_TeacherHeaderData>(
        future: _headerDataFuture,
        builder: (context, snapshot) {
          final headerData = snapshot.data ?? const _TeacherHeaderData();

          return AppBar(
            backgroundColor: Colors.white,
            elevation: 4,
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
                        builder: (_) => TeacherNotificationPage(),
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

                    await Navigator.pushNamed(context, '/profile');
                    _refreshHeaderData();
                  },
                  child: _buildProfileAvatar(headerData.profileImageUrl),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<_TeacherHeaderData> _getTeacherHeaderData() async {
    final prefs = await SharedPreferences.getInstance();
    final loggedInUserType = prefs.getString('user_type')?.toLowerCase();
    final userData = _readUserData(prefs.getString('user_data'));
    final selectedChild = loggedInUserType == 'teacher'
        ? null
        : _readUserData(prefs.getString('selected_child'));
    final selectedChildIsTeacher = _isTeacherSelection(selectedChild);
    final staffId =
        _resolveStaffId(selectedChild) ??
        _extractPositiveInt(userData?['staffid']) ??
        _extractPositiveInt(userData?['teacher_id']) ??
        _extractPositiveInt(userData?['staff_id']) ??
        _extractPositiveInt(userData?['id']) ??
        prefs.getInt('teacher_id');

    final cachedStaffId = prefs.getInt('teacher_profile_staff_id');
    final cachedImagePath = cachedStaffId == staffId
        ? prefs.getString('teacher_profile_image')
        : null;

    String? profileImagePath =
        (selectedChildIsTeacher
            ? _extractString(selectedChild?['image']) ??
                  _extractString(selectedChild?['profile_image']) ??
                  _extractString(selectedChild?['profile_img'])
            : null) ??
        cachedImagePath ??
        _extractString(userData?['profile_image']) ??
        _extractString(userData?['profile_img']) ??
        _extractString(userData?['image']);

    if (staffId != null && prefs.getInt('teacher_id') != staffId) {
      await prefs.setInt('teacher_id', staffId);
    }

    if (_isBlank(profileImagePath) && staffId != null) {
      profileImagePath = await _fetchTeacherProfileImage(staffId);

      if (!_isBlank(profileImagePath)) {
        await prefs.setInt('teacher_profile_staff_id', staffId);
        await prefs.setString('teacher_profile_image', profileImagePath!);
        await prefs.setInt(
          'teacher_profile_image_version',
          DateTime.now().millisecondsSinceEpoch,
        );
      }
    }

    if (!_isBlank(profileImagePath) &&
        cachedStaffId != staffId &&
        staffId != null) {
      await prefs.setInt('teacher_profile_staff_id', staffId);
      await prefs.setString('teacher_profile_image', profileImagePath!);
    }

    final version = prefs.getInt('teacher_profile_image_version');

    return _TeacherHeaderData(
      profileImageUrl: _buildImageUrl(profileImagePath, version: version),
    );
  }

  Map<String, dynamic>? _readUserData(String? rawUserData) {
    if (rawUserData == null || rawUserData.isEmpty) {
      return null;
    }

    try {
      return jsonDecode(rawUserData) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  bool _isTeacherSelection(Map<String, dynamic>? data) {
    final selectedType = data?['user_type']?.toString().toLowerCase() ?? '';
    return selectedType == 'staff' || selectedType == 'teacher';
  }

  int? _resolveStaffId(Map<String, dynamic>? data) {
    if (!_isTeacherSelection(data)) {
      return null;
    }

    return _extractPositiveInt(data?['staffid']) ??
        _extractPositiveInt(data?['teacher_id']) ??
        _extractPositiveInt(data?['staff_id']) ??
        _extractPositiveInt(data?['id']) ??
        _extractPositiveInt(data?['user_id']);
  }

  Future<String?> _fetchTeacherProfileImage(int staffId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null || token.isEmpty) {
        return null;
      }

      final response = await http.get(
        AppConfig.apiUri('/staff/Staff/$staffId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return _extractString(data['profile_image']);
    } catch (_) {
      return null;
    }
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
        : imagePath.startsWith('/')
        ? '${AppConfig.serverOrigin}$imagePath'
        : '${AppConfig.serverOrigin}/$imagePath';

    if (version != null) {
      final separator = imageUrl.contains('?') ? '&' : '?';
      imageUrl = '$imageUrl${separator}v=$version';
    }

    return imageUrl;
  }
}

class _TeacherHeaderData {
  final String? profileImageUrl;

  const _TeacherHeaderData({this.profileImageUrl});
}
