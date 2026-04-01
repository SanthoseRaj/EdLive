// ignore_for_file: constant_identifier_names
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:school_app/config/config.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '/widgets/student_app_bar.dart';
import 'student_menu_drawer.dart';

// ----------------- MODEL -----------------
class StudentTimetableItem {
  final String subject;
  final Map<String, String?> dayPeriods; // { "monday": "09:00 - 10:00", ... }

  StudentTimetableItem({required this.subject, required this.dayPeriods});

  factory StudentTimetableItem.fromJson(Map<String, dynamic> json) {
    return StudentTimetableItem(
      subject: json['subject'] ?? '',
      dayPeriods: {
        "monday": json['monday'],
        "tuesday": json['tuesday'],
        "wednesday": json['wednesday'],
        "thursday": json['thursday'],
        "friday": json['friday'],
        "saturday": json['saturday'],
      },
    );
  }
}

// ----------------- PAGE -----------------
class StudentTimeTablePage extends StatefulWidget {
  final String studentId; // 👈 you must pass Student ID

  const StudentTimeTablePage({super.key, required this.studentId});

  @override
  State<StudentTimeTablePage> createState() => _StudentTimeTablePageState();
}

class _StudentTimeTablePageState extends State<StudentTimeTablePage> {
  late DateTime _centerDate;
  late DateTime _startDate;
  final _scroll = ScrollController();

  List<StudentTimetableItem> _timetable = [];
  bool _loading = true;
  String? _error;

  static const _MONTHS = [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  void initState() {
    super.initState();
    if (AppConfig.academicYear.isEmpty) {
      AppConfig.setAcademicYear();
    }
    _centerDate = DateTime.now();
    _startDate = _centerDate.subtract(Duration(days: _centerDate.weekday - 1));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerCurrentDate();
    });
    _fetchTimetable();
  }

  // -------- API CALL --------
  Future<void> _fetchTimetable() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) {
        setState(() {
          _error = "No token found. Please login again.";
          _loading = false;
        });
        return;
      }

      final url =
          "${AppConfig.baseUrl}/student/students/timetable/${widget.studentId}/${AppConfig.academicYear}";
      final response = await http.get(
        Uri.parse(url),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _timetable = data
              .map((json) => StudentTimetableItem.fromJson(json))
              .toList();
          _loading = false;
        });
      } else {
        setState(() {
          _error = "Failed to load timetable (${response.statusCode})";
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = "Error: $e";
        _loading = false;
      });
    }
  }

  // -------- DATE HELPERS --------
  List<DateTime> get _visibleDates =>
      List.generate(30, (i) => _startDate.add(Duration(days: i)));

  String get _monthLabel =>
      "${_MONTHS[_centerDate.month]}. ${_centerDate.year}";

  void _centerCurrentDate() {
    final itemWidth = MediaQuery.of(context).size.width / 8.5;
    final index = _centerDate.difference(_startDate).inDays;

    const targetBoxPosition = 3;
    final offset = (index - targetBoxPosition) * itemWidth;

    if (_scroll.hasClients) {
      _scroll.animateTo(
        offset.clamp(0.0, _scroll.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onDateTap(DateTime date, int index) {
    setState(() => _centerDate = date);
    _centerCurrentDate();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8B3DE),
      drawer: const StudentMenuDrawer(),
      appBar: StudentAppBar(),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [_header(), const SizedBox(height: 8), _whiteCard()],
        ),
      ),
    );
  }

  // -------- HEADER --------
  Widget _header() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Row(
              children: [
                SvgPicture.asset(
                  'assets/icons/arrow_back.svg',
                  height: 11,
                  width: 11,
                  color: Colors.black,
                ),
                const SizedBox(width: 4),
                const Text(
                  'Back',
                  style: TextStyle(color: Colors.black, fontSize: 16),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E3192),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SvgPicture.asset(
                  'assets/icons/class_time.svg',
                  height: 32,
                  width: 32,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Time table',
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
    );
  }

  // -------- WHITE CARD --------
  Widget _whiteCard() {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            _monthRow(),
            const SizedBox(height: 12),
            _dateScroller(),
            const SizedBox(height: 16),
            _dayTitle(),
            const SizedBox(height: 12),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  // -------- CONTENT (API / LOADING / ERROR) --------
  Widget _buildContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    return _periodList();
  }

  // -------- DATE ROW --------
  Widget _monthRow() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 22),
          onPressed: () => setState(() {
            _centerDate = DateTime(_centerDate.year, _centerDate.month - 1, 1);
            _startDate = _centerDate.subtract(
              Duration(days: _centerDate.weekday - 1),
            );
            _centerCurrentDate();
          }),
        ),
        Expanded(
          child: Center(
            child: Text(
              _monthLabel,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 19,
                color: Color(0xFF2E3192),
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.arrow_forward_ios, size: 22),
          onPressed: () => setState(() {
            _centerDate = DateTime(_centerDate.year, _centerDate.month + 1, 1);
            _startDate = _centerDate.subtract(
              Duration(days: _centerDate.weekday - 1),
            );
            _centerCurrentDate();
          }),
        ),
      ],
    );
  }

  Widget _dateScroller() {
    final screenWidth = MediaQuery.of(context).size.width;
    final arrowWidth = 30.0; // space for arrows
    final itemWidth = (screenWidth - 3 * arrowWidth) / 8; // 7 days visible
    final dates = _visibleDates;

    return SizedBox(
      height: 70,
      child: Stack(
        children: [
          // Centered 7-day row
          Positioned(
            left: arrowWidth,
            right: arrowWidth,
            top: 0,
            bottom: 0,
            child: ListView.builder(
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: dates.length,
              itemBuilder: (context, index) {
                final date = dates[index];
                final selected =
                    date.day == _centerDate.day &&
                    date.month == _centerDate.month &&
                    date.year == _centerDate.year;

                return GestureDetector(
                  onTap: () {
                    setState(() => _centerDate = date);
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => _centerCurrentDate(),
                    );
                  },
                  child: Container(
                    width: itemWidth,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: selected ? Colors.blue : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('EEE').format(date),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: selected ? Colors.white : Colors.black87,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          date.day.toString(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: selected ? Colors.white : Colors.black87,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Left arrow flush with left screen edge
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                setState(() {
                  _centerDate = _centerDate.subtract(const Duration(days: 7));
                  _startDate = _centerDate.subtract(
                    Duration(days: _centerDate.weekday - 1),
                  );
                });
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _centerCurrentDate();
                });
              },
              child: SizedBox(
                width: arrowWidth,
                height: 70,
                child: const Icon(
                  Icons.arrow_back_ios,
                  size: 20,
                  color: Colors.black87,
                ),
              ),
            ),
          ),

          // Right arrow flush with right screen edge
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                setState(() {
                  _centerDate = _centerDate.add(const Duration(days: 7));
                  _startDate = _centerDate.subtract(
                    Duration(days: _centerDate.weekday - 1),
                  );
                });
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _centerCurrentDate();
                });
              },
              child: SizedBox(
                width: arrowWidth,
                height: 70,
                child: const Icon(
                  Icons.arrow_forward_ios,
                  size: 20,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dayTitle() {
    final dayName = DateFormat('EEEE').format(_centerDate);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          dayName,
          style: const TextStyle(
            fontSize: 20,
            color: Color(0xFF2E3192),
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // -------- PERIOD LIST (Filtered by selected day) --------
  Widget _periodList() {
    final weekday = DateFormat('EEEE').format(_centerDate).toLowerCase();

    final dayPeriods = _timetable
        .where((item) => item.dayPeriods[weekday] != null)
        .map(
          (item) => {
            "time": item.dayPeriods[weekday]!,
            "subject": item.subject,
          },
        )
        .toList();

    if (dayPeriods.isEmpty) {
      return const Center(child: Text("No classes for this day"));
    }

    return ListView.builder(
      itemCount: dayPeriods.length,
      itemBuilder: (_, i) {
        final item = dayPeriods[i];
        return _PeriodRow(time: item["time"]!, subject: item["subject"]!);
      },
    );
  }
}

// ----------------- ROW WIDGET -----------------
class _PeriodRow extends StatelessWidget {
  final String time;
  final String subject;

  const _PeriodRow({required this.time, required this.subject});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFCCCCCC), width: 1)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              time,
              style: const TextStyle(fontSize: 14, color: Color(0xFF808080)),
            ),
          ),
          Expanded(
            child: Text(
              subject,
              style: const TextStyle(fontSize: 15, color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }
}
