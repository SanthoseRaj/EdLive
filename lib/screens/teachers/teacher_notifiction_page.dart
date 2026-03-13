import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:school_app/screens/teachers/teacher_menu_drawer.dart';
import 'package:school_app/widgets/teacher_app_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

import 'todo_list_screen.dart';
import 'teacher_payments_page.dart';
import 'teacher_achivement_page.dart';
import 'teacher_message_page.dart';
import 'teacher_add_library_book_page.dart';

// ----------------- MODEL -----------------
class NotificationItem {
  final int id;
  final String title;
  final String subtitle;
  final String moduleType;
  final DateTime dateTime;
  final String type;

  NotificationItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.moduleType,
    required this.dateTime,
    required this.type,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    final timestampStr = json['timestamp'] ?? json['notification_date'] ?? '';
    final parsedDate = DateTime.tryParse(timestampStr) ?? DateTime.now();

    return NotificationItem(
      id: json['id'],
      title: json['title'] ?? '',
      subtitle: json['content'] ?? '',
      moduleType: json['module_type'] ?? '',
      dateTime: parsedDate,
      type: json['type'] ?? '',
    );
  }
}

// ----------------- PAGE -----------------
class TeacherNotificationPage extends StatefulWidget {
  const TeacherNotificationPage({super.key});

  @override
  State<TeacherNotificationPage> createState() =>
      _TeacherNotificationPageState();
}

class _TeacherNotificationPageState extends State<TeacherNotificationPage> {
  Map<String, List<NotificationItem>> _notificationsByDate = {};
  bool _loading = true;
  bool _fetchingMore = false;
  String? _error;
  DateTime? _nextFetchDate;
  Set<int> _viewedIds = {};

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _markAsViewed(int id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("auth_token");
      if (token == null) return;

      final url =
          "https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api/dashboard/viewed";

      await http.post(
        Uri.parse(url),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: json.encode({"item_type": "notifications", "item_id": id}),
      );
    } catch (e) {
      debugPrint("❌ Error marking notification viewed: $e");
    }
  }

  Future<void> _fetchNotifications({bool loadMore = false}) async {
    try {
      if (loadMore) {
        setState(() => _fetchingMore = true);
      } else {
        setState(() {
          _loading = true;
          _error = null;
          _notificationsByDate.clear();
          _nextFetchDate = DateTime.now();
        });
      }

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("auth_token");
      if (token == null) {
        setState(() {
          _loading = false;
          _fetchingMore = false;
          _error = "No token found, please login again.";
        });
        return;
      }

      final dateToFetch = _nextFetchDate ?? DateTime.now();
      final formattedDate = DateFormat('yyyy-MM-dd').format(dateToFetch);

      final url =
          "https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api/dashboard/daily-notifications?date=$formattedDate";

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
      if (data['success'] != true) throw Exception("API returned error");

      final notificationsData =
          data['notifications']['notifications'] as Map<String, dynamic>? ?? {};

      bool hasData = false;
      notificationsData.forEach((dateStr, list) {
        final List items = list as List;
        if (items.isNotEmpty) {
          hasData = true;
          _notificationsByDate.putIfAbsent(dateStr, () => []);
          _notificationsByDate[dateStr]!.addAll(
            items.map((e) => NotificationItem.fromJson(e)).toList(),
          );
        }
      });

      final periodStart = data['notifications']['period_start'];
      if (periodStart != null && periodStart.isNotEmpty) {
        DateTime prevStart = DateTime.parse(periodStart);
        _nextFetchDate = prevStart.subtract(const Duration(days: 1));
      } else {
        _nextFetchDate = null;
      }

      _notificationsByDate.forEach(
        (key, value) => value.sort((a, b) => b.dateTime.compareTo(a.dateTime)),
      );

      final sortedGrouped = Map.fromEntries(
        _notificationsByDate.entries.toList()
          ..sort((a, b) => b.key.compareTo(a.key)),
      );

      setState(() {
        _notificationsByDate = sortedGrouped;
        _loading = false;
        _fetchingMore = false;
      });

      if (!hasData && _nextFetchDate != null) {
        await _fetchNotifications(loadMore: true);
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _fetchingMore = false;
        _error = "Something went wrong: $e";
      });
    }
  }

  // Navigate based on notification type
void _navigateToModule(NotificationItem item) {
  switch (item.moduleType.toLowerCase()) {
    case 'todo':
    case 'to-do':
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ToDoListPage()),
      );
      break;

    case 'payments':
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const TeacherPaymentsPage()),
      );
      break;

    // ✅ Achievements module
    case 'achievement':
    case 'achievements':
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const TeacherAchievementPage()),
      );
      break;

    // ✅ Library module
    case 'library':
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AddLibraryBookPage()),
      );
      break;

    // ✅ Message module
    case 'message':
    case 'messages':
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const TeacherMessagePage()),
      );
      break;

    default:
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No linked page for ${item.moduleType}")),
      );
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TeacherAppBar(),
      drawer: const MenuDrawer(),
      backgroundColor: const Color(0xFFF9F7A5),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Text(
                "< Back",
                style: TextStyle(color: Colors.black, fontSize: 16),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  height: 40,
                  width: 40,
                  decoration: const BoxDecoration(color: Color(0xFF2E3192)),
                  padding: const EdgeInsets.all(8),
                  child: SvgPicture.asset(
                    'assets/icons/notification.svg',
                    color: Colors.white,
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
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!))
                      : _notificationsByDate.isEmpty
                          ? const Center(
                              child: Text("No notifications found."),
                            )
                          : ListView(
                              children: [
                                ..._notificationsByDate.entries.map((entry) {
                                  final date = entry.key;
                                  final items = entry.value;

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        child: Text(
                                          DateFormat('dd/MMM/yyyy')
                                              .format(DateTime.parse(date)),
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF2E3192),
                                          ),
                                        ),
                                      ),
                                      ...items.map((item) {
                                        if (!_viewedIds.contains(item.id)) {
                                          _viewedIds.add(item.id);
                                          _markAsViewed(item.id);
                                        }

                                        return GestureDetector(
                                          onTap: () =>
                                              _navigateToModule(item),
                                          child: Card(
                                            margin: const EdgeInsets.only(
                                                bottom: 12),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            elevation: 2,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.all(12),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          item.type,
                                                          style:
                                                              const TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 16,
                                                            color: Color(
                                                                0xFF2E3192),
                                                          ),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                      Text(
                                                        item.moduleType,
                                                        style: const TextStyle(
                                                          fontSize: 13,
                                                          color: Colors.black54,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    item.title,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
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
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ],
                                  );
                                }).toList(),
                                if (_nextFetchDate != null)
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: _fetchingMore
                                        ? const Center(
                                            child:
                                                CircularProgressIndicator(),
                                          )
                                        : ElevatedButton(
                                            onPressed: () =>
                                                _fetchNotifications(
                                                    loadMore: true),
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


// ----------------- Reply Msg DETAIL PAGE -----------------
// class TeacherNotificationDetailPage extends StatefulWidget {
//   final NotificationItem item;

//   TeacherNotificationDetailPage({super.key, required this.item});

//   @override
//   State<TeacherNotificationDetailPage> createState() =>
//       _TeacherNotificationDetailPageState();
// }

// class _TeacherNotificationDetailPageState
//     extends State<TeacherNotificationDetailPage> {
//   final TextEditingController _msgController = TextEditingController();
//   List<NotificationReply> _replies = [];
//   bool _loadingReplies = true;
//   String? _replyError;

//   final NotificationService _service = NotificationService();

//   @override
//   void initState() {
//     super.initState();
//     _fetchReplies();
//   }

//   Future<void> _fetchReplies() async {
//     setState(() {
//       _loadingReplies = true;
//       _replyError = null;
//     });

//     try {
//       final replies = await _service.fetchReplies(
//         itemId: widget.item.id,
//         itemType: widget.item.moduleType,
//       );
//       setState(() {
//         _replies = replies;
//         _loadingReplies = false;
//       });
//     } catch (e) {
//       setState(() {
//         _replyError = e.toString();
//         _loadingReplies = false;
//       });
//     }
//   }

//   List<NotificationReply> _flattenReplies(List<NotificationReply> replies) {
//     List<NotificationReply> list = [];
//     for (var r in replies) {
//       list.add(r);
//       if (r.replies.isNotEmpty) {
//         list.addAll(_flattenReplies(r.replies));
//       }
//     }
//     return list;
//   }

//   @override
//   Widget build(BuildContext context) {
//     final flattenedReplies = _flattenReplies(_replies);

//     return Scaffold(
//       appBar: TeacherAppBar(),
//       drawer: const MenuDrawer(),
//       backgroundColor: const Color(0xFFF9F7A5),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Top-left Back button
//             GestureDetector(
//               onTap: () => Navigator.pop(context),
//               child: const Padding(
//                 padding: EdgeInsets.only(top: 5.0, left: 5.0),
//                 child: Text(
//                   "< Back",
//                   style: TextStyle(color: Colors.black, fontSize: 15),
//                 ),
//               ),
//             ),
//             const SizedBox(height: 12),

//             // Title + Notification icon
//             Row(
//               crossAxisAlignment: CrossAxisAlignment.center,
//               children: [
//                 // Notification icon
//                 Container(
//                   padding: const EdgeInsets.all(8),
//                   decoration: const BoxDecoration(color: Color(0xFF2E3192)),
//                   child: SvgPicture.asset(
//                     'assets/icons/notification.svg',
//                     height: 20,
//                     width: 20,
//                     color: Colors.white,
//                   ),
//                 ),
//                 const SizedBox(width: 8),

//                 // Title
//                 const Text(
//                   "Notification Details",
//                   style: TextStyle(
//                     fontSize: 26,
//                     fontWeight: FontWeight.bold,
//                     color: Color(0xFF2E3192),
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 12),
//             Expanded(
//               child: Container(
//                 decoration: BoxDecoration(
//                   color: Colors.white,
//                   borderRadius: BorderRadius.circular(16),
//                   boxShadow: const [
//                     BoxShadow(
//                       color: Colors.black12,
//                       blurRadius: 6,
//                       offset: Offset(0, 3),
//                     ),
//                   ],
//                 ),
//                 padding: const EdgeInsets.all(16),
//                 child: Column(
//                   children: [
//                     Container(
//                       height: 150, // 👈 Fixed height for container
//                       padding: const EdgeInsets.all(12),
//                       decoration: BoxDecoration(
//                         color: const Color(0xFFF1F1F1),
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                       child: SingleChildScrollView(
//                         // 👈 Makes inner content scrollable
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               widget.item.title,
//                               style: const TextStyle(
//                                 fontSize: 18,
//                                 fontWeight: FontWeight.bold,
//                                 color: Color(0xFF2E3192),
//                               ),
//                             ),
//                             const SizedBox(height: 6),
//                             Text(
//                               widget.item.subtitle,
//                               style: const TextStyle(
//                                 fontSize: 14,
//                                 color: Colors.black87,
//                               ),
//                             ),
//                             const SizedBox(height: 6),
//                             Text(
//                               "${widget.item.moduleType} • ${widget.item.type}",
//                               style: const TextStyle(
//                                 fontSize: 13,
//                                 color: Colors.black54,
//                               ),
//                             ),
//                             const SizedBox(height: 4),
//                             Text(
//                               DateFormat(
//                                 // 'dd/MMM/yyyy hh:mm a',
//                               ).format(widget.item.dateTime),
//                               style: const TextStyle(
//                                 fontSize: 12,
//                                 color: Colors.black45,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),

//                     const Divider(),
//                     Expanded(
//                       child: _loadingReplies
//                           ? const Center(child: CircularProgressIndicator())
//                           : _replyError != null
//                           ? Center(child: Text(_replyError!))
//                           : flattenedReplies.isEmpty
//                           ? const Center(child: Text("No replies yet"))
//                           : ListView.builder(
//                               itemCount: flattenedReplies.length,
//                               itemBuilder: (context, index) {
//                                 final reply = flattenedReplies[index];
//                                 final isTeacher = reply.senderType == 'Teacher';

//                                 return Align(
//                                   alignment: isTeacher
//                                       ? Alignment.centerRight
//                                       : Alignment.centerLeft,
//                                   child: Container(
//                                     margin: const EdgeInsets.symmetric(
//                                       vertical: 4,
//                                       horizontal: 8,
//                                     ),
//                                     padding: const EdgeInsets.all(10),
//                                     decoration: BoxDecoration(
//                                       color: isTeacher
//                                           ? const Color(0xFF2E3192)
//                                           : Colors.grey[300],
//                                       borderRadius: BorderRadius.circular(12),
//                                     ),
//                                     child: Column(
//                                       crossAxisAlignment:
//                                           CrossAxisAlignment.start,
//                                       children: [
//                                         Text(
//                                           reply.messageText,
//                                           style: TextStyle(
//                                             color: isTeacher
//                                                 ? Colors.white
//                                                 : Colors.black87,
//                                           ),
//                                         ),
//                                         const SizedBox(height: 2),
//                                         Text(
//                                           "${reply.senderName} • ${DateFormat('dd/MMM/yyyy hh:mm a').format(reply.createdAt)}",
//                                           style: TextStyle(
//                                             fontSize: 11,
//                                             color: isTeacher
//                                                 ? Colors.white70
//                                                 : Colors.black54,
//                                           ),
//                                         ),
//                                       ],
//                                     ),
//                                   ),
//                                 );
//                               },
//                             ),
//                     ),
//                     Row(
//                       children: [
//                         Expanded(
//                           child: TextField(
//                             controller: _msgController,
//                             decoration: InputDecoration(
//                               hintText: "Write a reply...",
//                               contentPadding: const EdgeInsets.symmetric(
//                                 horizontal: 12,
//                                 vertical: 8,
//                               ),
//                               border: OutlineInputBorder(
//                                 borderRadius: BorderRadius.circular(20),
//                               ),
//                             ),
//                           ),
//                         ),
//                         const SizedBox(width: 8),
//                         ElevatedButton(
//                           onPressed: () async {
//                             if (_msgController.text.trim().isEmpty) return;
//                             await _service.sendReply(
//                               itemId: widget.item.id,
//                               itemType: widget.item.moduleType,
//                               message: _msgController.text.trim(),
//                             );
//                             _msgController.clear();
//                             _fetchReplies();
//                           },
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: const Color(0xFF2E3192),
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(20),
//                             ),
//                             padding: const EdgeInsets.symmetric(
//                               horizontal: 16,
//                               vertical: 12,
//                             ),
//                           ),
//                           child: const Icon(Icons.send, color: Colors.white),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }





//Old Reply page code


// import 'package:flutter/material.dart';
// import 'package:flutter_svg/flutter_svg.dart';
// import 'package:school_app/screens/teachers/teacher_menu_drawer.dart';
// import 'package:school_app/widgets/teacher_app_bar.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
// import 'package:intl/intl.dart';
// import 'package:school_app/services/teacher_notification_service.dart';
// import 'package:school_app/models/teacher_notification_reply_model.dart';

// // ----------------- MODEL -----------------
// class NotificationItem {
//   final int id;
//   final String title;
//   final String subtitle;
//   final String moduleType;
//   final DateTime dateTime;
//   final String type;

//   NotificationItem({
//     required this.id,
//     required this.title,
//     required this.subtitle,
//     required this.moduleType,
//     required this.dateTime,
//     required this.type,
//   });

//   factory NotificationItem.fromJson(Map<String, dynamic> json) {
//     // Prefer timestamp for accurate time display
//     final timestampStr = json['timestamp'] ?? json['notification_date'] ?? '';
//     final parsedDate = DateTime.tryParse(timestampStr) ?? DateTime.now();

//     return NotificationItem(
//       id: json['id'],
//       title: json['title'] ?? '',
//       subtitle: json['content'] ?? '',
//       moduleType: json['module_type'] ?? '',
//       dateTime: parsedDate,
//       type: json['type'] ?? '',
//     );
//   }
// }

// // ----------------- PAGE -----------------
// class TeacherNotificationPage extends StatefulWidget {
//   const TeacherNotificationPage({super.key});

//   @override
//   State<TeacherNotificationPage> createState() =>
//       _TeacherNotificationPageState();
// }

// class _TeacherNotificationPageState extends State<TeacherNotificationPage> {
//   Map<String, List<NotificationItem>> _notificationsByDate = {};
//   bool _loading = true;
//   bool _fetchingMore = false;
//   String? _error;
//   DateTime? _nextFetchDate;
//   Set<int> _viewedIds = {};

//   Map<int, bool> _hasReplies = {};
//   Map<int, bool> _hasUnreadReplies = {}; // for red dot
//   Map<int, int> _unreadReplyCount = {}; // store count of new replies
//   // Map<int, int> _unreadReplyCount = {}; // how many unread replies
//   Map<int, bool> _hasReadReplies = {}; // has the teacher already read it

//   @override
//   void initState() {
//     super.initState();
//     _fetchNotifications();
//   }

//   Future<void> _checkReplies(int itemId, String itemType) async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final savedReadIds = prefs.getStringList('readReplies_$itemId') ?? [];

//       final replies = await NotificationService().fetchReplies(
//         itemId: itemId,
//         itemType: itemType,
//       );

//       // Flatten all nested replies
//       List<NotificationReply> flatten(List<NotificationReply> list) {
//         List<NotificationReply> all = [];
//         for (var r in list) {
//           all.add(r);
//           if (r.replies.isNotEmpty) {
//             all.addAll(flatten(r.replies));
//           }
//         }
//         return all;
//       }

//       final allReplies = flatten(replies);

//       // Count replies not by teacher + not read
//       int unreadCount = allReplies
//           .where(
//             (r) =>
//                 r.senderType != "Teacher" &&
//                 !savedReadIds.contains(r.id.toString()),
//           )
//           .length;

//       if (mounted) {
//         setState(() {
//           _unreadReplyCount[itemId] = unreadCount;
//         });
//       }
//     } catch (e) {
//       debugPrint("⚠️ Error checking replies for $itemId: $e");
//     }
//   }

//   Future<void> _markAsViewed(int id) async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final token = prefs.getString("auth_token");
//       if (token == null) return;

//       final url =
//           "https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api/dashboard/viewed";

//       await http.post(
//         Uri.parse(url),
//         headers: {
//           "Authorization": "Bearer $token",
//           "Content-Type": "application/json",
//         },
//         body: json.encode({"item_type": "notifications", "item_id": id}),
//       );

//       debugPrint("✅ Marked notification $id as viewed");
//     } catch (e) {
//       debugPrint("❌ Error marking notification viewed: $e");
//     }
//   }

//   Future<void> _fetchNotifications({bool loadMore = false}) async {
//     try {
//       if (loadMore) {
//         setState(() => _fetchingMore = true);
//       } else {
//         setState(() {
//           _loading = true;
//           _error = null;
//           _notificationsByDate.clear();
//           _nextFetchDate = DateTime.now();
//         });
//       }

//       final prefs = await SharedPreferences.getInstance();
//       final token = prefs.getString("auth_token");
//       if (token == null) {
//         setState(() {
//           _loading = false;
//           _fetchingMore = false;
//           _error = "No token found, please login again.";
//         });
//         return;
//       }

//       // Use _nextFetchDate or today if null
//       final dateToFetch = _nextFetchDate ?? DateTime.now();
//       final formattedDate = DateFormat('yyyy-MM-dd').format(dateToFetch);

//       final url =
//           "https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api/dashboard/daily-notifications?date=$formattedDate";

//       final response = await http.get(
//         Uri.parse(url),
//         headers: {
//           "Authorization": "Bearer $token",
//           "Content-Type": "application/json",
//         },
//       );

//       if (response.statusCode != 200)
//         throw Exception("Failed to fetch notifications");

//       final data = json.decode(response.body);
//       if (data['success'] != true) throw Exception("API returned error");

//       final notificationsData =
//           data['notifications']['notifications'] as Map<String, dynamic>? ?? {};

//       bool hasData = false;
//       notificationsData.forEach((dateStr, list) {
//         final List items = list as List;
//         if (items.isNotEmpty) {
//           hasData = true;
//           _notificationsByDate.putIfAbsent(dateStr, () => []);
//           _notificationsByDate[dateStr]!.addAll(
//             items.map((e) => NotificationItem.fromJson(e)).toList(),
//           );
//         }
//       });

//       // Prepare next fetch date (for previous 7 days)
//       final periodStart = data['notifications']['period_start'];
//       if (periodStart != null && periodStart.isNotEmpty) {
//         DateTime prevStart = DateTime.parse(periodStart);
//         _nextFetchDate = prevStart.subtract(const Duration(days: 1));
//       } else {
//         _nextFetchDate = null;
//       }

//       // Sort notifications
//       _notificationsByDate.forEach(
//         (key, value) => value.sort((a, b) => b.dateTime.compareTo(a.dateTime)),
//       );

//       final sortedGrouped = Map.fromEntries(
//         _notificationsByDate.entries.toList()
//           ..sort((a, b) => b.key.compareTo(a.key)),
//       );

//       setState(() {
//         _notificationsByDate = sortedGrouped;
//         _loading = false;
//         _fetchingMore = false;
//       });

//       for (var entry in _notificationsByDate.entries) {
//         for (var item in entry.value) {
//           _checkReplies(item.id, item.moduleType);
//         }
//       }

//       // 🔁 Auto-fetch previous week if current response empty but more dates exist
//       if (!hasData && _nextFetchDate != null) {
//         debugPrint(
//           "⚠️ No notifications for ${formattedDate}. Fetching previous week from ${_nextFetchDate}...",
//         );
//         await _fetchNotifications(loadMore: true);
//       }
//     } catch (e) {
//       setState(() {
//         _loading = false;
//         _fetchingMore = false;
//         _error = "Something went wrong: $e";
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: TeacherAppBar(),
//       drawer: const MenuDrawer(),
//       backgroundColor: const Color(0xFFF9F7A5),
//       body: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             GestureDetector(
//               onTap: () => Navigator.pop(context),
//               child: const Text(
//                 "< Back",
//                 style: TextStyle(color: Colors.black, fontSize: 16),
//               ),
//             ),
//             const SizedBox(height: 12),
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
//             Expanded(
//               child: _loading
//                   ? const Center(child: CircularProgressIndicator())
//                   : _error != null
//                   ? Center(child: Text(_error!))
//                   : _notificationsByDate.isEmpty
//                   ? const Center(child: Text("No notifications found."))
//                   : ListView(
//                       children: [
//                         ..._notificationsByDate.entries.map((entry) {
//                           final date = entry.key;
//                           final items = entry.value;

//                           return Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
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
//                                                 color: Colors.black54,
//                                               ),
//                                             ),
//                                           ],
//                                         ),
//                                         const SizedBox(height: 2),
//                                         // Text(
//                                         //   DateFormat(
//                                         //     // 'hh:mm a',
//                                         //   ).format(item.dateTime),
//                                         //   style: const TextStyle(
//                                         //     fontSize: 12,
//                                         //     color: Colors.black54,
//                                         //   ),
//                                         // ),
//                                         const SizedBox(height: 4),
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
//                                           child: Stack(
//                                             clipBehavior: Clip.none,
//                                             children: [
//                                               TextButton(
//                                                 onPressed: () async {
//                                                   await Navigator.push(
//                                                     context,
//                                                     MaterialPageRoute(
//                                                       builder: (_) =>
//                                                           TeacherNotificationDetailPage(
//                                                             item: item,
//                                                           ),
//                                                     ),
//                                                   );

//                                                   // After coming back → mark as read locally
//                                                   final prefs =
//                                                       await SharedPreferences.getInstance();
//                                                   final replies =
//                                                       await NotificationService()
//                                                           .fetchReplies(
//                                                             itemId: item.id,
//                                                             itemType:
//                                                                 item.moduleType,
//                                                           );

//                                                   // Flatten and store all reply IDs as read
//                                                   List<int> allIds = [];
//                                                   void flatten(
//                                                     List<NotificationReply>
//                                                     list,
//                                                   ) {
//                                                     for (var r in list) {
//                                                       allIds.add(r.id);
//                                                       if (r.replies.isNotEmpty)
//                                                         flatten(r.replies);
//                                                     }
//                                                   }

//                                                   flatten(replies);

//                                                   prefs.setStringList(
//                                                     'readReplies_${item.id}',
//                                                     allIds
//                                                         .map(
//                                                           (e) => e.toString(),
//                                                         )
//                                                         .toList(),
//                                                   );

//                                                   // Hide red dot
//                                                   setState(() {
//                                                     _unreadReplyCount[item.id] =
//                                                         0;
//                                                   });
//                                                 },
//                                                 child: const Text("Reply"),
//                                               ),

//                                               // 🔴 Show reply count inside red circle
//                                               if ((_unreadReplyCount[item.id] ??
//                                                       0) >
//                                                   0)
//                                                 Positioned(
//                                                   right: -6,
//                                                   top: -4,
//                                                   child: Container(
//                                                     padding:
//                                                         const EdgeInsets.all(4),
//                                                     decoration:
//                                                         const BoxDecoration(
//                                                           color: Colors.red,
//                                                           shape:
//                                                               BoxShape.circle,
//                                                         ),
//                                                     constraints:
//                                                         const BoxConstraints(
//                                                           minWidth: 18,
//                                                           minHeight: 18,
//                                                         ),
//                                                     child: Center(
//                                                       child: Text(
//                                                         '${_unreadReplyCount[item.id]}',
//                                                         style: const TextStyle(
//                                                           color: Colors.white,
//                                                           fontSize: 11,
//                                                           fontWeight:
//                                                               FontWeight.bold,
//                                                         ),
//                                                       ),
//                                                     ),
//                                                   ),
//                                                 ),
//                                             ],
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
//                                       "View Past Notifications",
//                                     ),

//                                     // child: const Text("Load previous notifications"),
//                                     // View the notifications from the past 7 days
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

// // ----------------- DETAIL PAGE -----------------
// class TeacherNotificationDetailPage extends StatefulWidget {
//   final NotificationItem item;

//   TeacherNotificationDetailPage({super.key, required this.item});

//   @override
//   State<TeacherNotificationDetailPage> createState() =>
//       _TeacherNotificationDetailPageState();
// }

// class _TeacherNotificationDetailPageState
//     extends State<TeacherNotificationDetailPage> {
//   final TextEditingController _msgController = TextEditingController();
//   List<NotificationReply> _replies = [];
//   bool _loadingReplies = true;
//   String? _replyError;

//   final NotificationService _service = NotificationService();

//   @override
//   void initState() {
//     super.initState();
//     _fetchReplies();
//   }

//   Future<void> _fetchReplies() async {
//     setState(() {
//       _loadingReplies = true;
//       _replyError = null;
//     });

//     try {
//       final replies = await _service.fetchReplies(
//         itemId: widget.item.id,
//         itemType: widget.item.moduleType,
//       );
//       setState(() {
//         _replies = replies;
//         _loadingReplies = false;
//       });
//     } catch (e) {
//       setState(() {
//         _replyError = e.toString();
//         _loadingReplies = false;
//       });
//     }
//   }

//   List<NotificationReply> _flattenReplies(List<NotificationReply> replies) {
//     List<NotificationReply> list = [];
//     for (var r in replies) {
//       list.add(r);
//       if (r.replies.isNotEmpty) {
//         list.addAll(_flattenReplies(r.replies));
//       }
//     }
//     return list;
//   }

//   @override
//   Widget build(BuildContext context) {
//     final flattenedReplies = _flattenReplies(_replies);

//     return Scaffold(
//       appBar: TeacherAppBar(),
//       drawer: const MenuDrawer(),
//       backgroundColor: const Color(0xFFF9F7A5),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Top-left Back button
//             GestureDetector(
//               onTap: () => Navigator.pop(context),
//               child: const Padding(
//                 padding: EdgeInsets.only(top: 5.0, left: 5.0),
//                 child: Text(
//                   "< Back",
//                   style: TextStyle(color: Colors.black, fontSize: 15),
//                 ),
//               ),
//             ),
//             const SizedBox(height: 12),

//             // Title + Notification icon
//             Row(
//               crossAxisAlignment: CrossAxisAlignment.center,
//               children: [
//                 // Notification icon
//                 Container(
//                   padding: const EdgeInsets.all(8),
//                   decoration: const BoxDecoration(color: Color(0xFF2E3192)),
//                   child: SvgPicture.asset(
//                     'assets/icons/notification.svg',
//                     height: 20,
//                     width: 20,
//                     color: Colors.white,
//                   ),
//                 ),
//                 const SizedBox(width: 8),

//                 // Title
//                 const Text(
//                   "Notification Details",
//                   style: TextStyle(
//                     fontSize: 26,
//                     fontWeight: FontWeight.bold,
//                     color: Color(0xFF2E3192),
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 12),
//             Expanded(
//               child: Container(
//                 decoration: BoxDecoration(
//                   color: Colors.white,
//                   borderRadius: BorderRadius.circular(16),
//                   boxShadow: const [
//                     BoxShadow(
//                       color: Colors.black12,
//                       blurRadius: 6,
//                       offset: Offset(0, 3),
//                     ),
//                   ],
//                 ),
//                 padding: const EdgeInsets.all(16),
//                 child: Column(
//                   children: [
//                     Container(
//                       height: 150, // 👈 Fixed height for container
//                       padding: const EdgeInsets.all(12),
//                       decoration: BoxDecoration(
//                         color: const Color(0xFFF1F1F1),
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                       child: SingleChildScrollView(
//                         // 👈 Makes inner content scrollable
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               widget.item.title,
//                               style: const TextStyle(
//                                 fontSize: 18,
//                                 fontWeight: FontWeight.bold,
//                                 color: Color(0xFF2E3192),
//                               ),
//                             ),
//                             const SizedBox(height: 6),
//                             Text(
//                               widget.item.subtitle,
//                               style: const TextStyle(
//                                 fontSize: 14,
//                                 color: Colors.black87,
//                               ),
//                             ),
//                             const SizedBox(height: 6),
//                             Text(
//                               "${widget.item.moduleType} • ${widget.item.type}",
//                               style: const TextStyle(
//                                 fontSize: 13,
//                                 color: Colors.black54,
//                               ),
//                             ),
//                             const SizedBox(height: 4),
//                             Text(
//                               DateFormat(
//                                 // 'dd/MMM/yyyy hh:mm a',
//                               ).format(widget.item.dateTime),
//                               style: const TextStyle(
//                                 fontSize: 12,
//                                 color: Colors.black45,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),

//                     const Divider(),
//                     Expanded(
//                       child: _loadingReplies
//                           ? const Center(child: CircularProgressIndicator())
//                           : _replyError != null
//                           ? Center(child: Text(_replyError!))
//                           : flattenedReplies.isEmpty
//                           ? const Center(child: Text("No replies yet"))
//                           : ListView.builder(
//                               itemCount: flattenedReplies.length,
//                               itemBuilder: (context, index) {
//                                 final reply = flattenedReplies[index];
//                                 final isTeacher = reply.senderType == 'Teacher';

//                                 return Align(
//                                   alignment: isTeacher
//                                       ? Alignment.centerRight
//                                       : Alignment.centerLeft,
//                                   child: Container(
//                                     margin: const EdgeInsets.symmetric(
//                                       vertical: 4,
//                                       horizontal: 8,
//                                     ),
//                                     padding: const EdgeInsets.all(10),
//                                     decoration: BoxDecoration(
//                                       color: isTeacher
//                                           ? const Color(0xFF2E3192)
//                                           : Colors.grey[300],
//                                       borderRadius: BorderRadius.circular(12),
//                                     ),
//                                     child: Column(
//                                       crossAxisAlignment:
//                                           CrossAxisAlignment.start,
//                                       children: [
//                                         Text(
//                                           reply.messageText,
//                                           style: TextStyle(
//                                             color: isTeacher
//                                                 ? Colors.white
//                                                 : Colors.black87,
//                                           ),
//                                         ),
//                                         const SizedBox(height: 2),
//                                         Text(
//                                           "${reply.senderName} • ${DateFormat('dd/MMM/yyyy hh:mm a').format(reply.createdAt)}",
//                                           style: TextStyle(
//                                             fontSize: 11,
//                                             color: isTeacher
//                                                 ? Colors.white70
//                                                 : Colors.black54,
//                                           ),
//                                         ),
//                                       ],
//                                     ),
//                                   ),
//                                 );
//                               },
//                             ),
//                     ),
//                     Row(
//                       children: [
//                         Expanded(
//                           child: TextField(
//                             controller: _msgController,
//                             decoration: InputDecoration(
//                               hintText: "Write a reply...",
//                               contentPadding: const EdgeInsets.symmetric(
//                                 horizontal: 12,
//                                 vertical: 8,
//                               ),
//                               border: OutlineInputBorder(
//                                 borderRadius: BorderRadius.circular(20),
//                               ),
//                             ),
//                           ),
//                         ),
//                         const SizedBox(width: 8),
//                         ElevatedButton(
//                           onPressed: () async {
//                             if (_msgController.text.trim().isEmpty) return;
//                             await _service.sendReply(
//                               itemId: widget.item.id,
//                               itemType: widget.item.moduleType,
//                               message: _msgController.text.trim(),
//                             );
//                             _msgController.clear();
//                             _fetchReplies();
//                           },
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: const Color(0xFF2E3192),
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(20),
//                             ),
//                             padding: const EdgeInsets.symmetric(
//                               horizontal: 16,
//                               vertical: 12,
//                             ),
//                           ),
//                           child: const Icon(Icons.send, color: Colors.white),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
