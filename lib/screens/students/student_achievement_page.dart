import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:school_app/screens/students/student_menu_drawer.dart';
import 'package:school_app/widgets/student_app_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

// ----------------- MODEL -----------------
class Achievement {
  final int id;
  final String title;
  final String description;
  final String category;
  final String achievementDate;
  final String awardedBy;
  final String evidenceUrl;
  final String fullName;
  final String visibility;
  final String createdAt;
  final String updatedAt;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.achievementDate,
    required this.awardedBy,
    required this.evidenceUrl,
    required this.fullName,
    required this.visibility,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json['id'],
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? '',
      achievementDate: json['achievement_date'] ?? '',
      awardedBy: json['awarded_by'] ?? '',
      evidenceUrl: json['evidence_url'] ?? '',
      fullName: json['full_name'] ?? '',
      visibility: json['visibility'] ?? '',
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }
}

// ----------------- HELPERS -----------------
String getFullFileUrl(String url) {
  if (url.isEmpty) return "";
  if (url.startsWith("http")) {
    return url;
  } else {
    return "https://schoolmanagement.canadacentral.cloudapp.azure.com:443$url";
  }
}

/// Show image or PDF automatically
Widget buildAchievementFile(String url, {double height = 200}) {
  if (url.isEmpty) {
    return SizedBox(
      height: height,
      child: const Center(child: Text("No file available")),
    );
  }

  final fullUrl = getFullFileUrl(url);

  if (fullUrl.toLowerCase().endsWith('.pdf')) {
    // PDF view
    return SizedBox(
      height: height,
      child: SfPdfViewer.network(fullUrl),
    );
  } else {
    // Image view
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        fullUrl,
        width: double.infinity,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => SizedBox(
          height: height,
          child: const Center(child: Text("File not viewable")),
        ),
      ),
    );
  }
}

// ----------------- MAIN PAGE -----------------
class StudentAchievementPage extends StatefulWidget {
  final int classId;
  const StudentAchievementPage({super.key, required this.classId});

  @override
  State<StudentAchievementPage> createState() => _StudentAchievementPageState();
}

class _StudentAchievementPageState extends State<StudentAchievementPage> {
  late Future<List<Achievement>> futureAchievements;
  List<Achievement> _currentAchievements = [];
  Set<int> _viewedIds = {};
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    futureAchievements = fetchAchievements();

    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _checkForNewAchievements();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkForNewAchievements() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      final studentId = prefs.getInt('student_id');
      if (token.isEmpty || studentId == null) return;

      final response = await http.get(
        Uri.parse(
          "https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api/achievements/visible?studentId=$studentId",
        ),
        headers: {
          'accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List jsonData = json.decode(response.body);
        final newList = jsonData.map((e) => Achievement.fromJson(e)).toList();

        newList.sort((a, b) {
          final dateA = DateTime.tryParse(a.createdAt) ?? DateTime(1900);
          final dateB = DateTime.tryParse(b.createdAt) ?? DateTime(1900);
          return dateB.compareTo(dateA);
        });

        bool hasNewAchievement = false;
        if (newList.isNotEmpty &&
            (_currentAchievements.isEmpty ||
                newList.first.id != _currentAchievements.first.id)) {
          hasNewAchievement = true;
        }

        if (hasNewAchievement && mounted) {
          setState(() {
            futureAchievements = Future.value(newList);
            _currentAchievements = newList;
          });
        }
      }
    } catch (e) {
      debugPrint("⚠️ Error checking for new achievements: $e");
    }
  }

  Future<List<Achievement>> fetchAchievements() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    final studentId = prefs.getInt('student_id');
    if (token.isEmpty || studentId == null) {
      throw Exception("⚠️ Missing token or student ID");
    }

    final response = await http.get(
      Uri.parse(
        "https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api/achievements/visible?studentId=$studentId",
      ),
      headers: {
        'accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List jsonData = json.decode(response.body);
      final achievements = jsonData.map((e) => Achievement.fromJson(e)).toList();

      achievements.sort((a, b) {
        final dateA = DateTime.tryParse(a.createdAt) ?? DateTime(1900);
        final dateB = DateTime.tryParse(b.createdAt) ?? DateTime(1900);
        return dateB.compareTo(dateA);
      });

      _currentAchievements = achievements;
      return achievements;
    } else {
      throw Exception('Failed to load achievements');
    }
  }

  Future<void> _markAchievementViewed(int achievementId) async {
    if (_viewedIds.contains(achievementId)) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    final studentId = prefs.getInt('student_id');
    if (studentId == null || token.isEmpty) return;

    try {
      final url = Uri.parse(
        "https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api/dashboard/viewed?studentId=$studentId",
      );

      final response = await http.post(
        url,
        headers: {"Authorization": "Bearer $token", "Content-Type": "application/json"},
        body: jsonEncode({
          "item_type": "achievements",
          "item_id": achievementId,
        }),
      );

      if (response.statusCode == 200) {
        _viewedIds.add(achievementId);
        debugPrint("✅ Achievement $achievementId marked as viewed");
      } else {
        debugPrint("❌ Failed to mark viewed: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("❌ Error marking viewed: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: StudentAppBar(),
      drawer: StudentMenuDrawer(),
      backgroundColor: const Color(0xFFF7EB7C),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Text(
                "< Back",
                style: TextStyle(color: Colors.black, fontSize: 16),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFF2E3192),
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                  child: SvgPicture.asset(
                    "assets/icons/achievements.svg",
                    width: 20,
                    height: 20,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  "Achievements",
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E3192),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Achievement>>(
              future: futureAchievements,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF2E3192)),
                  );
                } else if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text("No achievements found."));
                }

                final achievements = snapshot.data!;

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: achievements.length,
                  itemBuilder: (context, index) {
                    final item = achievements[index];

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _markAchievementViewed(item.id);
                    });

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AchievementDetailPage(achievement: item),
                          ),
                        );
                      },
                      child: Card(
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            buildAchievementFile(item.evidenceUrl, height: 180),
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.fullName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Color(0xFF2E3192),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "${item.title} - ${item.description}",
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------- DETAIL PAGE -----------------
class AchievementDetailPage extends StatelessWidget {
  final Achievement achievement;
  const AchievementDetailPage({super.key, required this.achievement});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: StudentAppBar(),
      drawer: StudentMenuDrawer(),
      backgroundColor: const Color(0xFFF7EB7C),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  "< Back",
                  style: TextStyle(fontSize: 16, color: Colors.black),
                ),
              ),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      buildAchievementFile(achievement.evidenceUrl, height: 350),
                      const SizedBox(height: 16),
                      Text(
                        achievement.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E3192),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        achievement.description,
                        style: const TextStyle(fontSize: 15, color: Colors.black87),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Text("Student: ", style: TextStyle(fontSize: 14)),
                          Text(achievement.fullName,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text("Category: ", style: TextStyle(fontSize: 14)),
                          Text(achievement.category,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text("Awarded by: ", style: TextStyle(fontSize: 14)),
                          Text(achievement.awardedBy,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text("Date: ", style: TextStyle(fontSize: 14)),
                          Text(
                            achievement.achievementDate.isNotEmpty
                                ? achievement.achievementDate.split('T').first
                                : 'N/A',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text("Visibility: ", style: TextStyle(fontSize: 14)),
                          Text(achievement.visibility,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
