import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:school_app/screens/teachers/teacher_menu_drawer.dart';
import 'package:school_app/widgets/teacher_app_bar.dart';
import 'package:school_app/config/config.dart';

class AddStickyNotePage extends StatefulWidget {
  const AddStickyNotePage({super.key});

  @override
  State<AddStickyNotePage> createState() => _AddStickyNotePageState();
}

class _AddStickyNotePageState extends State<AddStickyNotePage> {
  final TextEditingController noteController = TextEditingController();
  final TextEditingController posXController = TextEditingController();
  final TextEditingController posYController = TextEditingController();

  String selectedColor = 'blue';
  bool isLoading = false;

  Future<void> _addStickyNote() async {
    final note = noteController.text.trim();
    final color = selectedColor;
    final posX = int.tryParse(posXController.text) ?? 0;
    final posY = int.tryParse(posYController.text) ?? 0;

    if (note.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please enter a note")));
      return;
    }

    setState(() => isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      // ✅ Get teacher ID and token from login
      final teacherId = prefs.getInt('teacher_id');
      final token = prefs.getString('auth_token') ?? '';

      if (teacherId == null || token.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error: Missing login credentials")),
        );
        setState(() => isLoading = false);
        return;
      }

      final url = '${AppConfig.baseUrl}/stickynotes/$teacherId';

      final body = jsonEncode({
        "notes": note,
        "color": color,
        "position_x": posX,
        "position_y": posY,
      });

      debugPrint("➡️ Sending StickyNote POST to $url");
      debugPrint("📦 Body: $body");

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'accept': '*/*',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      debugPrint("⬅️ Response (${response.statusCode}): ${response.body}");

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Sticky note added successfully!")),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed (${response.statusCode}): ${response.body}"),
          ),
        );
      }
    } catch (e) {
      debugPrint("❌ Error adding sticky note: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD3C4D6),
      appBar: TeacherAppBar(),
      drawer: const MenuDrawer(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Text(
                  "< Back",
                  style: TextStyle(fontSize: 14, color: Colors.black),
                ),
              ),
              const SizedBox(height: 10),

              // 🔹 Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(color: Color(0xFF2E3192)),
                    child: SvgPicture.asset(
                      'assets/icons/quick_notes.svg',
                      height: 20,
                      width: 20,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "Add Sticky Note",
                    style: TextStyle(
                      color: Color(0xFF2D3E9A),
                      fontWeight: FontWeight.bold,
                      fontSize: 26,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              // 📝 Note Field
                              Container(
                                height: 450, // 👈 Increased height
                                child: TextField(
                                  controller: noteController,
                                  maxLines: null, // 👈 Allows multiple lines
                                  expands:
                                      true, // 👈 Makes it fill the container height
                                  textAlignVertical: TextAlignVertical.top,
                                  decoration: _inputDecoration(
                                    "Enter your note",
                                  ),
                                ),
                              ),

                              const SizedBox(height: 50),

                              // 🎨 Color Dropdown
                              // 🎨 Color Dropdown (border only for dropdown)
                              // 🎨 Color Dropdown (border only for dropdown)
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    "Color",
                                    style: TextStyle(
                                      fontSize: 20,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  Container(
                                    width: 150,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.black,
                                        width: 1,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: DropdownButton<String>(
                                      value: selectedColor,
                                      isExpanded: true,
                                      underline: const SizedBox(),
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'yellow',
                                          child: Text('Yellow'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'pink',
                                          child: Text('Pink'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'blue',
                                          child: Text('Blue'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'green',
                                          child: Text('Green'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'orange',
                                          child: Text('Orange'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'purple',
                                          child: Text('Purple'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'red',
                                          child: Text('Red'),
                                        ),
                                        // DropdownMenuItem(value: 'skyblue', child: Text('Sky Blue')),
                                        DropdownMenuItem(
                                          value: 'brown',
                                          child: Text('Brown'),
                                        ),
                                      ],
                                      onChanged: (val) {
                                        setState(() => selectedColor = val!);
                                      },
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              // 📍 Position Fields
                              //   Row(
                              //     children: [
                              //       Expanded(
                              //         child: TextField(
                              //           controller: posXController,
                              //           keyboardType: TextInputType.number,
                              //           decoration:
                              //               _inputDecoration("Position X (opt)"),
                              //         ),
                              //       ),
                              //       const SizedBox(width: 10),
                              //       Expanded(
                              //         child: TextField(
                              //           controller: posYController,
                              //           keyboardType: TextInputType.number,
                              //           decoration:
                              //               _inputDecoration("Position Y (opt)"),
                              //         ),
                              //       ),
                              //     ],
                              //   ),
                            ],
                          ),
                        ),
                      ),

                      // 🔘 Add Button
                      GestureDetector(
                        onTap: isLoading ? null : _addStickyNote,
                        child: Container(
                          height: 44,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: isLoading
                                ? Colors.grey
                                : const Color(0xFF29ABE2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Center(
                            child: isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : const Text(
                                    "Add Sticky Note",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      hintText: label,
      filled: true,
      fillColor: const Color(0xFFF5F5F5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide.none,
      ),
    );
  }
}

// Teacher Quick Notes Old page:
// import 'package:flutter/material.dart';
// import 'package:flutter_svg/flutter_svg.dart';
// import 'package:school_app/screens/teachers/teacher_menu_drawer.dart';
// import 'package:school_app/widgets/teacher_app_bar.dart';
// import 'package:school_app/models/teacher_quicknote_class_model.dart';
// import 'package:school_app/models/teacher_quicknote_student_model.dart';
// import 'package:school_app/services/teacher_quicknote_class_service.dart';
// import 'package:school_app/services/teacher_quicknote_student_service.dart';
// import 'package:school_app/services/teacher_quicknote_add_service.dart';

// class AddQuickNotePage extends StatefulWidget {
//   const AddQuickNotePage({super.key});

//   @override
//   State<AddQuickNotePage> createState() => _AddQuickNotePageState();
// }

// class _AddQuickNotePageState extends State<AddQuickNotePage> {
//   QuickNoteClass? selectedClass;

//   List<QuickNoteStudent> students = [];
//   List<QuickNoteStudent> selectedStudents = []; // ✅ multiple students
//   bool isLoadingStudents = false;

//   final TextEditingController noteController = TextEditingController();
//   final TextEditingController descController = TextEditingController();
//   final TextEditingController linkController = TextEditingController();

//   late Future<List<QuickNoteClass>> futureClasses;

//   @override
//   void initState() {
//     super.initState();
//     futureClasses = QuickNoteClassService().fetchClasses();
//   }

//   Future<void> _loadStudents(int classId) async {
//     setState(() {
//       isLoadingStudents = true;
//       students = [];
//       selectedStudents = [];
//     });

//     try {
//       students = await QuickNoteStudentService().fetchStudents(classId);
//     } catch (e) {
//       debugPrint("Error loading students: $e");
//     } finally {
//       setState(() {
//         isLoadingStudents = false;
//       });
//     }
//   }

//   void _showMultiSelectStudents() {
//     // temporary copy
//     List<QuickNoteStudent> tempSelected = List.from(selectedStudents);

//     showDialog(
//       context: context,
//       builder: (ctx) {
//         return StatefulBuilder(
//           builder: (ctx, setStateDialog) {
//             return AlertDialog(
//               title: const Text("Select Students"),
//               content: SizedBox(
//                 width: double.maxFinite,
//                 child: ListView(
//                   children: students.map((stu) {
//                     final isSelected = tempSelected.contains(stu);
//                     return CheckboxListTile(
//                       value: isSelected,
//                       title: Text(stu.fullName),
//                       onChanged: (bool? checked) {
//                         setStateDialog(() {
//                           if (checked == true) {
//                             tempSelected.add(stu);
//                           } else {
//                             tempSelected.remove(stu);
//                           }
//                         });
//                       },
//                     );
//                   }).toList(),
//                 ),
//               ),
//               actions: [
//                 TextButton(
//                   onPressed: () {
//                     // ✅ update parent state when Done pressed
//                     setState(() {
//                       selectedStudents = tempSelected;
//                     });
//                     Navigator.pop(ctx);
//                   },
//                   child: const Text("Done"),
//                 ),
//               ],
//             );
//           },
//         );
//       },
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFD3C4D6),
//       appBar: TeacherAppBar(),
//       drawer: MenuDrawer(),
//       body: SafeArea(
//         child: Padding(
//           padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               GestureDetector(
//                 onTap: () => Navigator.pop(context),
//                 child: const Text(
//                   "< Back",
//                   style: TextStyle(fontSize: 14, color: Colors.black),
//                 ),
//               ),
//               const SizedBox(height: 6),

//               Row(
//                 children: [
//                   Container(
//                     padding: const EdgeInsets.all(6),
//                     decoration: const BoxDecoration(color: Color(0xFF2E3192)),
//                     child: SvgPicture.asset(
//                       'assets/icons/quick_notes.svg',
//                       height: 20,
//                       width: 20,
//                       color: Colors.white,
//                     ),
//                   ),
//                   const SizedBox(width: 8),
//                   const Text(
//                     "Quick Notes",
//                     style: TextStyle(
//                       color: Color(0xFF2D3E9A),
//                       fontWeight: FontWeight.bold,
//                       fontSize: 28,
//                     ),
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 24),

//               Expanded(
//                 child: Container(
//                   decoration: BoxDecoration(
//                     color: Colors.white,
//                     borderRadius: BorderRadius.circular(6),
//                   ),
//                   padding: const EdgeInsets.all(16),
//                   child: Column(
//                     children: [
//                       Expanded(
//                         child: SingleChildScrollView(
//                           child: Column(
//                             children: [
//                               // 🔽 Dynamic Class Dropdown
//                               Row(
//                                 mainAxisAlignment:
//                                     MainAxisAlignment.spaceBetween,
//                                 children: [
//                                   const Text(
//                                     "Class",
//                                     style: TextStyle(fontSize: 14),
//                                   ),
//                                   const SizedBox(width: 20),
//                                   SizedBox(
//                                     width: 200,
//                                     child: FutureBuilder<List<QuickNoteClass>>(
//                                       future: futureClasses,
//                                       builder: (context, snapshot) {
//                                         if (snapshot.connectionState ==
//                                             ConnectionState.waiting) {
//                                           return const Center(
//                                             child: CircularProgressIndicator(),
//                                           );
//                                         } else if (snapshot.hasError) {
//                                           return Text(
//                                             "Error: ${snapshot.error}",
//                                           );
//                                         } else if (!snapshot.hasData ||
//                                             snapshot.data!.isEmpty) {
//                                           return const Text("No classes found");
//                                         } else {
//                                           final classes = snapshot.data!;

//                                           // ✅ Don't call setState inside build
//                                           if (selectedClass == null) {
//                                             // Instead of setState, just assign directly
//                                             selectedClass = classes.first;

//                                             // Trigger async load AFTER build is done
//                                             WidgetsBinding.instance
//                                                 .addPostFrameCallback((_) {
//                                                   _loadStudents(
//                                                     selectedClass!.classId,
//                                                   );
//                                                 });
//                                           }

//                                           return DropdownButton<QuickNoteClass>(
//                                             value: selectedClass,
//                                             isExpanded: true,
//                                             underline: const SizedBox(),
//                                             items: classes.map((cls) {
//                                               return DropdownMenuItem(
//                                                 value: cls,
//                                                 child: Text(cls.className),
//                                               );
//                                             }).toList(),
//                                             onChanged: (val) {
//                                               if (val != null) {
//                                                 setState(() {
//                                                   selectedClass = val;
//                                                 });
//                                                 _loadStudents(val.classId);
//                                               }
//                                             },
//                                           );
//                                         }
//                                       },
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                               const SizedBox(height: 16),

//                               // 🔽 Dynamic Student Dropdown
//                               Row(
//                                 mainAxisAlignment:
//                                     MainAxisAlignment.spaceBetween,
//                                 children: [
//                                   const Text(
//                                     "Student Name",
//                                     style: TextStyle(fontSize: 14),
//                                   ),
//                                   const SizedBox(width: 20),
//                                   SizedBox(
//                                     width: 200,
//                                     child: isLoadingStudents
//                                         ? const Center(
//                                             child: CircularProgressIndicator(),
//                                           )
//                                         : GestureDetector(
//                                             onTap:
//                                                 _showMultiSelectStudents, // ✅ multiple select
//                                             child: Container(
//                                               padding:
//                                                   const EdgeInsets.symmetric(
//                                                     horizontal: 8,
//                                                     vertical: 10,
//                                                   ),
//                                               decoration: BoxDecoration(
//                                                 color: Colors.white,
//                                                 border: Border.all(
//                                                   color: Colors.grey.shade400,
//                                                 ),
//                                                 borderRadius:
//                                                     BorderRadius.circular(6),
//                                               ),
//                                               child: Text(
//                                                 selectedStudents.isEmpty
//                                                     ? "Select Students"
//                                                     : selectedStudents
//                                                           .map(
//                                                             (s) => s.fullName,
//                                                           )
//                                                           .join(", "),
//                                                 maxLines: 2,
//                                                 overflow: TextOverflow.ellipsis,
//                                               ),
//                                             ),
//                                           ),
//                                   ),
//                                 ],
//                               ),
//                               const SizedBox(height: 16),

//                               // Notes, Desc, Links
//                               TextField(
//                                 controller: noteController,
//                                 decoration: _inputDecoration("Quick Notes"),
//                               ),
//                               const SizedBox(height: 16),
//                               TextField(
//                                 controller: descController,
//                                 maxLines: 3,
//                                 decoration: _inputDecoration("Description"),
//                               ),
//                               const SizedBox(height: 16),
//                               TextField(
//                                 controller: linkController,
//                                 decoration: _inputDecoration("Web Links"),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),

//                       // Add / Remove buttons
//                       Row(
//                         children: [
//                           Expanded(
//                             child: Container(
//                               height: 44,
//                               decoration: BoxDecoration(
//                                 color: Colors.grey.shade400,
//                                 borderRadius: BorderRadius.circular(4),
//                               ),
//                               child: const Center(
//                                 child: Text(
//                                   "Remove",
//                                   style: TextStyle(
//                                     color: Colors.white,
//                                     fontWeight: FontWeight.w600,
//                                   ),
//                                 ),
//                               ),
//                             ),
//                           ),
//                           const SizedBox(width: 12),
//                           Expanded(
//                             child: GestureDetector(
//                               onTap: () async {
//                                 try {
//                                   final service = QuickNoteService();

//                                   final note = await service.createQuickNote(
//                                     title: noteController.text.trim(),
//                                     description: descController.text.trim(),
//                                     webLinks: linkController.text.isNotEmpty
//                                         ? [linkController.text.trim()]
//                                         : [],
//                                     studentIds: selectedStudents
//                                         .map((s) => s.id)
//                                         .toList(), // ✅ multiple
//                                     classId: selectedClass!.classId,
//                                   );

//                                   debugPrint("✅ Quick Note Created: $note");

//                                   if (mounted) {
//                                     ScaffoldMessenger.of(context).showSnackBar(
//                                       const SnackBar(
//                                         content: Text(
//                                           "Quick note added successfully!",
//                                         ),
//                                       ),
//                                     );
//                                     Navigator.pop(context);
//                                   }
//                                 } catch (e) {
//                                   debugPrint("❌ Error adding quick note: $e");
//                                   if (mounted) {
//                                     ScaffoldMessenger.of(context).showSnackBar(
//                                       SnackBar(content: Text("Error: $e")),
//                                     );
//                                   }
//                                 }
//                               },

//                               child: Container(
//                                 height: 44,
//                                 decoration: BoxDecoration(
//                                   color: const Color(0xFF29ABE2),
//                                   borderRadius: BorderRadius.circular(4),
//                                 ),
//                                 child: const Center(
//                                   child: Text(
//                                     "Add",
//                                     style: TextStyle(
//                                       color: Colors.white,
//                                       fontWeight: FontWeight.w600,
//                                     ),
//                                   ),
//                                 ),
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   InputDecoration _inputDecoration(String label) {
//     return InputDecoration(
//       hintText: label,
//       filled: true,
//       fillColor: const Color(0xFFF5F5F5),
//       contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
//       border: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(4),
//         borderSide: BorderSide.none,
//       ),
//     );
//   }
// }
