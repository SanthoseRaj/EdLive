import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:school_app/services/teacher_msg_service.dart';

import 'package:school_app/screens/teachers/teacher_menu_drawer.dart';
import 'package:school_app/widgets/teacher_app_bar.dart';
import 'package:school_app/models/teacher_class_student.dart';
import 'package:school_app/services/teacher_class_student_list.dart';

import 'package:school_app/models/class_section.dart';
import 'package:school_app/services/class_section_service.dart';

class TeacherMessagePage extends StatefulWidget {
  const TeacherMessagePage({super.key});

  @override
  State<TeacherMessagePage> createState() => _TeacherMessagePageState();
}

class _TeacherMessagePageState extends State<TeacherMessagePage> {
  String? selectedTo;
  bool showAccordion = false;
  bool sendSMS = false;
  bool sendWhatsApp = false;
  bool sendEmail = false;

  final TextEditingController studentSearchController = TextEditingController();
  final TextEditingController messageController = TextEditingController();

  // Example student data
  // List<Map<String, String>> allStudents = [
  //   {"name": "John Doe", "id": "1234", "class": "2A", "mobile": "9734567892"},
  //   {"name": "Jane Smith", "id": "5678", "class": "3B", "mobile": "9876543210"},
  // ];

  // List<Map<String, String>> searchResults = [];
  // List<Map<String, String>> selectedStudents = [];
  // // Add this above `searchResults`:
  // List<Student> allStudents = [];
  List<Student> allStudents = [];
  List<Student> searchResults = [];
  List<Map<String, dynamic>> selectedStudents = [];

  List<ClassSection> classSections = [];
  Map<int, bool> selectedClassSections = {}; // key = ClassSection.id

  bool loadingClasses = false;

  @override
  void initState() {
    super.initState();
    fetchAllStudents();
    fetchClassSectionsFromApi();
  }

  Future<void> fetchClassSectionsFromApi() async {
    setState(() => loadingClasses = true);

    try {
      final service = ClassService();
      final sections = await service.fetchClassSections();
      setState(() {
        classSections = sections;
        selectedClassSections = {for (var s in sections) s.id: false};
      });
    } catch (e) {
      debugPrint("Error fetching class sections: $e");
    } finally {
      setState(() => loadingClasses = false);
    }
  }

  void onSearch(String value) {
    final query = value.toLowerCase();

    setState(() {
      searchResults = allStudents.where((s) {
        return s.studentName.toLowerCase().contains(query) ||
            s.id.toString().contains(query);
        //  (s.mobile ?? '').contains(query);
      }).toList();
    });
  }

  void toggleStudentSelection(Map<String, String> student) {
    setState(() {
      if (selectedStudents.contains(student)) {
        selectedStudents.remove(student);
      } else {
        selectedStudents.add(student);
      }
    });
  }

  Widget buildStudentTile(Student student) {
    final isSelected = selectedStudents.any((s) => s["id"] == student.id);

    return ListTile(
      onTap: () {
        setState(() {
          if (isSelected) {
            selectedStudents.removeWhere((s) => s["id"] == student.id);
          } else {
            selectedStudents.add({
              "id": student.id,
              "name": student.studentName,
              "class": student.className,
            });
          }
        });
      },
      title: Text(student.studentName),
      subtitle: Text("ID: ${student.id}, Class: ${student.className}"),
      trailing: Checkbox(
        value: isSelected,
        onChanged: (val) {
          setState(() {
            if (val == true) {
              selectedStudents.add({
                "id": student.id,
                "name": student.studentName,
                "class": student.className,
              });
            } else {
              selectedStudents.removeWhere((s) => s["id"] == student.id);
            }
          });
        },
      ),
    );
  }

  void showStudentDetails(Student student) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(student.studentName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("ID: ${student.id}"),
            Text("Class: ${student.className}"),
            // If you have mobile or parent's contact in Student model, add it here
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  // Class & division selection state
  final Map<String, List<bool>> classSelections = {
    "LKG": List.generate(7, (_) => false),
    "UKG": List.generate(7, (_) => false),
    for (int i = 1; i <= 12; i++) "$i": List.generate(7, (_) => false),
  };

  void toggleDivision(String className, int index) {
    setState(() {
      classSelections[className]![index] = !classSelections[className]![index];
    });
  }

  void toggleWholeClass(String className) {
    setState(() {
      bool allSelected = classSelections[className]!.every((s) => s);
      for (int i = 0; i < 7; i++) {
        classSelections[className]![i] = !allSelected;
      }
    });
  }

  bool isClassChecked(String className) {
    return classSelections[className]!.contains(true);
  }

  void closeAccordion() {
    if (showAccordion) {
      setState(() {
        showAccordion = false;
      });
    }
  }

  // @override
  // void initState() {
  //   super.initState();
  //   fetchAllStudents();
  // }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token'); // key used when saving login token
  }

  Future<void> fetchAllStudents() async {
    try {
      final token = await getToken(); // get token from SharedPreferences
      if (token == null) return;

      final students = await StudentService.fetchStudents(token);
      setState(() {
        allStudents = students;
        searchResults = []; // start empty
      });
    } catch (e) {
      debugPrint("Error fetching students: $e");
    }
  }

  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: closeAccordion,
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        backgroundColor: Colors.pink[100], // fixed background
        appBar: TeacherAppBar(),
        drawer: MenuDrawer(),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Keep top section exactly as old design
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text(
                        "< Back",
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2E3192),
                          ),
                          child: SvgPicture.asset(
                            'assets/icons/message.svg',
                            width: 20,
                            height: 20,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Message',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2E3192),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // White card container with scroll
                Expanded(
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: Scrollbar(
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Your entire white container content goes here
                                    // Row(
                                    //   children: [
                                    //     Expanded(
                                    //       child: ElevatedButton(
                                    //         style: ElevatedButton.styleFrom(
                                    //           backgroundColor: Colors.grey[400],
                                    //           foregroundColor:
                                    //               Colors.white, // ✅ White text
                                    //         ),
                                    //         onPressed: () {},
                                    //         child: const Text("Cancel"),
                                    //       ),
                                    //     ),
                                    //     const SizedBox(width: 10),
                                    //     Expanded(
                                    //       child: ElevatedButton(
                                    //         style: ElevatedButton.styleFrom(
                                    //           backgroundColor: Colors.blue,
                                    //           foregroundColor: Colors.white,
                                    //         ),
                                    //         onPressed: () async {
                                    //           final selectedSections = classSections
                                    //               .where(
                                    //                 (cls) =>
                                    //                     selectedClassSections[cls
                                    //                         .id] ==
                                    //                     true,
                                    //               )
                                    //               .toList();

                                    //           if (selectedSections.isEmpty &&
                                    //               selectedStudents.isEmpty) {
                                    //             ScaffoldMessenger.of(
                                    //               context,
                                    //             ).showSnackBar(
                                    //               const SnackBar(
                                    //                 content: Text(
                                    //                   "Select at least one student or class",
                                    //                 ),
                                    //               ),
                                    //             );
                                    //             return;
                                    //           }

                                    //           if (messageController.text
                                    //               .trim()
                                    //               .isEmpty) {
                                    //             ScaffoldMessenger.of(
                                    //               context,
                                    //             ).showSnackBar(
                                    //               const SnackBar(
                                    //                 content: Text(
                                    //                   "Please enter a message",
                                    //                 ),
                                    //               ),
                                    //             );
                                    //             return;
                                    //           }

                                    //           final token = await getToken();
                                    //           if (token == null) return;

                                    //           bool allSuccess = true;

                                    //           final channels = <String>[];
                                    //           if (sendSMS) channels.add("sms");
                                    //           if (sendWhatsApp)
                                    //             channels.add("whatsapp");
                                    //           if (sendEmail) channels.add("email");

                                    //           if (channels.isEmpty) {
                                    //             ScaffoldMessenger.of(
                                    //               context,
                                    //             ).showSnackBar(
                                    //               const SnackBar(
                                    //                 content: Text(
                                    //                   "Select at least one channel",
                                    //                 ),
                                    //               ),
                                    //             );
                                    //             return;
                                    //           }

                                    //           // ✅ Send to selected individual students (ONLY ONCE)
                                    //           for (var student in selectedStudents) {
                                    //             final success =
                                    //                 await MessageService.sendMessage(
                                    //                   token: token,
                                    //                   studentId: student["id"],
                                    //                   messageText:
                                    //                       messageController.text,
                                    //                   isAppreciation: true,
                                    //                   isMeetingRequest: false,
                                    //                   channels: channels,
                                    //                 );

                                    //             if (!success) allSuccess = false;
                                    //           }

                                    //           // 🔜 Future: class section students send logic here

                                    //           if (allSuccess) {
                                    //             setState(() {
                                    //               messageController.clear();
                                    //               selectedStudents.clear();
                                    //               studentSearchController.clear();
                                    //               searchResults.clear();
                                    //               selectedClassSections.updateAll(
                                    //                 (key, value) => false,
                                    //               );
                                    //             });

                                    //             ScaffoldMessenger.of(
                                    //               context,
                                    //             ).showSnackBar(
                                    //               const SnackBar(
                                    //                 content: Text(
                                    //                   "Messages sent successfully",
                                    //                 ),
                                    //               ),
                                    //             );
                                    //           } else {
                                    //             ScaffoldMessenger.of(
                                    //               context,
                                    //             ).showSnackBar(
                                    //               const SnackBar(
                                    //                 content: Text(
                                    //                   "Some messages failed",
                                    //                 ),
                                    //               ),
                                    //             );
                                    //           }
                                    //         },
                                    //         child: const Text("Send"),
                                    //       ),
                                    //     ),
                                    //   ],
                                    // ),
                                    Text(
                                      "Write message History",
                                      style: TextStyle(
                                        color: Colors.blue[800],
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 10),

                                    // Main dropdown
                                    DropdownButtonFormField<String>(
                                      decoration: const InputDecoration(
                                        labelText: 'To',
                                        border: OutlineInputBorder(),
                                      ),
                                      value: selectedTo,
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'Specific Classes',
                                          child: Text('Specific Classes'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'Select a group',
                                          child: Text('Select a group'),
                                        ),
                                      ],
                                      onChanged: (val) {
                                        setState(() {
                                          selectedTo = val;
                                          showAccordion =
                                              val == "Specific Classes";
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 12),

                                    // Accordion for Specific Classes
                                    if (showAccordion) _buildAccordion(),

                                    const SizedBox(height: 15),
                                    const Divider(thickness: 1),
                                    const SizedBox(height: 10),
                                    const Center(
                                      child: Text(
                                        "OR",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),

                                    // Student Search (always below dropdown)
                                    TextFormField(
                                      controller: studentSearchController,
                                      decoration: const InputDecoration(
                                        labelText:
                                            "Student's name, ID No, or parent's mobile number",
                                        border: OutlineInputBorder(),
                                      ),
                                      onChanged: onSearch,
                                    ),
                                    const SizedBox(height: 10),

                                    // Show matching results
                                    ...searchResults
                                        .map(buildStudentTile)
                                        .toList(),

                                    const SizedBox(height: 10),

                                    // Selected students chips
                                    if (selectedStudents.isNotEmpty)
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: selectedStudents.map((
                                          student,
                                        ) {
                                          return Chip(
                                            label: Text(student["name"] ?? ""),
                                            deleteIcon: const Icon(Icons.close),
                                            onDeleted: () {
                                              setState(() {
                                                selectedStudents.remove(
                                                  student,
                                                );
                                              });
                                            },
                                          );
                                        }).toList(),
                                      ),

                                    const SizedBox(height: 15),

                                    // Compose message
                                    TextFormField(
                                      controller: messageController,
                                      maxLines: 4,
                                      decoration: const InputDecoration(
                                        labelText: "Type your message here",
                                        border: OutlineInputBorder(),
                                      ),
                                      onTap: closeAccordion,
                                    ),
                                    const SizedBox(height: 15),

                                    // Send options
                                    Row(
                                      children: [
                                        Checkbox(
                                          value: sendSMS,
                                          onChanged: (val) =>
                                              setState(() => sendSMS = val!),
                                        ),
                                        const Text("SMS"),
                                        const SizedBox(width: 8),
                                        Checkbox(
                                          value: sendWhatsApp,
                                          onChanged: (val) => setState(
                                            () => sendWhatsApp = val!,
                                          ),
                                        ),
                                        const Text("Whatsapp"),
                                        const SizedBox(width: 8),
                                        Checkbox(
                                          value: sendEmail,
                                          onChanged: (val) =>
                                              setState(() => sendEmail = val!),
                                        ),
                                        const Text("Email"),
                                      ],
                                    ),
                                    const SizedBox(height: 10),

                                    // File Upload
                                    // OutlinedButton(
                                    //   onPressed: () {},
                                    //   child: const Text("Select file"),
                                    // ),
                                    // const SizedBox(height: 8),
                                    // const Text("Document.pdf"),
                                    // const Text("Image.jpg"),
                                    const SizedBox(height: 20),

                                    // Buttons
                                  ],
                                ),
                              ),
                            ),
                          ),

                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.grey[400],
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        messageController.clear();
                                        selectedStudents.clear();
                                        studentSearchController.clear();
                                        searchResults.clear();
                                        selectedClassSections.updateAll(
                                          (k, v) => false,
                                        );
                                      });
                                    },
                                    child: const Text("Cancel"),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () async {
                                      final selectedSections = classSections
                                          .where(
                                            (cls) =>
                                                selectedClassSections[cls.id] ==
                                                true,
                                          )
                                          .toList();

                                      if (selectedSections.isEmpty &&
                                          selectedStudents.isEmpty) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              "Select at least one student or class",
                                            ),
                                          ),
                                        );
                                        return;
                                      }

                                      if (messageController.text
                                          .trim()
                                          .isEmpty) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              "Please enter a message",
                                            ),
                                          ),
                                        );
                                        return;
                                      }

                                      final token = await getToken();
                                      if (token == null) return;

                                      bool allSuccess = true;

                                      final channels = <String>[];
                                      if (sendSMS) channels.add("sms");
                                      if (sendWhatsApp)
                                        channels.add("whatsapp");
                                      if (sendEmail) channels.add("email");

                                      if (channels.isEmpty) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              "Select at least one channel",
                                            ),
                                          ),
                                        );
                                        return;
                                      }

                                      for (var student in selectedStudents) {
                                        final success =
                                            await MessageService.sendMessage(
                                              token: token,
                                              studentId: student["id"],
                                              messageText:
                                                  messageController.text,
                                              isAppreciation: true,
                                              isMeetingRequest: false,
                                              channels: channels,
                                            );

                                        if (!success) allSuccess = false;
                                      }

                                      if (allSuccess) {
                                        setState(() {
                                          messageController.clear();
                                          selectedStudents.clear();
                                          studentSearchController.clear();
                                          searchResults.clear();
                                          selectedClassSections.updateAll(
                                            (k, v) => false,
                                          );
                                        });

                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              "Messages sent successfully",
                                            ),
                                          ),
                                        );
                                      } else {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              "Some messages failed",
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                    child: const Text("Send"),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccordion() {
    if (loadingClasses) {
      return const Center(child: CircularProgressIndicator());
    }

    // Group sections by class name
    final Map<String, List<ClassSection>> groupedClasses = {};
    for (var cls in classSections) {
      groupedClasses.putIfAbsent(cls.className, () => []).add(cls);
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(5),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Classes',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 5),

          ...groupedClasses.entries.map((entry) {
            final className = entry.key;
            final sections = entry.value;

            bool isClassChecked() =>
                sections.every((s) => selectedClassSections[s.id] == true);

            void toggleWholeClass() {
              setState(() {
                final allSelected = isClassChecked();
                for (var s in sections) {
                  selectedClassSections[s.id] = !allSelected;
                }
              });
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: isClassChecked(),
                  onChanged: (_) => toggleWholeClass(),
                ),
                SizedBox(width: 30, child: Text(className)),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    children: sections.map((cls) {
                      final selected = selectedClassSections[cls.id] ?? false;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedClassSections[cls.id] = !selected;
                          });
                        },
                        child: Container(
                          width: 50,
                          height: 50,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            color: selected ? Colors.blue : Colors.white,
                          ),
                          child: Text(
                            cls.section.toUpperCase(),
                            style: TextStyle(
                              color: selected ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildClassCheckboxRow(String label) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: isClassChecked(label),
          onChanged: (_) => toggleWholeClass(label),
        ),
        SizedBox(width: 30, child: Text(label)),
        Expanded(
          child: Wrap(
            spacing: 6,
            children: List.generate(7, (index) {
              return GestureDetector(
                onTap: () => toggleDivision(label, index),
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    color: classSelections[label]![index]
                        ? Colors.blue
                        : Colors.white,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    String.fromCharCode(65 + index),
                    style: TextStyle(
                      color: classSelections[label]![index]
                          ? Colors.white
                          : Colors.black,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}
