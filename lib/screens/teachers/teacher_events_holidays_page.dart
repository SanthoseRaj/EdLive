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

class _TeacherEventsHolidaysPageState extends State<TeacherEventsHolidaysPage> {
  int selectedYear = DateTime.now().year;
  bool isMonthSelected = false;
  int currentMonthIndex = DateTime.now().month - 1;
  String currentMonth = '';

  bool isHolidayChecked = true;
  bool isEventChecked = true;
  bool isLoading = false;

  final List<String> months = const [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  Map<String, List<Map<String, dynamic>>> yearlyEvents =
      <String, List<Map<String, dynamic>>>{};

  @override
  void initState() {
    super.initState();
    currentMonth = months[currentMonthIndex];
    isMonthSelected = widget.startInMonthView;
    fetchDataForCurrentView();
  }

  Future<void> fetchDataForCurrentView() async {
    setState(() => isLoading = true);

    final nextEvents = <String, List<Map<String, dynamic>>>{};

    if (isMonthSelected) {
      nextEvents[currentMonth] = await _fetchEventsForMonth(
        selectedYear,
        currentMonthIndex + 1,
      );
    } else {
      final results = await Future.wait(
        List.generate(
          months.length,
          (index) => _fetchEventsForMonth(selectedYear, index + 1),
        ),
      );

      for (int index = 0; index < months.length; index++) {
        nextEvents[months[index]] = results[index];
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      yearlyEvents = nextEvents;
      isLoading = false;
    });
  }

  Future<List<Map<String, dynamic>>> _fetchEventsForMonth(
    int year,
    int month,
  ) async {
    try {
      final url =
          'https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api/events-holidays/$year/$month';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        throw Exception('Failed to load events');
      }

      final List data = json.decode(response.body);
      return data.map<Map<String, dynamic>>((e) {
        final date = DateTime.parse(e['date']);
        return {
          'day': date.day.toString(),
          'weekday': DateFormat('E').format(date),
          'type': e['holiday_type'],
          'label': e['title'],
        };
      }).toList();
    } catch (e) {
      debugPrint('Error fetching events for $year/$month: $e');
      return <Map<String, dynamic>>[];
    }
  }

  List<Map<String, dynamic>> _visibleEventsForMonth(String month) {
    final events = yearlyEvents[month] ?? const <Map<String, dynamic>>[];
    return events.where((event) {
      if (event['type'] == 'Holiday' && !isHolidayChecked) {
        return false;
      }
      if (event['type'] == 'Event' && !isEventChecked) {
        return false;
      }
      return true;
    }).toList();
  }

  bool _hasVisibleEvents() {
    for (final month in (isMonthSelected ? [currentMonth] : months)) {
      if (_visibleEventsForMonth(month).isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  Widget _buildToggle(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              color: selected ? const Color(0xFF29ABE2) : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          if (selected)
            Container(height: 3, width: 40, color: const Color(0xFF29ABE2)),
        ],
      ),
    );
  }

  Widget _buildMonthSection(String month) {
    final visibleEvents = _visibleEventsForMonth(month);
    if (visibleEvents.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
          children: visibleEvents.map((event) {
            final isHoliday = event['type'] == 'Holiday';
            final color = isHoliday ? Colors.red : Colors.orange;

            return Column(
              children: [
                isHoliday
                    ? CircleAvatar(
                        backgroundColor: color,
                        radius: 28,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              event['day'],
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              event['weekday'],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              event['day'],
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              event['weekday'],
                              style: const TextStyle(
                                color: Colors.white,
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
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.visible,
                    softWrap: true,
                    maxLines: 2,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.pink[100],
      appBar: TeacherAppBar(),
      drawer: const MenuDrawer(),
      body: SafeArea(
        child: Column(
          children: [
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
                ],
              ),
            ),
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
                      colorFilter: const ColorFilter.mode(
                        Colors.white,
                        BlendMode.srcIn,
                      ),
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
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildToggle('Month', isMonthSelected, () {
                              setState(() {
                                isMonthSelected = true;
                              });
                              fetchDataForCurrentView();
                            }),
                            _buildToggle('Year', !isMonthSelected, () {
                              setState(() {
                                isMonthSelected = false;
                              });
                              fetchDataForCurrentView();
                            }),
                          ],
                        ),
                        const SizedBox(height: 8),
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
                                    currentMonth = months[currentMonthIndex];
                                  } else {
                                    selectedYear--;
                                  }
                                });
                                fetchDataForCurrentView();
                              },
                            ),
                            Text(
                              isMonthSelected ? currentMonth : '$selectedYear',
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
                                    currentMonth = months[currentMonthIndex];
                                  } else {
                                    selectedYear++;
                                  }
                                });
                                fetchDataForCurrentView();
                              },
                            ),
                          ],
                        ),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value: isHolidayChecked,
                                  onChanged: (value) => setState(
                                    () => isHolidayChecked = value ?? true,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                                const CircleAvatar(
                                  radius: 6,
                                  backgroundColor: Colors.red,
                                ),
                                const SizedBox(width: 4),
                                const Text('Holiday'),
                              ],
                            ),
                            const SizedBox(width: 16),
                            Row(
                              children: [
                                Checkbox(
                                  value: isEventChecked,
                                  onChanged: (value) => setState(
                                    () => isEventChecked = value ?? true,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Text('Event'),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (isLoading)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 32),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (_hasVisibleEvents())
                          for (final month
                              in (isMonthSelected ? [currentMonth] : months))
                            _buildMonthSection(month)
                        else
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 32),
                            child: Center(child: Text('No events found.')),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
