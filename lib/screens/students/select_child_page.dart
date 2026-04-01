import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:school_app/config/config.dart';
import 'package:school_app/widgets/student_app_bar.dart';
import 'student_menu_drawer.dart';
import 'student_dashboard.dart';
import '../teachers/teacher_dashboard.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class SelectChildPage extends StatefulWidget {
  const SelectChildPage({super.key});

  @override
  State<SelectChildPage> createState() => _SelectChildPageState();
}

class _SelectChildPageState extends State<SelectChildPage> {
  List<Map<String, dynamic>> children = [];
  bool isLoading = true;
  static const double _profileImageSize = 160;
  static const int _profileImageCacheSize = 320;

  int? _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is String) {
      return int.tryParse(value);
    }
    if (value is List && value.isNotEmpty) {
      return _toInt(value.first);
    }
    return null;
  }

  Map<String, dynamic> _buildSelectedChild(Map<String, dynamic> child) {
    final selectedChild = Map<String, dynamic>.from(child);
    final profilePath =
        child['profile_img'] ?? child['profile_image'] ?? child['image'];

    selectedChild['name'] = child['full_name'] ?? child['name'] ?? '';
    selectedChild['image'] =
        profilePath != null && profilePath.toString().trim().isNotEmpty
        ? AppConfig.absoluteUrl(profilePath.toString())
        : '';
    selectedChild['class'] =
        child['class_name'] ?? child['classname'] ?? child['class'] ?? '';
    selectedChild['notification'] = child['notification'] ?? 0;

    return selectedChild;
  }

  int? _resolveTeacherId(Map<String, dynamic> child) {
    return _toInt(child['staffid']) ??
        _toInt(child['teacher_id']) ??
        _toInt(child['staff_id']) ??
        _toInt(child['id']) ??
        _toInt(child['user_id']);
  }

  Future<void> _openSelectedDashboard(Map<String, dynamic> child) async {
    final prefs = await SharedPreferences.getInstance();
    final selectedType = (child['user_type'] ?? '').toString().toLowerCase();
    final isTeacher = selectedType == 'staff' || selectedType == 'teacher';

    await prefs.setString('selected_child', jsonEncode(child));

    if (isTeacher) {
      await prefs.remove('student_id');
      await prefs.remove('class_id');
      final teacherId = _resolveTeacherId(child);
      if (teacherId != null) {
        await prefs.setInt('teacher_id', teacherId);
      }

      if (!mounted) {
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const TeacherDashboardPage()),
      );
      return;
    }

    final studentId = _toInt(child['id']);
    final classId = _toInt(child['class_id']);

    if (studentId != null) {
      await prefs.setInt('student_id', studentId);
    }
    if (classId != null) {
      await prefs.setInt('class_id', classId);
    }
    await prefs.remove('teacher_id');

    if (!mounted) {
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => StudentDashboardPage(childData: child)),
    );
  }

  @override
  void initState() {
    super.initState();
    fetchChildren();
  }

  Widget _buildProfilePlaceholder() {
    return Container(
      width: _profileImageSize,
      height: _profileImageSize,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.person, size: 50, color: Colors.white),
    );
  }

  Widget _buildProfileImage(Map<String, dynamic> child) {
    final imageUrl = child['image']?.toString() ?? '';
    if (imageUrl.isEmpty) {
      return _buildProfilePlaceholder();
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: _profileImageSize,
        height: _profileImageSize,
        fit: BoxFit.cover,
        fadeInDuration: Duration.zero,
        placeholderFadeInDuration: Duration.zero,
        memCacheWidth: _profileImageCacheSize,
        memCacheHeight: _profileImageCacheSize,
        maxWidthDiskCache: _profileImageCacheSize,
        maxHeightDiskCache: _profileImageCacheSize,
        placeholder: (_, __) => _buildProfilePlaceholder(),
        errorWidget: (_, __, ___) => _buildProfilePlaceholder(),
      ),
    );
  }

  Future<void> _warmUpChildImages(List<Map<String, dynamic>> childList) async {
    final imageFutures = <Future<void>>[];

    for (final child in childList) {
      final imageUrl = child['image']?.toString() ?? '';
      if (imageUrl.isEmpty) {
        continue;
      }

      imageFutures.add(
        precacheImage(
          CachedNetworkImageProvider(
            imageUrl,
            maxWidth: _profileImageCacheSize,
            maxHeight: _profileImageCacheSize,
          ),
          context,
        ),
      );
    }

    await Future.wait(imageFutures);
  }

  Future<void> fetchChildren() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/student/parents/children'),
        headers: {
          'accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        List<Map<String, dynamic>> tempChildren = data
            .map<Map<String, dynamic>>((child) {
              return _buildSelectedChild(
                Map<String, dynamic>.from(child as Map),
              );
            })
            .toList();

        // Staff first, then Student
        tempChildren.sort((a, b) {
          final aType = (a['user_type'] ?? '').toString().toLowerCase();
          final bType = (b['user_type'] ?? '').toString().toLowerCase();

          if (aType == 'staff' && bType != 'staff') return -1;
          if (aType != 'staff' && bType == 'staff') return 1;
          return 0;
        });

        setState(() {
          children = tempChildren;
          isLoading = false;
        });
        unawaited(_warmUpChildImages(tempChildren));
      } else {
        setState(() => isLoading = false);
        debugPrint('Failed to fetch children: ${response.body}');
      }
    } catch (e) {
      setState(() => isLoading = false);
      debugPrint('Error fetching children: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: StudentAppBar(),
      drawer: const StudentMenuDrawer(),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : children.isEmpty
          ? const Center(child: Text("No children found"))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: children.map((child) {
                  final bool isTeacher =
                      (child['user_type'] ?? '').toString().toLowerCase() ==
                          'staff' ||
                      (child['user_type'] ?? '').toString().toLowerCase() ==
                          'teacher';

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: GestureDetector(
                      onTap: () => _openSelectedDashboard(child),
                      child: Stack(
                        alignment: Alignment.topRight,
                        children: [
                          Center(
                            child: Column(
                              children: [
                                Stack(
                                  children: [
                                    _buildProfileImage(child),
                                    if (child['notification'] > 0)
                                      Positioned(
                                        right: 4,
                                        top: 4,
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: const BoxDecoration(
                                            color: Colors.purple,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Text(
                                            child['notification'].toString(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  child['name'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E266D),
                                  ),
                                ),
                                if (isTeacher) ...[
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Teacher',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 4),
                                Text(
                                  'Class: ${child['class']}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
    );
  }
}
