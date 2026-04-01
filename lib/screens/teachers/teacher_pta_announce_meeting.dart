import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:school_app/screens/teachers/teacher_menu_drawer.dart';
import 'package:school_app/widgets/teacher_app_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:school_app/models/class_section.dart';
import 'package:school_app/services/class_section_service.dart';
import 'package:school_app/config/config.dart';

class AnnounceMeetingPage extends StatefulWidget {
  const AnnounceMeetingPage({Key? key}) : super(key: key);

  @override
  State<AnnounceMeetingPage> createState() => _AnnounceMeetingPageState();
}

class _AnnounceMeetingPageState extends State<AnnounceMeetingPage> {
  // String? selectedClass = '10';
  bool isAllDivision = true;
  DateTime selectedDate = DateTime.now();
  TimeOfDay selectedTime = const TimeOfDay(hour: 14, minute: 0);

  List<ClassSection> classSections = [];
  ClassSection? selectedClassSection;
  bool isLoadingClasses = true;

  bool sendSMS = true;
  bool sendWhatsApp = true;
  bool sendEmail = true;

  final TextEditingController divisionController = TextEditingController();
  final TextEditingController subjectController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    setState(() => isLoadingClasses = true);
    try {
      final classes = await ClassService().fetchClassSections();
      setState(() {
        classSections = classes;
        if (classes.isNotEmpty) selectedClassSection = classes[0];
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to load classes: $e")));
    } finally {
      setState(() => isLoadingClasses = false);
    }
  }

  Future<void> _announceMeeting(int meetingId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';

      final url = Uri.parse("${AppConfig.baseUrl}/pta/announce");

      // Determine selected channels
      List<String> channels = [];
      if (sendSMS) channels.add("sms");
      if (sendWhatsApp) channels.add("whatsapp");
      if (sendEmail) channels.add("email");

      final body = jsonEncode({
        "meetingId": meetingId,
        "class_ids": selectedClassSection != null
            ? [selectedClassSection!.id]
            : [],
        "include_all_sections": isAllDivision,
        "channels": channels,
      });

      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: body,
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Meeting announced successfully")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Announcement error: ${response.statusCode} ${response.body}",
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Announcement error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TeacherAppBar(),
      drawer: MenuDrawer(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Announce a meeting",
                    style: TextStyle(
                      color: Colors.lightBlue,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, size: 28),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Select classes dropdown
              isLoadingClasses
                  ? const CircularProgressIndicator()
                  : DropdownButtonFormField<ClassSection>(
                      value: selectedClassSection,
                      decoration: const InputDecoration(
                        labelText: "Select class",
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12),
                      ),
                      items: classSections
                          .map(
                            (cls) => DropdownMenuItem(
                              value: cls,
                              child: Text(cls.fullName),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        setState(() {
                          selectedClassSection = val;
                        });
                      },
                    ),
              const SizedBox(height: 16),

              // Division selection
              // Row(
              //   crossAxisAlignment: CrossAxisAlignment.center,
              //   children: [
              //     Column(
              //       mainAxisSize: MainAxisSize.min,
              //       children: [
              //         const Text(
              //           "Division",
              //           style: TextStyle(
              //               fontSize: 14, fontWeight: FontWeight.w500),
              //         ),
              //         Row(
              //           mainAxisSize: MainAxisSize.min,
              //           children: [
              //             Radio<bool>(
              //               value: true,
              //               groupValue: isAllDivision,
              //               onChanged: (val) {
              //                 setState(() {
              //                   isAllDivision = val!;
              //                 });
              //               },
              //             ),
              //             const Text("All"),
              //           ],
              //         ),
              //       ],
              //     ),
              //     const SizedBox(width: 10),
              //     Column(
              //       mainAxisSize: MainAxisSize.min,
              //       children: [
              //         const Text(
              //           "Enter Division",
              //           style: TextStyle(
              //               fontSize: 14, fontWeight: FontWeight.w500),
              //         ),
              //         Row(
              //           mainAxisSize: MainAxisSize.min,
              //           children: [
              //             Radio<bool>(
              //               value: false,
              //               groupValue: isAllDivision,
              //               onChanged: (val) {
              //                 setState(() {
              //                   isAllDivision = val!;
              //                 });
              //               },
              //             ),
              //             SizedBox(
              //               width: 60,
              //               height: 30,
              //               child: TextField(
              //                 controller: divisionController,
              //                 enabled: !isAllDivision,
              //                 textAlign: TextAlign.center,
              //                 decoration: const InputDecoration(
              //                   isDense: false,
              //                   contentPadding:
              //                       EdgeInsets.symmetric(vertical: 8),
              //                   border: OutlineInputBorder(),
              //                 ),
              //               ),
              //             ),
              //           ],
              //         ),
              //       ],
              //     ),
              //   ],
              // ),
              const SizedBox(height: 16),

              // Date & Time
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      readOnly: true,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(
                            Icons.calendar_today,
                            color: Colors.deepPurple,
                          ),
                          onPressed: _pickDate,
                        ),
                      ),
                      controller: TextEditingController(
                        text:
                            "${selectedDate.day}, ${_monthName(selectedDate.month)} ${selectedDate.year}",
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      readOnly: true,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(
                            Icons.access_time,
                            color: Colors.deepPurple,
                          ),
                          onPressed: _pickTime,
                        ),
                      ),
                      controller: TextEditingController(
                        text: _formatTime(selectedTime),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),

              // Subject
              TextFormField(
                controller: subjectController,
                decoration: const InputDecoration(
                  hintText: "Lesson name, topic etc...",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 26),

              // Description
              TextFormField(
                controller: descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: "Type",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 26),

              // Checkboxes
              Row(
                children: [
                  Checkbox(
                    value: sendSMS,
                    onChanged: (val) => setState(() => sendSMS = val!),
                    fillColor: MaterialStateProperty.all(Colors.white),
                    checkColor: Colors.green,
                  ),
                  const Text("SMS"),
                  const SizedBox(width: 8),
                  Checkbox(
                    value: sendWhatsApp,
                    onChanged: (val) => setState(() => sendWhatsApp = val!),
                    fillColor: MaterialStateProperty.all(Colors.white),
                    checkColor: Colors.green,
                  ),
                  const Text("Whats app"),
                  const SizedBox(width: 8),
                  Checkbox(
                    value: sendEmail,
                    onChanged: (val) => setState(() => sendEmail = val!),
                    fillColor: MaterialStateProperty.all(Colors.white),
                    checkColor: Colors.green,
                  ),
                  const Text("Email"),
                ],
              ),
              const Spacer(),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade400,
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        "Cancel",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.lightBlue,
                      ),
                      onPressed: isLoading ? null : _sendMeeting,
                      child: isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              "Send",
                              style: TextStyle(color: Colors.white),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _monthName(int month) {
    const months = [
      "",
      "Jan.",
      "Feb.",
      "Mar.",
      "Apr.",
      "May",
      "Jun.",
      "Jul.",
      "Aug.",
      "Sep.",
      "Oct.",
      "Nov.",
      "Dec.",
    ];
    return months[month];
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Future<void> _pickDate() async {
    DateTime? date = await showDatePicker(
      context: context,
      initialDate: selectedDate.isBefore(DateTime.now())
          ? DateTime.now()
          : selectedDate,
      firstDate: DateTime.now(), // 👈 prevents selecting past dates
      lastDate: DateTime(2100),
    );
    if (date != null) {
      setState(() {
        selectedDate = date;
      });
    }
  }

  Future<void> _pickTime() async {
    TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: selectedTime,
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(alwaysUse24HourFormat: false), // 👈 12-hour format
          child: child!,
        );
      },
    );

    if (time != null) {
      setState(() {
        selectedTime = time;
      });
    }
  }

  Future<void> _sendMeeting() async {
    if (subjectController.text.isEmpty || descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
      return;
    }

    setState(() => isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';

      final url = Uri.parse("${AppConfig.baseUrl}/pta/meetings");

      final body = jsonEncode({
        "title": subjectController.text,
        "description": descriptionController.text,
        "date":
            "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}",
        "time":
            "${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}",
        "class_ids": selectedClassSection != null
            ? [selectedClassSection!.id]
            : [],

        "include_all_sections": isAllDivision,
      });

      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: body,
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final meetingId = data['id']; // Get created meeting id

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Meeting created successfully")),
        );

        // Send announcements
        await _announceMeeting(meetingId);

        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: ${response.statusCode} ${response.body}"),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => isLoading = false);
    }
  }
}
