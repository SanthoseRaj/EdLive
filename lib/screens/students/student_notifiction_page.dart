import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:school_app/screens/students/student_menu_drawer.dart';
import 'package:school_app/widgets/student_app_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

import 'package:school_app/screens/students/student_payments_page.dart';
import 'student_achievement_page.dart';
import 'student_library_book_detail_page.dart';
import 'student_library_page.dart';
import 'student_messages_page.dart';
import 'student_todo_list_screen.dart';
import 'package:school_app/config/config.dart';

int _parseNotificationInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is String) {
    return int.tryParse(value.trim()) ?? 0;
  }
  return 0;
}

// ----------------- MODEL -----------------
class StudentNotificationItem {
  final int id;
  final int linkedItemId;
  final String title;
  final String subtitle;
  final String moduleType;
  final DateTime dateTime;
  final String type;
  final String apiItemType; // for backend API

  StudentNotificationItem({
    required this.id,
    required this.linkedItemId,
    required this.title,
    required this.subtitle,
    required this.moduleType,
    required this.dateTime,
    required this.type,
    required this.apiItemType,
  });

  factory StudentNotificationItem.fromJson(Map<String, dynamic> json) {
    final nestedData = json['data'] is Map
        ? Map<String, dynamic>.from(json['data'] as Map)
        : <String, dynamic>{};
    final notificationId = _parseNotificationInt(json['id']);
    final linkedItemId = _parseNotificationInt(
      json['item_id'] ??
          json['module_item_id'] ??
          json['module_id'] ??
          json['resource_id'] ??
          json['reference_id'] ??
          nestedData['item_id'] ??
          nestedData['id'],
    );

    return StudentNotificationItem(
      id: notificationId,
      linkedItemId: linkedItemId,
      title: json['title'] ?? '',
      subtitle: json['content'] ?? '',
      moduleType: json['module_type'] ?? '',
      dateTime: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      type: json['type'] ?? '',
      apiItemType: json['module_type'] ?? '',
    );
  }
}

// ----------------- PAGE -----------------
class StudentNotificationPage extends StatefulWidget {
  const StudentNotificationPage({super.key});

  @override
  State<StudentNotificationPage> createState() =>
      _StudentNotificationPageState();
}

class _StudentNotificationPageState extends State<StudentNotificationPage> {
  bool _loading = true;
  String? _error;
  final DateTime _selectedDate = DateTime.now();

  final Set<int> _viewedIds = {};

  bool _fetchingMore = false;
  DateTime? _nextFetchDate; // for keeping track of next week's start date

  void _navigateToModule(StudentNotificationItem item) async {
    final module = item.moduleType.toLowerCase();
    final prefs = await SharedPreferences.getInstance();
    final classId = prefs.getInt('class_id') ?? 1;
    final studentId = prefs.getInt('student_id');
    final linkedItemId = item.linkedItemId > 0 ? item.linkedItemId : null;

    if (!mounted) {
      return;
    }

    switch (module) {
      case 'todo':
      case 'to-do':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StudentToDoListPage(
              initialTaskId: linkedItemId,
              initialTaskTitle: item.title,
              initialTaskDescription: item.subtitle,
            ),
          ),
        );
        break;

      case 'exam':
      case 'exams':
        Navigator.pushNamed(context, '/exams');
        break;

      case 'syllabus':
        Navigator.pushNamed(context, '/syllabus');
        break;

      case 'achievement':
      case 'achievements':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StudentAchievementPage(
              classId: classId,
              initialAchievementId: linkedItemId,
              initialAchievementTitle: item.title,
              initialAchievementDescription: item.subtitle,
              autoOpenInitialDetail: true,
            ),
          ),
        );
        break;

      // ✅ Messages notification
      case 'message':
      case 'messages':
        if (studentId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StudentMessagesPage(
                studentId: studentId,
                initialMessageId: linkedItemId,
                initialMessageTitle: item.title,
                initialMessageText: item.subtitle,
              ),
            ),
          );
        }
        break;

      // ✅ Payment notification
      case 'payment':
      case 'payments':
        if (studentId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  StudentPaymentsPage(studentId: studentId.toString()),
            ),
          );
        }
        break;

      // ✅ Library notification
      case 'library':
      case 'libraries':
        if (linkedItemId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StudentBookDetailPage(bookId: linkedItemId),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const StudentLibraryPage()),
          );
        }
        break;

      default:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No linked page for this notification.'),
          ),
        );
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _markAsViewed(int itemId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("auth_token");
      final studentId = prefs.getInt("student_id");

      if (token == null || studentId == null) return;

      final url = "${AppConfig.baseUrl}/dashboard/viewed?studentId=$studentId";

      final response = await http.post(
        Uri.parse(url),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: json.encode({"item_type": "notifications", "item_id": itemId}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data["success"] == true) {
          debugPrint("✅ Student notification $itemId marked as viewed");
        }
      } else {
        debugPrint(
          "❌ Failed to mark notification viewed: ${response.statusCode}",
        );
      }
    } catch (e) {
      debugPrint("❌ Error marking notification viewed: $e");
    }
  }

  Map<String, List<StudentNotificationItem>> _notificationsByDate = {};

  Future<void> _fetchNotifications({bool loadMore = false}) async {
    try {
      if (loadMore) {
        setState(() => _fetchingMore = true);
      } else {
        setState(() {
          _loading = true;
          _error = null;
          _notificationsByDate.clear();
          _nextFetchDate = _selectedDate; // reset when first load
        });
      }

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("auth_token");
      final studentId = prefs.getInt("student_id");

      if (token == null || studentId == null) {
        setState(() {
          _loading = false;
          _fetchingMore = false;
          _error = "Missing token or student ID. Please login again.";
        });
        return;
      }

      final dateToFetch = _nextFetchDate ?? _selectedDate;
      final formattedDate = DateFormat('yyyy-MM-dd').format(dateToFetch);

      final url =
          "${AppConfig.baseUrl}/dashboard/daily-notifications?studentId=$studentId&date=$formattedDate";

      final response = await http.get(
        Uri.parse(url),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode != 200) {
        throw Exception("Failed to fetch notifications");
      }

      final data = json.decode(response.body);
      if (data['success'] != true) {
        throw Exception("API returned error");
      }

      final notificationsData =
          data['notifications']['notifications'] as Map<String, dynamic>? ?? {};

      final periodStart = data['notifications']['period_start'];
      final periodEnd = data['notifications']['period_end'];

      // ✅ Check if the week has any data
      bool hasData = notificationsData.values.any(
        (list) => (list as List).isNotEmpty,
      );

      if (hasData) {
        // 🔹 Only process dates that have data
        notificationsData.forEach((dateStr, list) {
          final List items = list as List;
          if (items.isNotEmpty) {
            _notificationsByDate.putIfAbsent(dateStr, () => []);
            _notificationsByDate[dateStr]!.addAll(
              items.map((e) => StudentNotificationItem.fromJson(e)).toList(),
            );
          }
        });
      } else {
        // 🔹 No data at all in this week → skip showing in UI
        debugPrint(
          "⚠️ Week ($periodStart → $periodEnd) is empty, skipping display.",
        );
      }

      // 🔹 Prepare for next fetch
      if (periodStart != null) {
        DateTime prevStart = DateTime.parse(periodStart);
        if (!prevStart.isBefore(DateTime(2020))) {
          _nextFetchDate = prevStart.subtract(const Duration(days: 1));
        } else {
          _nextFetchDate = null;
        }
      } else {
        _nextFetchDate = null;
      }

      // 🔹 Sort notifications by date descending
      final sortedGrouped = Map.fromEntries(
        _notificationsByDate.entries.toList()
          ..sort((a, b) => b.key.compareTo(a.key)),
      );

      setState(() {
        _notificationsByDate = sortedGrouped;
        _loading = false;
        _fetchingMore = false;
      });

      // 🔹 If week empty, automatically fetch previous week
      if (!hasData && _nextFetchDate != null) {
        debugPrint(
          "📅 Current week empty. Auto-fetching previous week ending ${_nextFetchDate}",
        );
        _fetchNotifications(loadMore: true);
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _fetchingMore = false;
        _error = "Error: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: StudentAppBar(),
      drawer: const StudentMenuDrawer(),
      backgroundColor: const Color(0xFFF9F7A5),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔹 Back button
            InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  SizedBox(width: 4),
                  Text(
                    "< Back",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 🔹 Title row with icon
            Row(
              children: [
                Container(
                  height: 40,
                  width: 40,
                  decoration: const BoxDecoration(color: Color(0xFF2E3192)),
                  padding: const EdgeInsets.all(8),
                  child: SvgPicture.asset(
                    'assets/icons/notification.svg',
                    colorFilter: const ColorFilter.mode(
                      Colors.white,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  "Notifications",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E3192),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Date picker
            // Row(
            //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
            //   children: [
            //     Text(
            //       "Date: ${DateFormat('dd/MM/yyyy').format(_selectedDate)}",
            //       style: const TextStyle(
            //         fontSize: 16,
            //         fontWeight: FontWeight.bold,
            //         color: Color(0xFF2E3192),
            //       ),
            //     ),
            //     IconButton(
            //       icon: const Icon(
            //         Icons.calendar_today,
            //         color: Color(0xFF2E3192),
            //       ),
            //       onPressed: _pickDate,
            //     ),
            //   ],
            // ),
            const SizedBox(height: 10),

            // Loader / Error / List
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(child: Text(_error!))
                  : _notificationsByDate.isEmpty
                  ? const Center(child: Text("No notifications found."))
                  : ListView(
                      children: [
                        // 🔹 Notifications list
                        ..._notificationsByDate.entries.map((entry) {
                          final date = entry.key;
                          final items = entry.value;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Date header
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Text(
                                  DateFormat(
                                    'dd/MMM/yyyy',
                                  ).format(DateTime.parse(date)),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2E3192),
                                  ),
                                ),
                              ),
                              ...items.map((item) {
                                // Mark as viewed if not already
                                if (!_viewedIds.contains(item.id)) {
                                  _viewedIds.add(item.id);
                                  _markAsViewed(item.id);
                                }

                                return InkWell(
                                  onTap: () => _navigateToModule(item),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Card(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    elevation: 2,
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  item.type,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                    color: Color(0xFF2E3192),
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              Text(
                                                item.moduleType,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.black54,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            item.title,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            item.subtitle,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          );
                        }),

                        // 🔹 Load More button at bottom
                        if (_nextFetchDate != null)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: _fetchingMore
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : ElevatedButton(
                                    onPressed: () =>
                                        _fetchNotifications(loadMore: true),
                                    child: const Text(
                                      "View Past Notifications",
                                    ),
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
}

//Old Page Code (Reply Page section code)

// import 'package:flutter/material.dart';
// import 'package:flutter_svg/flutter_svg.dart';
// import 'package:school_app/screens/students/student_menu_drawer.dart';
// import 'package:school_app/widgets/student_app_bar.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
// import 'package:intl/intl.dart';
// import 'student_notification_replies_page.dart'; // your replies page

// // ----------------- MODEL -----------------
// class StudentNotificationItem {
//   final int id;
//   final String title;
//   final String subtitle;
//   final String moduleType;
//   final DateTime dateTime;
//   final String type;
//   final String apiItemType; // for backend API

//   StudentNotificationItem({
//     required this.id,
//     required this.title,
//     required this.subtitle,
//     required this.moduleType,
//     required this.dateTime,
//     required this.type,
//     required this.apiItemType,
//   });

//   factory StudentNotificationItem.fromJson(Map<String, dynamic> json) {
//     return StudentNotificationItem(
//       id: json['id'] ?? 0,
//       title: json['title'] ?? '',
//       subtitle: json['content'] ?? '',
//       moduleType: json['module_type'] ?? '',
//       dateTime: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
//       type: json['type'] ?? '',
//       apiItemType: json['module_type'] ?? '',
//     );
//   }
// }

// // ----------------- PAGE -----------------
// class StudentNotificationPage extends StatefulWidget {
//   const StudentNotificationPage({super.key});

//   @override
//   State<StudentNotificationPage> createState() =>
//       _StudentNotificationPageState();
// }

// class _StudentNotificationPageState extends State<StudentNotificationPage> {
//   List<StudentNotificationItem> _notifications = [];
//   bool _loading = true;
//   String? _error;
//   DateTime _selectedDate = DateTime.now();

//   Set<int> _viewedIds = {};

//   bool _fetchingMore = false;
//   DateTime? _nextFetchDate; // for keeping track of next week's start date

//   @override
//   void initState() {
//     super.initState();
//     _fetchNotifications();
//   }

//   Future<void> _markAsViewed(int itemId) async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final token = prefs.getString("auth_token");
//       final studentId = prefs.getInt("student_id");

//       if (token == null || studentId == null) return;

//       final url =
//           "${AppConfig.baseUrl}/dashboard/viewed?studentId=$studentId";

//       final response = await http.post(
//         Uri.parse(url),
//         headers: {
//           "Authorization": "Bearer $token",
//           "Content-Type": "application/json",
//         },
//         body: json.encode({"item_type": "notifications", "item_id": itemId}),
//       );

//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);
//         if (data["success"] == true) {
//           debugPrint("✅ Student notification $itemId marked as viewed");
//         }
//       } else {
//         debugPrint(
//           "❌ Failed to mark notification viewed: ${response.statusCode}",
//         );
//       }
//     } catch (e) {
//       debugPrint("❌ Error marking notification viewed: $e");
//     }
//   }

//   Future<void> _pickDate() async {
//     final DateTime? picked = await showDatePicker(
//       context: context,
//       initialDate: _selectedDate,
//       firstDate: DateTime(2020),
//       lastDate: DateTime(2100),
//     );

//     if (picked != null && picked != _selectedDate) {
//       setState(() {
//         _selectedDate = picked;
//         _loading = true;
//       });
//       _fetchNotifications();
//     }
//   }

//   Map<String, List<StudentNotificationItem>> _notificationsByDate = {};

//   Future<void> _fetchNotifications({bool loadMore = false}) async {
//     try {
//       if (loadMore) {
//         setState(() => _fetchingMore = true);
//       } else {
//         setState(() {
//           _loading = true;
//           _error = null;
//           _notificationsByDate.clear();
//           _nextFetchDate = _selectedDate; // reset when first load
//         });
//       }

//       final prefs = await SharedPreferences.getInstance();
//       final token = prefs.getString("auth_token");
//       final studentId = prefs.getInt("student_id");

//       if (token == null || studentId == null) {
//         setState(() {
//           _loading = false;
//           _fetchingMore = false;
//           _error = "Missing token or student ID. Please login again.";
//         });
//         return;
//       }

//       final dateToFetch = _nextFetchDate ?? _selectedDate;
//       final formattedDate = DateFormat('yyyy-MM-dd').format(dateToFetch);

//       final url =
//           "${AppConfig.baseUrl}/dashboard/daily-notifications?studentId=$studentId&date=$formattedDate";

//       final response = await http.get(
//         Uri.parse(url),
//         headers: {
//           "Authorization": "Bearer $token",
//           "Content-Type": "application/json",
//         },
//       );

//       if (response.statusCode != 200) {
//         throw Exception("Failed to fetch notifications");
//       }

//       final data = json.decode(response.body);
//       if (data['success'] != true) {
//         throw Exception("API returned error");
//       }

//       final notificationsData =
//           data['notifications']['notifications'] as Map<String, dynamic>? ?? {};

//       final periodStart = data['notifications']['period_start'];
//       final periodEnd = data['notifications']['period_end'];

//       // ✅ Check if the week has any data
//       bool hasData = notificationsData.values.any(
//         (list) => (list as List).isNotEmpty,
//       );

//       if (hasData) {
//         // 🔹 Only process dates that have data
//         notificationsData.forEach((dateStr, list) {
//           final List items = list as List;
//           if (items.isNotEmpty) {
//             _notificationsByDate.putIfAbsent(dateStr, () => []);
//             _notificationsByDate[dateStr]!.addAll(
//               items.map((e) => StudentNotificationItem.fromJson(e)).toList(),
//             );
//           }
//         });
//       } else {
//         // 🔹 No data at all in this week → skip showing in UI
//         debugPrint(
//           "⚠️ Week ($periodStart → $periodEnd) is empty, skipping display.",
//         );
//       }

//       // 🔹 Prepare for next fetch
//       if (periodStart != null) {
//         DateTime prevStart = DateTime.parse(periodStart);
//         if (!prevStart.isBefore(DateTime(2020))) {
//           _nextFetchDate = prevStart.subtract(const Duration(days: 1));
//         } else {
//           _nextFetchDate = null;
//         }
//       } else {
//         _nextFetchDate = null;
//       }

//       // 🔹 Sort notifications by date descending
//       final sortedGrouped = Map.fromEntries(
//         _notificationsByDate.entries.toList()
//           ..sort((a, b) => b.key.compareTo(a.key)),
//       );

//       setState(() {
//         _notificationsByDate = sortedGrouped;
//         _loading = false;
//         _fetchingMore = false;
//       });

//       // 🔹 If week empty, automatically fetch previous week
//       if (!hasData && _nextFetchDate != null) {
//         debugPrint(
//           "📅 Current week empty. Auto-fetching previous week ending ${_nextFetchDate}",
//         );
//         _fetchNotifications(loadMore: true);
//       }
//     } catch (e) {
//       setState(() {
//         _loading = false;
//         _fetchingMore = false;
//         _error = "Error: $e";
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: StudentAppBar(),
//       drawer: const StudentMenuDrawer(),
//       backgroundColor: const Color(0xFFF9F7A5),
//       body: Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // 🔹 Back button
//             InkWell(
//               onTap: () => Navigator.pop(context),
//               borderRadius: BorderRadius.circular(4),
//               child: Row(
//                 mainAxisSize: MainAxisSize.min,
//                 children: const [
//                   SizedBox(width: 4),
//                   Text(
//                     "< Back",
//                     style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
//                   ),
//                 ],
//               ),
//             ),

//             const SizedBox(height: 12),

//             // 🔹 Title row with icon
//             Row(
//               children: [
//                 Container(
//                   height: 40,
//                   width: 40,
//                   decoration: const BoxDecoration(color: Color(0xFF2E3192)),
//                   padding: const EdgeInsets.all(8),
//                   child: SvgPicture.asset(
//                     'assets/icons/notification.svg',
//                     color: Colors.white,
//                   ),
//                 ),
//                 const SizedBox(width: 12),
//                 const Text(
//                   "Notifications",
//                   style: TextStyle(
//                     fontSize: 28,
//                     fontWeight: FontWeight.bold,
//                     color: Color(0xFF2E3192),
//                   ),
//                 ),
//               ],
//             ),

//             const SizedBox(height: 16),

//             // Date picker
//             // Row(
//             //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             //   children: [
//             //     Text(
//             //       "Date: ${DateFormat('dd/MM/yyyy').format(_selectedDate)}",
//             //       style: const TextStyle(
//             //         fontSize: 16,
//             //         fontWeight: FontWeight.bold,
//             //         color: Color(0xFF2E3192),
//             //       ),
//             //     ),
//             //     IconButton(
//             //       icon: const Icon(
//             //         Icons.calendar_today,
//             //         color: Color(0xFF2E3192),
//             //       ),
//             //       onPressed: _pickDate,
//             //     ),
//             //   ],
//             // ),
//             const SizedBox(height: 10),

//             // Loader / Error / List
//             Expanded(
//               child: _loading
//                   ? const Center(child: CircularProgressIndicator())
//                   : _error != null
//                   ? Center(child: Text(_error!))
//                   : _notificationsByDate.isEmpty
//                   ? const Center(child: Text("No notifications found."))
//                   : ListView(
//                       children: [
//                         // 🔹 Notifications list
//                         ..._notificationsByDate.entries.map((entry) {
//                           final date = entry.key;
//                           final items = entry.value;

//                           return Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               // Date header
//                               Padding(
//                                 padding: const EdgeInsets.symmetric(
//                                   vertical: 8,
//                                 ),
//                                 child: Text(
//                                   DateFormat(
//                                     'dd/MMM/yyyy',
//                                   ).format(DateTime.parse(date)),
//                                   style: const TextStyle(
//                                     fontSize: 18,
//                                     fontWeight: FontWeight.bold,
//                                     color: Color(0xFF2E3192),
//                                   ),
//                                 ),
//                               ),
//                               ...items.map((item) {
//                                 // Mark as viewed if not already
//                                 if (!_viewedIds.contains(item.id)) {
//                                   _viewedIds.add(item.id);
//                                   _markAsViewed(item.id);
//                                 }

//                                 return Card(
//                                   margin: const EdgeInsets.only(bottom: 12),
//                                   shape: RoundedRectangleBorder(
//                                     borderRadius: BorderRadius.circular(10),
//                                   ),
//                                   elevation: 2,
//                                   child: Padding(
//                                     padding: const EdgeInsets.all(12),
//                                     child: Column(
//                                       crossAxisAlignment:
//                                           CrossAxisAlignment.start,
//                                       children: [
//                                         Row(
//                                           mainAxisAlignment:
//                                               MainAxisAlignment.spaceBetween,
//                                           children: [
//                                             Expanded(
//                                               child: Text(
//                                                 item.type,
//                                                 style: const TextStyle(
//                                                   fontWeight: FontWeight.bold,
//                                                   fontSize: 16,
//                                                   color: Color(0xFF2E3192),
//                                                 ),
//                                                 overflow: TextOverflow.ellipsis,
//                                               ),
//                                             ),
//                                             Text(
//                                               item.moduleType,
//                                               style: const TextStyle(
//                                                 fontSize: 13,
//                                                 fontWeight: FontWeight.w500,
//                                                 color: Colors.black54,
//                                               ),
//                                             ),
//                                           ],
//                                         ),
//                                         const SizedBox(height: 4),
//                                         // Text(
//                                         //   DateFormat(
//                                         //     'HH:mm',
//                                         //   ).format(item.dateTime),
//                                         //   style: const TextStyle(
//                                         //     fontSize: 12,
//                                         //     color: Colors.black54,
//                                         //   ),
//                                         // ),
//                                         const SizedBox(height: 6),
//                                         Text(
//                                           item.title,
//                                           style: const TextStyle(
//                                             fontWeight: FontWeight.bold,
//                                             fontSize: 14,
//                                           ),
//                                         ),
//                                         const SizedBox(height: 4),
//                                         Text(
//                                           item.subtitle,
//                                           style: const TextStyle(
//                                             fontSize: 13,
//                                             color: Colors.grey,
//                                           ),
//                                           maxLines: 2,
//                                           overflow: TextOverflow.ellipsis,
//                                         ),
//                                         const SizedBox(height: 8),
//                                         Align(
//                                           alignment: Alignment.centerRight,
//                                           child: TextButton(
//                                             onPressed: () {
//                                               Navigator.push(
//                                                 context,
//                                                 MaterialPageRoute(
//                                                   builder: (_) =>
//                                                       NotificationRepliesPage(
//                                                         notificationItem:
//                                                             item, // pass the whole notification
//                                                       ),
//                                                 ),
//                                               );
//                                             },
//                                             child: const Text("Reply"),
//                                           ),
//                                         ),
//                                       ],
//                                     ),
//                                   ),
//                                 );
//                               }).toList(),
//                             ],
//                           );
//                         }).toList(),

//                         // 🔹 Load More button at bottom
//                         if (_nextFetchDate != null)
//                           Padding(
//                             padding: const EdgeInsets.all(16),
//                             child: _fetchingMore
//                                 ? const Center(
//                                     child: CircularProgressIndicator(),
//                                   )
//                                 : ElevatedButton(
//                                     onPressed: () =>
//                                         _fetchNotifications(loadMore: true),
//                                     child: const Text(
//                                       "View the notifications from the past 7 days",
//                                     ),
//                                   ),
//                           ),
//                       ],
//                     ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
