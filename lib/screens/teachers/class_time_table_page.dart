import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/teacher_period_model.dart';
import 'package:intl/intl.dart';

class TimeTablePage extends StatefulWidget {
  const TimeTablePage({super.key});

  @override
  State<TimeTablePage> createState() => _TimeTablePageState();
}

class _TimeTablePageState extends State<TimeTablePage> {
  DateTime _centerDate = DateTime.now();
  final ScrollController _scrollController = ScrollController();
  List<dynamic> _classSchedule = [];
  bool _isLoading = true;
  String _errorMessage = '';
  List<dynamic> _timetableData = [];
  DateTime _startDate = DateTime.now().subtract(
    Duration(days: DateTime.now().weekday - 1),
  );

  @override
  void initState() {
    super.initState();
    fetchTimetable();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerCurrentDate();
    });
  }

  void _centerCurrentDate() {
    final itemWidth = MediaQuery.of(context).size.width / 7;
    final today = DateTime.now();
    final index = today.difference(_startDate).inDays;

    final offset = (index * itemWidth) - (MediaQuery.of(context).size.width / 2) + (itemWidth / 2);

  

    _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> fetchTimetable() async {
    final prefs = await SharedPreferences.getInstance();
final token = prefs.getString('auth_token') ?? '';    
final userData = prefs.getString('user_data');
final user = jsonDecode(userData!);

    final url = 'https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api/staff/staff/timetable/2024-2025';
  final response = await http.get(
  Uri.parse(url),
  headers: {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token', // ✅ Add this line
  },
);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        _classSchedule = data;
        _isLoading = false;
      });
    } else {
      _isLoading = false;
      throw Exception('Failed to load timetable');
    }
  }

void _onDateTap(DateTime date, int index) {
  setState(() {
    _centerDate = date;
  });

  final screenWidth = MediaQuery.of(context).size.width;
  final itemWidth = screenWidth / 7; // No spacing

  final offset = (index - 3) * itemWidth;

  _scrollController.animateTo(
    offset.clamp(0.0, _scrollController.position.maxScrollExtent),
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeInOut,
  );
}

  List<DateTime> get _visibleDates => List.generate(30, (index) => _startDate.add(Duration(days: index)));

  List<dynamic> _getClassesForSelectedDay() {
    if (_classSchedule.isEmpty) return [];

    String dayName = DateFormat('EEEE').format(_centerDate).toLowerCase();
    String periodIdKey = '${dayName}_period_id';

    var filteredClasses = _classSchedule.where((classItem) {
      return classItem[dayName] != null && classItem[dayName].toString().isNotEmpty;
    }).toList();

    filteredClasses.sort((a, b) {
      int aPeriod = a[periodIdKey] ?? 0;
      int bPeriod = b[periodIdKey] ?? 0;
      return aPeriod.compareTo(bPeriod);
    });

    return filteredClasses;
  }

  @override
  Widget build(BuildContext context) {
 final screenWidth = MediaQuery.of(context).size.width;
final containerSpacing = 4.0; // 2 left + 2 right margin
final itemWidth = (screenWidth - (6 * containerSpacing)) / 7;



    final currentMonth = DateFormat('MMMM yyyy').format(_centerDate);
    final classesForDay = _getClassesForSelectedDay();
    final dayName = DateFormat('EEEE').format(_centerDate).toLowerCase();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              children: [
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_left),
                      onPressed: () {
                        setState(() {
                          _centerDate = DateTime(_centerDate.year, _centerDate.month - 1, _centerDate.day);
                        });
                      },
                    ),
                    Text(
                      currentMonth,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: screenWidth * 0.05,
                        color: const Color(0xFF2E3192),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_right),
                      onPressed: () {
                        setState(() {
                          _centerDate = DateTime(_centerDate.year, _centerDate.month + 1, _centerDate.day);
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 4),
            
SizedBox(
  height: 80, // Adjust height as needed
  child: Stack(
    clipBehavior: Clip.none,
    children: [
      Positioned.fill(
        child: ListView.builder(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          itemCount: _visibleDates.length,
          physics: const BouncingScrollPhysics(),
          itemBuilder: (context, index) {
            final date = _visibleDates[index];
            final isSelected = _centerDate.day == date.day &&
                _centerDate.month == date.month &&
                _centerDate.year == date.year;

      return GestureDetector(
  onTap: () => _onDateTap(date, index),
  child: SizedBox(
    width: itemWidth, // 🔥 Exactly 1/7th of screen
    child: Container(
      // ❌ no margin here
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue : Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 10), // ✅ internal padding only
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            DateFormat('EEE').format(date),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : Colors.black87,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            date.day.toString(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : Colors.black87,
              fontSize: 12,
            ),
          ),
        ],
      ),
    ),
  ),
);
    },
        ),
      ),
      // Left arrow
      Positioned(
        left: -12,
        top: 0,
        bottom: 0,
        child: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 16),
          onPressed: () {
            setState(() {
              _startDate = _startDate.subtract(const Duration(days: 7));
              _centerCurrentDate();
            });
          },
        ),
      ),
      // Right arrow
      Positioned(
        right: -12,
        top: 0,
        bottom: 0,
        child: IconButton(
          icon: const Icon(Icons.arrow_forward_ios, size: 16),
          onPressed: () {
            setState(() {
              _startDate = _startDate.add(const Duration(days: 7));
              _centerCurrentDate();
            });
          },
        ),
      ),
    ],
  ),
),
           const SizedBox(height: 2),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_errorMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(color: Colors.red, fontSize: 14),
                    ),
                  )
                else if (classesForDay.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Text(
                      "No classes scheduled for today",
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: classesForDay.length,
                    separatorBuilder: (context, index) => const Divider(
                      thickness: 0.5,
                      color: Colors.grey,
                      height: 1,
                    ),
                    itemBuilder: (context, index) {
                      final classItem = classesForDay[index];
                      final time = classItem[dayName];
                      final subject = classItem['subject'] ?? '';
                      final className = classItem['class'] ?? '';
                      final isUpcoming = index > 0;

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
  Text(
    time ?? '',
    style: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: Colors.black87, // ✅ fixed color
    ),
  ),
  const SizedBox(height: 4),
  Text(
    "$className - $subject",
    style: const TextStyle(
      fontSize: 14,
      color: Colors.grey,
    ),
  ),
],

                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
