import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'package:school_app/widgets/teacher_app_bar.dart';
import 'teacher_menu_drawer.dart';

class TeacherEventsHolidaysPage extends StatefulWidget {
  final bool startInMonthView;

  const TeacherEventsHolidaysPage({Key? key, this.startInMonthView = false})
      : super(key: key);

  @override
  State<TeacherEventsHolidaysPage> createState() =>
      _TeacherEventsHolidaysPageState();
}

class _TeacherEventsHolidaysPageState
    extends State<TeacherEventsHolidaysPage> {
  int selectedYear = DateTime.now().year;
  bool isMonthSelected = false;
  int currentMonthIndex = DateTime.now().month - 1;
  String currentMonth = '';

  bool isHolidayChecked = true;
  bool isEventChecked = true;

  final List<String> months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  // Map<MonthName, List<EventItem>>
  Map<String, List<Map<String, dynamic>>> yearlyEvents = {};

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    currentMonth = months[currentMonthIndex];
    isMonthSelected = widget.startInMonthView;
    fetchDataForCurrentView();
  }

  Future<void> fetchDataForCurrentView() async {
   if (isMonthSelected) {
  await fetchEventsForMonth(DateTime.now().year, currentMonthIndex + 1);
}
 else {
      // fetch all months
      yearlyEvents.clear();
      for (int m = 1; m <= 12; m++) {
        await fetchEventsForMonth(selectedYear, m, append: true);
      }
      setState(() {});
    }
  }

  Future<void> fetchEventsForMonth(int year, int month,
      {bool append = false}) async {
    setState(() => isLoading = true);
    try {
      final url =
          'https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api/events-holidays/$year/$month';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);

        List<Map<String, dynamic>> monthEvents = data.map((e) {
          DateTime date = DateTime.parse(e['date']);
          return {
            'day': date.day.toString(),
            'weekday': DateFormat('E').format(date), // Mon., Tue.
            'type': e['holiday_type'],
            'label': e['title']
          };
        }).toList();

        if (append) {
          yearlyEvents[months[month - 1]] = monthEvents;
        } else {
          yearlyEvents.clear();
          yearlyEvents[months[month - 1]] = monthEvents;
        }
      } else {
        throw Exception('Failed to load events');
      }
    } catch (e) {
      debugPrint('Error fetching events: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.pink[100],
      appBar: TeacherAppBar(),
      drawer: MenuDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text('< Back', style: TextStyle(fontSize: 16)),
                  ),
                  const Spacer(),
                  // const Text(
                  //   'Gallery',
                  //   style: TextStyle(fontWeight: FontWeight.bold),
                  // ),
                ],
              ),
            ),

            // Title Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E3192),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SvgPicture.asset(
                      'assets/icons/events.svg',
                      width: 24,
                      height: 24,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Events & Holidays',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E3192),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // White Container
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Toggle
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        isMonthSelected = true;
                                      });
                                      fetchDataForCurrentView();
                                    },
                                    child: Column(
                                      children: [
                                        Text(
                                          'Month',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: isMonthSelected
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            color: isMonthSelected
                                                ? const Color(0xFF29ABE2)
                                                : Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        if (isMonthSelected)
                                          Container(
                                            height: 3,
                                            width: 40,
                                            color: const Color(0xFF29ABE2),
                                          ),
                                      ],
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        isMonthSelected = false;
                                      });
                                      fetchDataForCurrentView();
                                    },
                                    child: Column(
                                      children: [
                                        Text(
                                          'Year',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: !isMonthSelected
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            color: !isMonthSelected
                                                ? const Color(0xFF29ABE2)
                                                : Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        if (!isMonthSelected)
                                          Container(
                                            height: 3,
                                            width: 40,
                                            color: const Color(0xFF29ABE2),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Year Selector
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.chevron_left),
                                    color: Colors.black,
                                    onPressed: () {
                                      setState(() {
                                        if (isMonthSelected) {
                                          currentMonthIndex =
                                              (currentMonthIndex - 1 + 12) % 12;
                                          currentMonth =
                                              months[currentMonthIndex];
                                          fetchDataForCurrentView();
                                        } else {
                                          selectedYear--;
                                          fetchDataForCurrentView();
                                        }
                                      });
                                    },
                                  ),
                                  Text(
                                    isMonthSelected
                                        ? currentMonth
                                        : '$selectedYear',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.chevron_right),
                                    color: const Color(0xFFE6E6E6),
                                    onPressed: () {
                                      setState(() {
                                        if (isMonthSelected) {
                                          currentMonthIndex =
                                              (currentMonthIndex + 1) % 12;
                                          currentMonth =
                                              months[currentMonthIndex];
                                          fetchDataForCurrentView();
                                        } else {
                                          selectedYear++;
                                          fetchDataForCurrentView();
                                        }
                                      });
                                    },
                                  ),
                                ],
                              ),
                              const Divider(),

                              // Legend
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    children: [
                                      Checkbox(
                                        value: isHolidayChecked,
                                        onChanged: (v) => setState(() =>
                                            isHolidayChecked = v ?? true),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      const CircleAvatar(
                                          radius: 6, backgroundColor: Colors.red),
                                      const SizedBox(width: 4),
                                      const Text('Holiday'),
                                    ],
                                  ),
                                  const SizedBox(width: 16),
                                  Row(
                                    children: [
                                      Checkbox(
                                        value: isEventChecked,
                                        onChanged: (v) => setState(
                                            () => isEventChecked = v ?? true),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: Colors.orange,
                                          borderRadius:
                                              BorderRadius.circular(3),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Text('Event'),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Events list
                              for (var month in (isMonthSelected
                                  ? [currentMonth]
                                  : months))
                                if (yearlyEvents[month] != null &&
                                    yearlyEvents[month]!.isNotEmpty)
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Center(
                                        child: Text(
                                          month,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                            color: Color(0xFF2E3192),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 16,
                                        runSpacing: 16,
                                        children: yearlyEvents[month]!
                                            .where((event) {
                                              if (event['type'] == 'Holiday' &&
                                                  !isHolidayChecked) {
                                                return false;
                                              }
                                              if (event['type'] == 'Event' &&
                                                  !isEventChecked) {
                                                return false;
                                              }
                                              return true;
                                            })
                                            .map((event) {
                                              final isHoliday =
                                                  event['type'] == 'Holiday';
                                              final color = isHoliday
                                                  ? Colors.red
                                                  : Colors.orange;
                                              return Column(
                                                children: [
                                                  isHoliday
                                                      ? CircleAvatar(
                                                          backgroundColor:
                                                              color,
                                                          radius: 28,
                                                          child: Column(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .center,
                                                            children: [
                                                              Text(
                                                                event['day'],
                                                                style:
                                                                    const TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 16,
                                                                ),
                                                              ),
                                                              Text(
                                                                event[
                                                                    'weekday'],
                                                                style:
                                                                    const TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontSize: 12,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        )
                                                      : Container(
                                                          width: 56,
                                                          height: 56,
                                                          decoration:
                                                              BoxDecoration(
                                                            color: color,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        12),
                                                          ),
                                                          child: Column(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .center,
                                                            children: [
                                                              Text(
                                                                event['day'],
                                                                style:
                                                                    const TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 16,
                                                                ),
                                                              ),
                                                              Text(
                                                                event[
                                                                    'weekday'],
                                                                style:
                                                                    const TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontSize: 12,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                  const SizedBox(height: 4),
                                                  SizedBox(
                                                    width: 56,
                                                    child: Text(
                                                      event['label'],
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: const TextStyle(
                                                          fontSize: 12),
                                                      overflow:
                                                          TextOverflow.visible,
                                                      softWrap: true,
                                                      maxLines: 2,
                                                    ),
                                                  ),
                                                ],
                                              );
                                            })
                                            .toList(),
                                      ),
                                      const SizedBox(height: 24),
                                    ],
                                  ),
                            ],
                          ),
                        ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
