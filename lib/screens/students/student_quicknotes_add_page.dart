import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:school_app/screens/students/student_menu_drawer.dart';
import 'package:school_app/widgets/student_app_bar.dart';
import 'package:school_app/config/config.dart';

class StudentAddQuickNotesPage extends StatefulWidget {
  const StudentAddQuickNotesPage({super.key});

  @override
  State<StudentAddQuickNotesPage> createState() =>
      _StudentAddQuickNotesPageState();
}

class _StudentAddQuickNotesPageState extends State<StudentAddQuickNotesPage> {
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
      final studentId = prefs.getInt('student_id');
      final token = prefs.getString('auth_token') ?? '';

      if (studentId == null || token.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error: Missing login credentials")),
        );
        setState(() => isLoading = false);
        return;
      }

      // ✅ Correct API Endpoint
      final url =
          '${AppConfig.baseUrl}/stickynotes/$studentId?user_type=Student';

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
          'accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      debugPrint("⬅️ Response (${response.statusCode}): ${response.body}");

      if (response.statusCode == 201 || response.statusCode == 200) {
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
      appBar: StudentAppBar(),
      drawer: const StudentMenuDrawer(),
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
                              SizedBox(
                                height: 450,
                                child: TextField(
                                  controller: noteController,
                                  maxLines: null,
                                  expands: true,
                                  textAlignVertical: TextAlignVertical.top,
                                  decoration: _inputDecoration(
                                    "Enter your note",
                                  ),
                                ),
                              ),

                              const SizedBox(height: 50),

                              // 🎨 Color Dropdown
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
