import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:school_app/config/config.dart';
import 'teacher_quick_notes_addpage.dart';
import 'package:school_app/widgets/teacher_app_bar.dart';
import 'package:school_app/screens/teachers/teacher_menu_drawer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class TeacherQuickNotesPage extends StatefulWidget {
  const TeacherQuickNotesPage({super.key});

  @override
  State<TeacherQuickNotesPage> createState() => _TeacherQuickNotesPageState();
}

class _TeacherQuickNotesPageState extends State<TeacherQuickNotesPage> {
  late Future<List<StickyNote>> _notesFuture;
  final QuickNoteService _service = QuickNoteService();

  /// store expanded notes (by index)
  int? expandedIndex;

  @override
  void initState() {
    super.initState();
    _loadQuickNotes();
  }

  // ✅ Load quick notes based on logged-in teacher ID
  // ✅ Load quick notes based on logged-in teacher ID
  void _loadQuickNotes() async {
    setState(() {
      _notesFuture = _service.fetchStickyNotes(); // Remove teacherId parameter
    });
  }

  // Function to get color from string
  Color _getColorFromString(String colorName) {
    switch (colorName.toLowerCase()) {
      case 'yellow':
        return Colors.yellow.shade100;
      case 'pink':
        return Colors.pink.shade100;
      case 'blue':
        return Colors.blue.shade100;
      case 'green':
        return Colors.green.shade100;
      case 'orange':
        return Colors.orange.shade100;
      case 'purple':
        return Colors.purple.shade100;
      case 'red':
        return Colors.red.shade100;
      // case 'skyblue':
      //   return Colors.lightBlue.shade100;
      case 'brown':
        return Colors.brown.shade100;
      case 'grey':
      case 'gray':
        return Colors.grey.shade300;
      default:
        try {
          // handle hex colors like "#FF5733"
          if (colorName.startsWith('#')) {
            return Color(
              int.parse(colorName.substring(1, 7), radix: 16) + 0xFF000000,
            );
          }
        } catch (_) {}
        return Colors.yellow.shade100; // fallback color
    }
  }

  // Function to format date
  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (expandedIndex != null) {
          setState(() {
            expandedIndex = null; // go back to list instead of exiting page
          });
          return false; // ❌ don't pop route
        }
        return true; // ✅ allow normal back (go to dashboard)
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFE6E6E6),
        drawer: MenuDrawer(),
        appBar: TeacherAppBar(),
        body: Column(
          children: [
            // Header Section
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Text(
                          '< Back',
                          style: TextStyle(fontSize: 16, color: Colors.black),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AddStickyNotePage(),
                            ),
                          ).then(
                            (_) => _loadQuickNotes(),
                          ); // Refresh after adding
                        },
                        icon: const Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 20,
                        ),
                        label: const Text(
                          'Add',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFF29ABE2),
                          padding: const EdgeInsets.symmetric(
                            vertical: 6,
                            horizontal: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: const BoxDecoration(
                          color: Color(0xFF2E3192),
                        ),
                        child: SvgPicture.asset(
                          'assets/icons/quick_notes.svg',
                          height: 24,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Sticky Notes',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2E3192),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Notes List
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: FutureBuilder<List<StickyNote>>(
                  future: _notesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(
                        child: Text(
                          'No Quick Notes available',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      );
                    } else {
                      final notes = snapshot.data!;
                      if (expandedIndex != null) {
                        // Show only the expanded note with back button
                        final note = notes[expandedIndex!];
                        return ListView(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                          children: [_expandedNoteView(note)],
                        );
                      } else {
                        // Show all notes list
                        return ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                          itemCount: notes.length,
                          itemBuilder: (context, index) {
                            final note = notes[index];
                            return _noteItem(note, index);
                          },
                        );
                      }
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _expandedNoteView(StickyNote note) {
    final screenHeight = MediaQuery.of(context).size.height;

    return SingleChildScrollView(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        height: screenHeight * 0.82, // ✅ make expanded note taller
        decoration: BoxDecoration(
          color: _getColorFromString(note.color),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back + Title Row
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF2E3192)),
                  onPressed: () {
                    setState(() {
                      expandedIndex = null; // go back to list
                    });
                  },
                ),
                Expanded(
                  child: Text(
                    "Note ${note.id}",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E3192),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getColorFromString(note.color).withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    note.color.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Note Content
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    note.notes,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Metadata Section
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: Colors.black54,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "Created: ",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      Text(
                        _formatDate(note.createdDate),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (note.updateDate != note.createdDate)
                    Row(
                      children: [
                        const Icon(
                          Icons.update,
                          size: 16,
                          color: Colors.black54,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          "Updated: ",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        Text(
                          _formatDate(note.updateDate),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  if (note.updateDate != note.createdDate)
                    const SizedBox(height: 8),

                  Row(
                    children: [
                      const Icon(Icons.person, size: 16, color: Colors.black54),
                      const SizedBox(width: 8),
                      const Text(
                        "By: ",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      Text(
                        note.userName.isNotEmpty ? note.userName : 'You',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _noteItem(StickyNote note, int index) {
    final isExpanded = expandedIndex == index;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _getColorFromString(note.color),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Note #${note.id}",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E3192),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  note.notes.length > 100
                      ? '${note.notes.substring(0, 100)}...'
                      : note.notes,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _formatDate(note.createdDate),
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
            contentPadding: const EdgeInsets.only(
              left: 16,
              right: 8,
              top: 8,
              bottom: 8,
            ),
            trailing: IconButton(
              icon: Icon(
                isExpanded ? Icons.expand_less : Icons.chevron_right,
                color: Colors.black54,
              ),
              onPressed: () {
                setState(() {
                  if (expandedIndex == index) {
                    expandedIndex = null; // collapse
                  } else {
                    expandedIndex = index; // expand only this one
                  }
                });
              },
            ),
            onTap: () {
              setState(() {
                if (expandedIndex == index) {
                  expandedIndex = null;
                } else {
                  expandedIndex = index;
                }
              });
            },
          ),

          // Show details only for expanded item
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      note.notes,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.person, size: 14, color: Colors.black54),
                      const SizedBox(width: 4),
                      Text(
                        note.userName.isNotEmpty ? note.userName : 'You',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: Colors.black54,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(note.createdDate),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class StickyNote {
  final int id;
  final int userId;
  final String userType;
  final String notes;
  final String createdDate;
  final String updateDate;
  final bool isArchived;
  final String color;
  final int positionX;
  final int positionY;
  final String userName;

  StickyNote({
    required this.id,
    required this.userId,
    required this.userType,
    required this.notes,
    required this.createdDate,
    required this.updateDate,
    required this.isArchived,
    required this.color,
    required this.positionX,
    required this.positionY,
    required this.userName,
  });

  factory StickyNote.fromJson(Map<String, dynamic> json) {
    return StickyNote(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      userType: json['user_type'] ?? '',
      notes: json['notes'] ?? '',
      createdDate: json['created_date'] ?? '',
      updateDate: json['update_date'] ?? '',
      isArchived: json['is_archived'] ?? false,
      color: json['color'] ?? 'yellow',
      positionX: json['position_x'] ?? 0,
      positionY: json['position_y'] ?? 0,
      userName: json['user_name'] ?? 'You', // Default value for null userName
    );
  }
}

class QuickNoteService {
  static String get baseUrl => AppConfig.serverOrigin;

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    // Try multiple possible token keys - prioritize auth_token since that's what login uses
    return prefs.getString('auth_token') ??
        prefs.getString('token') ??
        prefs.getString('access_token');
  }

  Future<int?> _getTeacherId() async {
    final prefs = await SharedPreferences.getInstance();

    // First try to get teacher_id directly
    final teacherId = prefs.getInt('teacher_id');
    if (teacherId != null) return teacherId;

    // If not found, try to get from user_data
    final userDataString = prefs.getString('user_data');
    if (userDataString != null) {
      try {
        final userData = json.decode(userDataString);
        // Check if user has staffid (for teachers)
        if (userData['staffid'] != null && userData['staffid'].isNotEmpty) {
          final staffId = userData['staffid'][0]; // Get first staff ID
          await prefs.setInt('teacher_id', staffId);
          return staffId;
        }
        // Alternatively, use the user id
        final userId = userData['id'];
        if (userId != null) {
          await prefs.setInt('teacher_id', userId);
          return userId;
        }
      } catch (e) {
        print('Error parsing user_data: $e');
      }
    }

    return null;
  }

  Future<List<StickyNote>> fetchStickyNotes({int? teacherId}) async {
    try {
      final token = await _getToken();

      if (token == null) {
        throw Exception('No authentication token found. Please login.');
      }

      // If teacherId not provided, get it from storage
      final actualTeacherId = teacherId ?? await _getTeacherId();

      if (actualTeacherId == null) {
        throw Exception('Teacher ID not found. Please login again.');
      }

      print('Fetching sticky notes for teacher ID: $actualTeacherId');
      print(
        'Using token: ${token.length > 20 ? '${token.substring(0, 20)}...' : token}',
      );

      final response = await http.get(
        Uri.parse(
          '$baseUrl/api/stickynotes/$actualTeacherId?user_type=Teacher',
        ),
        headers: {
          'accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      }

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isEmpty) {
          return [];
        }
        return data.map((json) => StickyNote.fromJson(json)).toList();
      } else {
        throw Exception(
          'Failed to load sticky notes: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('Error in fetchStickyNotes: $e');
      throw Exception('Failed to load sticky notes: $e');
    }
  }
}

// import 'package:flutter/material.dart';
// import 'package:url_launcher/url_launcher.dart';

// import 'package:flutter_svg/flutter_svg.dart';
// import 'teacher_quick_notes_addpage.dart';
// import 'package:school_app/widgets/teacher_app_bar.dart';
// import 'package:school_app/screens/teachers/teacher_menu_drawer.dart';
// import '../../models/teacher_quick_note_model.dart';
// import '../../services/teacher_quick_note_service.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// class TeacherQuickNotesPage extends StatefulWidget {
//   const TeacherQuickNotesPage({super.key});

//   @override
//   State<TeacherQuickNotesPage> createState() => _TeacherQuickNotesPageState();
// }

// class _TeacherQuickNotesPageState extends State<TeacherQuickNotesPage> {
//   late Future<List<QuickNote>> _notesFuture;
//   final QuickNoteService _service = QuickNoteService();

//   /// store expanded notes (by index)
// int? expandedIndex;

//   @override
//   void initState() {
//     super.initState();
//     _loadQuickNotes();
//   }

//   // ✅ Load quick notes based on logged-in student class and ID
//   void _loadQuickNotes() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     int? studentId = prefs.getInt('student_id'); // stored at login
//     int? classId = prefs.getInt('class_id'); // stored at login

//     setState(() {
//       _notesFuture = _service.fetchQuickNotes(
//         classId: classId,
//         studentId: studentId,
//       );
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFE6E6E6),
//       drawer: MenuDrawer(),
//       appBar: TeacherAppBar(),
//       body: Column(
//         children: [
//           // Header Section
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 const SizedBox(height: 12),
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     GestureDetector(
//                       onTap: () => Navigator.pop(context),
//                       child: const Text('< Back',
//                           style: TextStyle(fontSize: 16, color: Colors.black)),
//                     ),
//                     TextButton.icon(
//                       onPressed: () {
//                         Navigator.push(
//                           context,
//                           MaterialPageRoute(
//                               builder: (context) => const AddQuickNotePage()),
//                         );
//                       },
//                       icon: const Icon(Icons.add_circle_outline,
//                           color: Colors.white, size: 20),
//                       label: const Text('Add',
//                           style: TextStyle(color: Colors.white, fontSize: 16)),
//                       style: TextButton.styleFrom(
//                         backgroundColor: const Color(0xFF29ABE2),
//                         padding: const EdgeInsets.symmetric(
//                             vertical: 6, horizontal: 12),
//                         shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(6)),
//                       ),
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 10),
//                 Row(
//                   children: [
//                     Container(
//                       padding: const EdgeInsets.all(7),
//                       decoration:
//                           const BoxDecoration(color: Color(0xFF2E3192)),
//                       child: SvgPicture.asset(
//                         'assets/icons/quick_notes.svg',
//                         height: 24,
//                         color: Colors.white,
//                       ),
//                     ),
//                     const SizedBox(width: 8),
//                     const Text(
//                       'Quick Notes',
//                       style: TextStyle(
//                           fontSize: 28,
//                           fontWeight: FontWeight.w700,
//                           color: Color(0xFF2E3192)),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//           const SizedBox(height: 10),

//           // Notes List
//           Expanded(
//             child: Container(
//               margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
//               decoration: BoxDecoration(
//                   color: Colors.white, borderRadius: BorderRadius.circular(8)),
//               child: FutureBuilder<List<QuickNote>>(
//                 future: _notesFuture,
//                 builder: (context, snapshot) {
//                   if (snapshot.connectionState == ConnectionState.waiting) {
//                     return const Center(child: CircularProgressIndicator());
//                   } else if (snapshot.hasError) {
//                     return Center(child: Text('Error: ${snapshot.error}'));
//                   } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
//                     return const Center(child: Text('No Quick Notes available'));
//                   } else {
//                     final notes = snapshot.data!;
//                    if (expandedIndex != null) {
//   // Show only the expanded note with back button
//   final note = notes[expandedIndex!];
//   return ListView(
//     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//     children: [
//       _expandedNoteView(note),
//     ],
//   );
// } else {
//   // Show all notes list
//   return ListView.builder(
//     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//     itemCount: notes.length,
//     itemBuilder: (context, index) {
//       final note = notes[index];
//       return _noteItem(note, index);
//     },
//   );
// }

//                   }
//                 },
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// Widget _expandedNoteView(QuickNote note) {
//   return Container(
//     margin: const EdgeInsets.only(bottom: 10),
//     padding: const EdgeInsets.all(16),
//     decoration: BoxDecoration(
//       color: Colors.white,
//       borderRadius: BorderRadius.circular(10),
//       boxShadow: [
//         BoxShadow(
//           color: Colors.grey.withOpacity(0.15),
//           blurRadius: 6,
//           offset: const Offset(0, 3),
//         ),
//       ],
//     ),
//     child: Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         // Back + Title Row
//         Row(
//           children: [
//             IconButton(
//               icon: const Icon(Icons.arrow_back, color: Color(0xFF2E3192)),
//               onPressed: () {
//                 setState(() {
//                   expandedIndex = null; // go back to list
//                 });
//               },
//             ),
//             Expanded(
//               child: Text(
//                 note.title,
//                 style: const TextStyle(
//                   fontSize: 20,
//                   fontWeight: FontWeight.bold,
//                   color: Color(0xFF2E3192),
//                 ),
//               ),
//             ),
//           ],
//         ),
//         const SizedBox(height: 16),

//         // Description
//         if (note.description != null && note.description!.isNotEmpty) ...[
//           const SizedBox(height: 12),
//           const Text(
//             "Description:",
//             style: TextStyle(
//               fontWeight: FontWeight.bold,
//               fontSize: 16,
//               color: Colors.black,
//             ),
//           ),
//           const SizedBox(height: 6),
//           Text(
//             note.description!,
//             style: const TextStyle(fontSize: 15, color: Colors.black87),
//           ),
//           const SizedBox(height: 12),
//         ],

//         // Links
//         // Links
// if (note.webLinks != null && note.webLinks!.isNotEmpty) ...[
//   const Divider(thickness: 1, color: Color(0xFFE6E6E6)),
//   const SizedBox(height: 12),
//   const Text(
//     "Links:",
//     style: TextStyle(
//       fontWeight: FontWeight.bold,
//       fontSize: 16,
//       color: Colors.black,
//     ),
//   ),
//   const SizedBox(height: 6),
//   Column(
//     crossAxisAlignment: CrossAxisAlignment.start,
//     children: note.webLinks!
//         .map((l) => Padding(
//               padding: const EdgeInsets.only(bottom: 4),
//               child: InkWell(
//                 onTap: () async {
//                   final Uri uri = Uri.parse(l);
//                   if (await canLaunchUrl(uri)) {
//                     await launchUrl(uri, mode: LaunchMode.externalApplication);
//                   }
//                 },
//                 child: Text(
//                   l,
//                   style: const TextStyle(
//                     color: Colors.blue,
//                     decoration: TextDecoration.none, // no underline
//                   ),
//                 ),
//               ),
//             ))
//         .toList(),
//   ),
//   const SizedBox(height: 12),
// ],

//         // Class Name + Student Names
//         const SizedBox(height: 12),
//        if (note.className != null) ...[
//   RichText(
//     text: TextSpan(
//       children: [
//         const TextSpan(
//           text: "Class: ",
//           style: TextStyle(
//             fontSize: 14,
//             fontWeight: FontWeight.bold,
//             color: Colors.black, // 🔹 Dark Blue for title
//           ),
//         ),
//         TextSpan(
//           text: note.className!,
//           style: const TextStyle(
//             fontSize: 14,
//             color: Colors.black87,
//           ),
//         ),
//       ],
//     ),
//   ),
//   const SizedBox(height: 20), // 🔹 line space
// ],
// if (note.studentNames != null && note.studentNames!.isNotEmpty) ...[
//   RichText(
//     text: TextSpan(
//       children: [
//         const TextSpan(
//           text: "Students: ",
//           style: TextStyle(
//             fontSize: 14,
//             fontWeight: FontWeight.bold,
//              color: Colors.black,  // 🔹 Dark Blue for title
//           ),
//         ),
//         TextSpan(
//           text: note.studentNames!.join(", "),
//           style: const TextStyle(
//             fontSize: 14,
//             color: Colors.black87,
//           ),
//         ),
//       ],
//     ),
//   ),
//   const SizedBox(height: 4), // 🔹 line space
// ],

//       ],
//     ),
//   );
// }

// Widget _noteItem(QuickNote note, int index) {
//   final isExpanded = expandedIndex == index;

//   return Container(
//     margin: const EdgeInsets.only(bottom: 6),
//     decoration: BoxDecoration(
//       color: Colors.white,
//       borderRadius: BorderRadius.circular(6),
//     ),
//     child: Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         ListTile(
//           title: Text(
//             note.title,
//             style: const TextStyle(
//               fontSize: 15,
//               color: Color(0xFF2E3192),
//               // decoration: TextDecoration.underline,
//             ),
//           ),
//           contentPadding: const EdgeInsets.only(left: 10, right: 0),
//           trailing: IconButton(
//             icon: Icon(
//               isExpanded ? Icons.expand_less : Icons.chevron_right,
//               color: Colors.black54,
//             ),
//             onPressed: () {
//               setState(() {
//                 if (expandedIndex == index) {
//                   expandedIndex = null; // collapse
//                 } else {
//                   expandedIndex = index; // expand only this one
//                 }
//               });
//             },
//           ),
//           onTap: () {
//             setState(() {
//               if (expandedIndex == index) {
//                 expandedIndex = null;
//               } else {
//                 expandedIndex = index;
//               }
//             });
//           },
//         ),

//         // Show details only for expanded item
//         if (isExpanded)
//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 if (note.description != null && note.description!.isNotEmpty) ...[
//                   const Text("Description:",
//                       style: TextStyle(fontWeight: FontWeight.bold)),
//                   Text(note.description!),
//                   const SizedBox(height: 8),
//                 ],
//                 if (note.webLinks != null && note.webLinks!.isNotEmpty) ...[
//                   const Text("Links:",
//                       style: TextStyle(fontWeight: FontWeight.bold)),
//                   ...note.webLinks!.map((l) => Text(l)),
//                   const SizedBox(height: 8),
//                 ],
//                 Text("Class ID: ${note.classId}"),
//                 Text("Student IDs: ${note.studentIds.join(", ")}"),
//               ],
//             ),
//           ),
//       ],
//     ),
//   );
// }

// }
