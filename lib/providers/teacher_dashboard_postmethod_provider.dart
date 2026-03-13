// // lib/providers/teacher_dashboard_postmethod_provider.dart
// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:shared_preferences/shared_preferences.dart';

// class DashboardCounts {
//   final int notifications;
//   final int todo;
//   final int payments;
//   final int messages;
//   final int library;
//   final int achievements;

//   DashboardCounts({
//     required this.notifications,
//     required this.todo,
//     required this.payments,
//     required this.messages,
//     required this.library,
//     required this.achievements,
//   });

//   factory DashboardCounts.fromJson(Map<String, dynamic> json) {
//     return DashboardCounts(
//       notifications: json['notifications'] ?? 0,
//       todo: json['todo'] ?? 0,
//       payments: json['payments'] ?? 0,
//       messages: json['messages'] ?? 0,
//       library: json['library'] ?? 0,
//       achievements: json['achievements'] ?? 0,
//     );
//   }
// }

// class DashboardProvider with ChangeNotifier {
//   DashboardCounts? counts;
//   bool isLoading = false;

//   // track unread items
//   Map<String, bool> unreadMap = {
//     "notifications": true,
//     "todo": true,
//     "payments": true,
//     "messages": true,
//     "library": true,
//     "achievements": true,
//   };

//   Future<String?> _getToken() async {
//     final prefs = await SharedPreferences.getInstance();
//     return prefs.getString("auth_token");
//   }

//   Future<void> fetchCounts() async {
//     isLoading = true;
//     notifyListeners();

//     final token = await _getToken();
//     if (token == null) return;

//     final url = Uri.parse(
//         "https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api/dashboard/counts");

//     try {
//       final res = await http.get(url, headers: {
//         "Authorization": "Bearer $token",
//       });

//       if (res.statusCode == 200) {
//         final data = json.decode(res.body);
//         counts = DashboardCounts.fromJson(data);
//       }
//     } catch (e) {
//       debugPrint("Error fetching dashboard counts: $e");
//     }

//     isLoading = false;
//     notifyListeners();
//   }

//   Future<void> markAsViewed(String itemType, int itemId) async {
//     final token = await _getToken();
//     if (token == null) return;

//     final url = Uri.parse(
//         "https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api/dashboard/viewed");

//     try {
//       final res = await http.post(
//         url,
//         headers: {
//           "Authorization": "Bearer $token",
//           "Content-Type": "application/json",
//         },
//         body: json.encode({
//           "item_type": itemType,
//           "item_id": itemId,
//         }),
//       );

//       if (res.statusCode == 200) {
//         // mark as read (unbold)
//         unreadMap[itemType] = false;
//         notifyListeners();
//       }
//     } catch (e) {
//       debugPrint("Error marking item viewed: $e");
//     }
//   }
// }
