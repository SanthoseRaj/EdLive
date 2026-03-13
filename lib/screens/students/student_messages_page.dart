import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:school_app/screens/students/student_menu_drawer.dart';
import 'package:school_app/widgets/student_app_bar.dart';
import 'dart:async';

/// ---------------- MODEL ----------------
class StudentMessage {
  final int id;
  final int studentId;
  final String senderName;
  final String messageText;
  final String messageType;
  final bool isAppreciation;
  final bool isMeetingRequest;
  final DateTime createdAt;

  StudentMessage({
    required this.id,
    required this.studentId,
    required this.senderName,
    required this.messageText,
    required this.messageType,
    required this.isAppreciation,
    required this.isMeetingRequest,
    required this.createdAt,
  });

  factory StudentMessage.fromJson(Map<String, dynamic> json) {
    return StudentMessage(
      id: json['id'],
      studentId: json['student_id'],
      senderName: json['sender_name'] ?? 'Unknown',
      messageText: json['message_text'] ?? '',
      messageType: json['message_type'] ?? '',
      isAppreciation: json['is_appreciation'] ?? false,
      isMeetingRequest: json['is_meeting_request'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

/// ---------------- SERVICE ----------------
class MessageService {
  static const String baseUrl =
      "https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api";

  static Future<List<StudentMessage>> fetchMessages(int studentId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("auth_token");

    final response = await http.get(
      Uri.parse("$baseUrl/messages/$studentId"),
      headers: {"Authorization": "Bearer $token"},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => StudentMessage.fromJson(json)).toList();
    } else {
      throw Exception("Failed to load messages");
    }
  }

  static Future<void> markMessageViewed(int studentId, int messageId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("auth_token");

    await http.post(
      Uri.parse("$baseUrl/dashboard/viewed?studentId=$studentId"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode({"item_type": "messages", "item_id": messageId}),
    );
  }
}

/// ---------------- UI PAGE ----------------
class StudentMessagesPage extends StatefulWidget {
  final int studentId;
  const StudentMessagesPage({Key? key, required this.studentId})
    : super(key: key);

  @override
  State<StudentMessagesPage> createState() => _StudentMessagesPageState();
}

class _StudentMessagesPageState extends State<StudentMessagesPage> {
  late Future<List<StudentMessage>> _messagesFuture;
  StudentMessage? _selectedMessage;
  Timer? _timer;
  List<StudentMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _messagesFuture = _loadMessages();
    _messagesFuture.then((msgs) => _messages = msgs);

    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted && _selectedMessage == null) {
        _refreshMessages();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<List<StudentMessage>> _loadMessages() async {
    final messages = await MessageService.fetchMessages(widget.studentId);

    // Mark all as viewed
    for (var msg in messages) {
      await MessageService.markMessageViewed(widget.studentId, msg.id);
    }

    return messages;
  }

  void _refreshMessages() async {
    final latestMessages = await MessageService.fetchMessages(widget.studentId);

    // Check if there are new messages
    bool hasNew = false;

    if (latestMessages.length != _messages.length) {
      hasNew = true;
    } else {
      // Compare IDs
      for (int i = 0; i < latestMessages.length; i++) {
        if (latestMessages[i].id != _messages[i].id) {
          hasNew = true;
          break;
        }
      }
    }

    if (hasNew) {
      // Mark new messages as viewed
      for (var msg in latestMessages) {
        if (!_messages.any((m) => m.id == msg.id)) {
          await MessageService.markMessageViewed(widget.studentId, msg.id);
        }
      }

      // Update UI only if there are new messages
      setState(() {
        _messages = latestMessages;
        _messagesFuture = Future.value(_messages);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: StudentAppBar(),
      drawer: StudentMenuDrawer(),
      backgroundColor: const Color(0xFFA3D3A7),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: GestureDetector(
              onTap: () {
                if (_selectedMessage != null) {
                  setState(() => _selectedMessage = null); // back to list
                } else {
                  Navigator.pop(context);
                }
              },
              child: const Text(
                "< Back",
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 4.0,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(color: Color(0xFF2E3192)),
                  child: SvgPicture.asset(
                    "assets/icons/message.svg",
                    height: 20,
                    width: 20,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  "Messages",
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E3192),
                  ),
                ),
              ],
            ),
          ),

          // List OR Detail
          Expanded(
            child: FutureBuilder<List<StudentMessage>>(
              future: _messagesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text("No messages found"));
                }

                final messages = snapshot.data!;

                // 🔹 DETAIL VIEW
                if (_selectedMessage != null) {
                  final msg = _selectedMessage!;
                  return Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Sender
                          SizedBox(
                            width: double.infinity,
                            child: Text(
                              msg.senderName,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2E3192),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Date
                          SizedBox(
                            width: double.infinity,
                            child: Text(
                              "${msg.createdAt.toLocal()}".split(" ")[0],
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Message text
                          SizedBox(
                            width: double.infinity,
                            child: Text(
                              msg.messageText,
                              style: const TextStyle(fontSize: 16, height: 1.5),
                              softWrap: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // 🔹 LIST VIEW
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedMessage = msg;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Icon
                           Container(
  padding: const EdgeInsets.all(10),
  decoration: const BoxDecoration(
    color: Colors.green, // fixed color
    shape: BoxShape.circle,
  ),
  child: const Icon(
    Icons.thumb_up_alt_rounded, // fixed icon
    color: Colors.white,
    size: 22,
  ),
),

                            const SizedBox(width: 12),

                            // Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        msg.senderName,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF2E3192),
                                        ),
                                      ),
                                      Text(
                                        "${msg.createdAt.toLocal()}".split(
                                          " ",
                                        )[0],
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    msg.messageText,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.black87,
                                      height: 1.4,
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
