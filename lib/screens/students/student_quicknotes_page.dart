import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:school_app/widgets/student_app_bar.dart';
import 'package:school_app/screens/students/student_menu_drawer.dart';
import 'package:school_app/screens/students/student_quicknotes_add_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class StudentQuickNotesPage extends StatefulWidget {
  const StudentQuickNotesPage({super.key});

  @override
  State<StudentQuickNotesPage> createState() => _StudentQuickNotesPageState();
}

class _StudentQuickNotesPageState extends State<StudentQuickNotesPage> {
  late Future<List<StudentStickyNote>> _notesFuture;
  final StudentQuickNoteService _service = StudentQuickNoteService();
  int? expandedIndex;

  @override
  void initState() {
    super.initState();
    _loadQuickNotes();
  }

  void _loadQuickNotes() {
    setState(() {
      _notesFuture = _service.fetchStudentStickyNotes();
    });
  }

  // 🔹 Navigate to Add Note page and refresh list on return
  Future<void> _navigateToAddNote() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const StudentAddQuickNotesPage()),
    );
    _loadQuickNotes(); // refresh after returning
  }

  // Convert color name/hex to Flutter color
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
      case 'brown':
        return Colors.brown.shade100;
      case 'grey':
      case 'gray':
        return Colors.grey.shade300;
      default:
        try {
          if (colorName.startsWith('#')) {
            return Color(int.parse(colorName.substring(1, 7), radix: 16) + 0xFF000000);
          }
        } catch (_) {}
        return Colors.yellow.shade100;
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE6E6E6),
      drawer: const StudentMenuDrawer(),
      appBar:  StudentAppBar(),
      body: Column(
        children: [
          // Header
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
                      onPressed: _navigateToAddNote,
                      icon: const Icon(Icons.add, color: Colors.white, size: 20),
                      label: const Text(
                        'Add',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFF29ABE2),
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
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
                      decoration: const BoxDecoration(color: Color(0xFF2E3192)),
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
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: FutureBuilder<List<StudentStickyNote>>(
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
                      final note = notes[expandedIndex!];
                      return ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        children: [_expandedNoteView(note)],
                      );
                    } else {
                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
    );
  }

  Widget _expandedNoteView(StudentStickyNote note) {
    final screenHeight = MediaQuery.of(context).size.height;
    return SingleChildScrollView(
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        height: screenHeight * 0.82,
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
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF2E3192)),
                  onPressed: () => setState(() => expandedIndex = null),
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                    style: const TextStyle(fontSize: 16, color: Colors.black87, height: 1.4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
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
                      const Icon(Icons.calendar_today, size: 16, color: Colors.black54),
                      const SizedBox(width: 8),
                      const Text("Created: ",
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      Text(_formatDate(note.createdDate),
                          style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (note.updateDate != note.createdDate)
                    Row(
                      children: [
                        const Icon(Icons.update, size: 16, color: Colors.black54),
                        const SizedBox(width: 8),
                        const Text("Updated: ",
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        Text(_formatDate(note.updateDate),
                            style: const TextStyle(fontSize: 14)),
                      ],
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.person, size: 16, color: Colors.black54),
                      const SizedBox(width: 8),
                      const Text("By: ",
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      Text(note.userName.isNotEmpty ? note.userName : 'You',
                          style: const TextStyle(fontSize: 14)),
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

  Widget _noteItem(StudentStickyNote note, int index) {
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
              offset: const Offset(0, 2)),
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
            trailing: IconButton(
              icon: Icon(isExpanded ? Icons.expand_less : Icons.chevron_right,
                  color: Colors.black54),
              onPressed: () {
                setState(() {
                  expandedIndex = isExpanded ? null : index;
                });
              },
            ),
            onTap: () {
              setState(() {
                expandedIndex = isExpanded ? null : index;
              });
            },
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(note.notes,
                    style: const TextStyle(fontSize: 14, color: Colors.black87)),
              ),
            ),
        ],
      ),
    );
  }
}

// ----------------------- MODEL -----------------------

class StudentStickyNote {
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

  StudentStickyNote({
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

  factory StudentStickyNote.fromJson(Map<String, dynamic> json) {
    return StudentStickyNote(
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
      userName: json['user_name'] ?? 'You',
    );
  }
}

// ----------------------- SERVICE -----------------------

class StudentQuickNoteService {
  static const String baseUrl =
      'https://schoolmanagement.canadacentral.cloudapp.azure.com:443';

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token') ??
        prefs.getString('access_token');
  }

  Future<int?> _getStudentId() async {
    final prefs = await SharedPreferences.getInstance();
    final studentId = prefs.getInt('student_id');
    if (studentId != null) return studentId;

    final userDataString = prefs.getString('user_data');
    if (userDataString != null) {
      try {
        final userData = json.decode(userDataString);
        if (userData['studentid'] != null && userData['studentid'].isNotEmpty) {
          final sid = userData['studentid'][0];
          await prefs.setInt('student_id', sid);
          return sid;
        }
        if (userData['id'] != null) {
          await prefs.setInt('student_id', userData['id']);
          return userData['id'];
        }
      } catch (e) {
        debugPrint('Error parsing student user_data: $e');
      }
    }
    return null;
  }

  Future<List<StudentStickyNote>> fetchStudentStickyNotes() async {
    try {
      final token = await _getToken();
      if (token == null) throw Exception('No authentication token found.');
      final studentId = await _getStudentId();
      if (studentId == null) throw Exception('Student ID not found.');

      final response = await http.get(
        Uri.parse('$baseUrl/api/stickynotes/$studentId?user_type=Student'),
        headers: {'accept': 'application/json', 'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => StudentStickyNote.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load student sticky notes: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching student notes: $e');
      throw Exception('Failed to fetch student notes: $e');
    }
  }
}






//Old Page Code (open link) 


// import 'dart:convert';
// import 'package:flutter_svg/flutter_svg.dart';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:url_launcher/url_launcher.dart';


// import 'package:school_app/models/teacher_class_student.dart';
// import 'package:school_app/screens/students/student_menu_drawer.dart';
// import 'package:school_app/widgets/student_app_bar.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// class StudentQuickNotesPage extends StatefulWidget {
//   const StudentQuickNotesPage({super.key});

//   @override
//   State<StudentQuickNotesPage> createState() => _StudentQuickNotesPageState();
// }

// class _StudentQuickNotesPageState extends State<StudentQuickNotesPage> {
//   List<dynamic> _notes = [];
//   bool _isLoading = true;
//   String? _error;
//   dynamic _selectedNote; // 🔹 track which note is selected

//   @override
//   void initState() {
//     super.initState();
//     _fetchQuickNotes();
//   }

//   Future<void> _fetchQuickNotes() async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final token = prefs.getString("auth_token") ?? "";
//       final studentId = prefs.getInt("student_id") ?? 0;
//       final classId = prefs.getInt("class_id") ?? 0;

//       final url =
//           "https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api/quicknotes?classId=$classId&studentId=$studentId";

//       final response = await http.get(
//         Uri.parse(url),
//         headers: {
//           "Content-Type": "application/json",
//           "Authorization": "Bearer $token",
//         },
//       );

//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//         setState(() {
//           _notes = data;
//           _isLoading = false;
//         });
//       } else {
//         setState(() {
//           _error = "Failed to load notes (status ${response.statusCode})";
//           _isLoading = false;
//         });
//       }
//     } catch (e) {
//       setState(() {
//         _error = "Error: $e";
//         _isLoading = false;
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFE6E6E6),
//       drawer: StudentMenuDrawer(),
//       appBar: StudentAppBar(),
//       body: Column(
//         children: [
//           // Header
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 GestureDetector(
//                   onTap: () {
//                     if (_selectedNote != null) {
//                       // go back to list view
//                       setState(() {
//                         _selectedNote = null;
//                       });
//                     } else {
//                       Navigator.pop(context);
//                     }
//                   },
//                   child: const Text(
//                     '< Back',
//                     style: TextStyle(
//                       fontSize: 16,
//                       color: Colors.black,
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 8),
//                 Row(
//                   children: [
//                     Container(
//                       padding: const EdgeInsets.all(8),
//                       decoration: BoxDecoration(
//                         color: const Color(0xFF2E3192),
//                         borderRadius: BorderRadius.circular(8),
//                       ),
//                       child: SvgPicture.asset(
//                         "assets/icons/quick_notes.svg",
//                         width: 24,
//                         height: 24,
//                         color: Colors.white,
//                       ),
//                     ),
//                     const SizedBox(width: 10),
//                     const Text(
//                       'Quick Notes',
//                       style: TextStyle(
//                         fontSize: 28,
//                         fontWeight: FontWeight.w700,
//                         color: Color(0xFF2E3192),
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//           const SizedBox(height: 10),

//           // Notes container
// Expanded(
//   child: Container(
//     margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10), // fixed outside spacing
//     padding: const EdgeInsets.all(16), // inner padding
//     decoration: BoxDecoration(
//       color: Colors.white,
//       borderRadius: BorderRadius.circular(8),
//     ),
//     child: _isLoading
//         ? const Center(child: CircularProgressIndicator())
//         : _error != null
//             ? Center(
//                 child: Text(
//                   _error!,
//                   style: const TextStyle(color: Colors.red),
//                 ),
//               )
//             : _selectedNote != null
//                 ? LayoutBuilder(
//                     builder: (context, constraints) {
//                       // constraints.maxWidth is the fixed container width
//                       return SingleChildScrollView(
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             SizedBox(
//                               width: constraints.maxWidth,
//                               child: Text(
//                                 _selectedNote["title"] ?? "",
//                                 style: const TextStyle(
//                                   fontSize: 20,
//                                   fontWeight: FontWeight.bold,
//                                   color: Color(0xFF2E3192),
//                                 ),
//                                 softWrap: true,
//                               ),
//                             ),
//                             const SizedBox(height: 12),
//                             SizedBox(
//                               width: constraints.maxWidth,
//                               child: Text(
//                                 _selectedNote["description"] ?? "",
//                                 style: const TextStyle(fontSize: 16),
//                                 softWrap: true,
//                               ),
//                             ),
//                             const SizedBox(height: 12),
//                           if (_selectedNote["web_links"] != null &&
//     _selectedNote["web_links"].isNotEmpty)
//   Column(
//     crossAxisAlignment: CrossAxisAlignment.start,
//     children: [
//       const Text(
//         "Links:",
//         style: TextStyle(
//           fontSize: 16,
//           fontWeight: FontWeight.w600,
//         ),
//       ),
//       ...(_selectedNote["web_links"] as List).map(
//         (link) => SizedBox(
//           width: constraints.maxWidth,
//           child: Padding(
//             padding: const EdgeInsets.symmetric(vertical: 2),
//             child: InkWell(
//               onTap: () async {
//   final uri = Uri.tryParse(link);
//   if (uri != null) {
//     if (await canLaunchUrl(uri)) {
//       await launchUrl(
//         uri,
//         mode: LaunchMode.externalApplication, // 🔹 opens in Chrome/Safari
//       );
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text("Cannot open link")),
//       );
//     }
//   }
// },
//  child: Text(
//                 link,
//                 style: const TextStyle(
//                   color: Colors.blue,
//                   // decoration: TextDecoration.underline,
//                 ),
//                 softWrap: true,
//               ),
//             ),
//           ),
//         ),
//       ).toList(),
//     ],
//   ),

//                           ],
//                         ),
//                       );
//                     },
//                   )
//               // 🔹 Replace only the list section when _selectedNote == null
// : ListView.builder(
//     padding: const EdgeInsets.all(12),
//     itemCount: _notes.length,
//     itemBuilder: (context, index) {
//       final note = _notes[index];
//       return Container(
//         margin: const EdgeInsets.symmetric(vertical: 6),
//         padding: const EdgeInsets.all(12),
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(8),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.grey.withOpacity(0.2),
//               spreadRadius: 1,
//               blurRadius: 4,
//               offset: const Offset(0, 2),
//             ),
//           ],
//         ),
//         child: ListTile(
//           contentPadding: EdgeInsets.zero,
//           title: Text(
//             note["title"] ?? "",
//             style: const TextStyle(
//               fontSize: 16,
//               color: Color(0xFF2E3192),
//               fontWeight: FontWeight.w600,
//             ),
//             softWrap: true,
//           ),
//           subtitle: Padding(
//             padding: const EdgeInsets.only(top: 4),
//             child: Text(
//               note["description"] ?? "",
//               maxLines: 2, // 🔹 show only 2 lines
//               overflow: TextOverflow.ellipsis, // 🔹 truncate with "..."
//               softWrap: true,
//             ),
//           ),
//           trailing: Text(
//             note["created_by_name"] ?? "",
//             style: const TextStyle(
//               fontStyle: FontStyle.italic,
//               fontSize: 12,
//             ),
//             softWrap: true,
//           ),
//           onTap: () {
//             setState(() {
//               _selectedNote = note;
//             });
//           },
//         ),
//       );
//     },
//   ),
//  ),
// ),
//   ],
//       ),
//     );
//   }
// }
