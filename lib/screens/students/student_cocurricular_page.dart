import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:school_app/config/config.dart';
import 'package:school_app/screens/students/student_menu_drawer.dart';
import 'package:school_app/widgets/student_app_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

class StudentActivitiesPage extends StatefulWidget {
  final int studentId;
  final String academicYear;

  const StudentActivitiesPage({
    super.key,
    required this.studentId,
    required this.academicYear,
  });

  @override
  State<StudentActivitiesPage> createState() => _StudentActivitiesPageState();
}

class _StudentActivitiesPageState extends State<StudentActivitiesPage> {
  bool isLoading = true;
  List<dynamic> activities = [];
  String? errorMessage;
  Map<String, dynamic>? _selectedActivity;
  Timer? _pollingTimer;
  int _retryCount = 0;
  static const int maxRetries = 3;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    fetchStudentActivities();

    // Poll every 30 seconds instead of 15 to reduce load
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      fetchStudentActivities(autoUpdate: true);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _scrollController.dispose(); // ✅ add this
    super.dispose();
  }

  Future<void> fetchStudentActivities({bool autoUpdate = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("auth_token");

      if (token == null) {
        if (!autoUpdate) {
          setState(() {
            errorMessage = "No authentication token found. Please login again.";
            isLoading = false;
          });
        }
        return;
      }

      // Use explicit port 443 (HTTPS) - it's correct but we'll ensure URL is properly formatted
      final url = AppConfig.apiUri(
        '/co-curricular/student-activities',
        queryParameters: {
          'studentId': widget.studentId,
          'academicYear': widget.academicYear,
        },
      );

      // Add timeout to prevent hanging requests
      final response = await http
          .get(
            url,
            headers: {
              "Authorization": "Bearer $token",
              "accept": "application/json",
              "content-type": "application/json",
            },
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw TimeoutException(
                'Connection timeout. Please check your internet connection.',
              );
            },
          );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);

        data.sort((a, b) {
          final dateA =
              DateTime.tryParse(a["created_at"] ?? "") ?? DateTime(2000);
          final dateB =
              DateTime.tryParse(b["created_at"] ?? "") ?? DateTime(2000);
          return dateB.compareTo(dateA);
        });

        _retryCount = 0;

        if (autoUpdate) {
          if (!listEquals(activities, data)) {
            setState(() => activities = data);
          }
        } else {
          setState(() {
            activities = data;
            isLoading = false;
            errorMessage = null;
          });
        }
      } else if (response.statusCode == 401) {
        // Unauthorized - token expired
        if (!autoUpdate) {
          setState(() {
            errorMessage = "Session expired. Please login again.";
            isLoading = false;
          });
        }
        // Optionally: Navigate to login screen
      } else {
        if (!autoUpdate) {
          setState(() {
            errorMessage =
                "Failed to fetch activities (${response.statusCode}). Please try again.";
            isLoading = false;
          });
        }
      }
    } on SocketException catch (e) {
      // Network error - no internet or DNS resolution failed
      final errorMsg = _handleNetworkError(e);
      if (!autoUpdate) {
        setState(() {
          errorMessage = errorMsg;
          isLoading = false;
        });
      } else if (_retryCount < maxRetries) {
        // Retry on auto-update failure
        _retryCount++;
        await Future.delayed(Duration(seconds: _retryCount * 5));
        fetchStudentActivities(autoUpdate: true);
      }
    } on TimeoutException catch (e) {
      if (!autoUpdate) {
        setState(() {
          errorMessage =
              "Connection timeout. Please check your internet connection.";
          isLoading = false;
        });
      }
    } catch (e) {
      if (!autoUpdate) {
        setState(() {
          errorMessage = "Error: $e";
          isLoading = false;
        });
      }
    }
  }

  String _handleNetworkError(SocketException e) {
    if (e.message.contains('Failed host lookup') ||
        e.message.contains('No address associated with hostname')) {
      return '''Unable to connect to server. Please check:
• Your internet connection
• If you're using a VPN, try disabling it
• The server might be temporarily unavailable
• Try switching between WiFi and Mobile Data

Error: DNS lookup failed''';
    } else if (e.message.contains('Network is unreachable')) {
      return "No internet connection. Please check your network settings.";
    } else {
      return "Network error: ${e.message}";
    }
  }

  @override
  Widget build(BuildContext context) {
    void _handleBack() {
      if (_selectedActivity != null) {
        setState(() => _selectedActivity = null);
      } else {
        Navigator.pop(context);
      }
    }

    return WillPopScope(
      onWillPop: () async {
        if (_selectedActivity != null) {
          setState(() => _selectedActivity = null);
          return false; // ❌ prevent page pop
        }
        return true; // ✅ allow pop
      },
      child: Scaffold(
        appBar: StudentAppBar(),
        drawer: StudentMenuDrawer(),
        body: Container(
          color: const Color(0xFFDBD88A),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button
              GestureDetector(
                // onTap: () {
                //   if (_selectedActivity != null) {
                //     setState(() => _selectedActivity = null);
                //   } else {
                //     Navigator.pop(context);
                //   }
                // },
                onTap: _handleBack,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: const Text(
                    '< Back',
                    style: TextStyle(color: Colors.black, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Page title with icon
              Row(
                children: [
                  Container(
                    width: 35,
                    height: 35,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E3192),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: SvgPicture.asset(
                      'assets/icons/co_curricular.svg',
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Co curricular activities',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E3192),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // List or Detail view
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : errorMessage != null
                    ? _buildErrorWidget()
                    : activities.isEmpty
                    ? const Center(child: Text("No activities found"))
                    : _selectedActivity != null
                    ? _buildActivityDetail(_selectedActivity!)
                    : ListView.builder(
                        key: const PageStorageKey("activities_list"),
                        controller: _scrollController,
                        itemCount: activities.length,
                        itemBuilder: (context, index) {
                          final activity = activities[index];
                          return GestureDetector(
                            onTap: () {
                              setState(() => _selectedActivity = activity);
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 6,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    activity["activity_name"] ??
                                        "Unknown Activity",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: Color(0xFF2E3192),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "Category: ${activity["category_name"] ?? "N/A"}",
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Class: ${activity["class_name"] ?? "N/A"}",
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  isLoading = true;
                  errorMessage = null;
                });
                fetchStudentActivities();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E3192),
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityDetail(Map<String, dynamic> activity) {
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
                activity["activity_name"] ?? "No title",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E3192),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildDetailRow('Category:', activity["category_name"] ?? "N/A"),
            const SizedBox(height: 8),
            _buildDetailRow('Class:', activity["class_name"] ?? "N/A"),
            const SizedBox(height: 8),
            _buildDetailRow('Student:', activity["student_name"] ?? "N/A"),
            const SizedBox(height: 8),
            _buildDetailRow(
              'Academic Year:',
              activity["academic_year"] ?? "N/A",
            ),
            const SizedBox(height: 16),
            if (activity["description"] != null &&
                activity["description"].toString().isNotEmpty)
              _buildDetailRow('Description:', activity["description"]),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 16))),
      ],
    );
  }
}
