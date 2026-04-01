import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import 'food_tile.dart';
import 'package:school_app/config/config.dart';

class DayFoodTab extends StatefulWidget {
  const DayFoodTab({super.key});

  @override
  State<DayFoodTab> createState() => _DayFoodTabState();
}

class _DayFoodTabState extends State<DayFoodTab> {
  DateTime _selectedMonth = DateTime.now();
  DateTime _selectedDate = DateTime.now();
  Map<String, Map<String, bool>> _foodSelectionsByDate = {};
  Map<String, dynamic>? _weeklyMenu;
  bool _loading = false;
  List<String> _weekdays = [];
  bool _isLoading = true;

  late ScrollController _scroll;
  late DateTime _centerDate;
  late DateTime _startDate;
  List<DateTime> _visibleDates = [];

  @override
  void initState() {
    super.initState();
    _centerDate = DateTime.now();
    _startDate = _centerDate.subtract(Duration(days: _centerDate.weekday - 1));
    _generateVisibleDates();
    _scroll = ScrollController();
    _fetchMenu();
    _loadData();
    _fetchScheduleForDate(_selectedDate);
  }

  void _generateVisibleDates() {
    _visibleDates = List.generate(30, (i) => _startDate.add(Duration(days: i)));
  }

  void _centerCurrentDate() {
    final index = _visibleDates.indexWhere(
      (d) =>
          d.day == _centerDate.day &&
          d.month == _centerDate.month &&
          d.year == _centerDate.year,
    );

    if (index != -1) {
      final itemWidth =
          (MediaQuery.of(context).size.width - 3 * 30) /
          8; // same as in _dateScroller
      _scroll.animateTo(
        index * itemWidth,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + 1,
        1,
      );

      // ✅ Reset week section to first week of month
      _selectedDate = _selectedMonth;
      _centerDate = _selectedDate;
      _startDate = _centerDate.subtract(
        Duration(days: _centerDate.weekday - 1),
      );
      _generateVisibleDates();
      _fetchMenu();
      _fetchScheduleForDate(_selectedDate);
    });
  }

  void _toggleFood(String key, bool value) {
    final dateKey = DateFormat("yyyy-MM-dd").format(_selectedDate);

    setState(() {
      // Ensure map exists for the date
      _foodSelectionsByDate.putIfAbsent(
        dateKey,
        () => {"Breakfast": false, "Lunch": false, "Snacks": false},
      );

      _foodSelectionsByDate[dateKey]![key] = value;
    });
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month - 1,
        1,
      );

      // ✅ Reset week section to first week of month
      _selectedDate = _selectedMonth;
      _centerDate = _selectedDate;
      _startDate = _centerDate.subtract(
        Duration(days: _centerDate.weekday - 1),
      );
      _generateVisibleDates();
      _fetchMenu();
      _fetchScheduleForDate(_selectedDate);
    });
  }

  String get _monthYear {
    return "${_monthNames[_selectedMonth.month - 1]}. ${_selectedMonth.year}";
  }

  static const List<String> _monthNames = [
    "Jan",
    "Feb",
    "Mar",
    "Apr",
    "May",
    "Jun",
    "Jul",
    "Aug",
    "Sep",
    "Oct",
    "Nov",
    "Dec",
  ];

  // ... (Copy all the day-specific methods from your original code)
  // _centerCurrentDate, _fetchScheduleForDate, _submitFoodForSelectedDate,
  // _fetchMenu, _toggleFood, fetchWeekdays, _loadData, _previousMonth,
  // _nextMonth, _previousWeek, _nextWeek, get _monthYear, etc.

  Future<void> _fetchMenu() async {
    setState(() => _loading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("auth_token") ?? "";

      final formattedDate =
          "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";

      final url = "${AppConfig.baseUrl}/food/weekly-menu?date=$formattedDate";

      final response = await http.get(
        Uri.parse(url),
        headers: {
          "accept": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        setState(() {
          _weeklyMenu = data; // store entire week instead of only one day
        });
      } else {
        print("Error: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("API Error: $e");
    }

    setState(() => _loading = false);
  }

  Future<void> _submitFoodForSelectedDate() async {
    final dateKey = DateFormat("yyyy-MM-dd").format(_selectedDate);
    final selections = _foodSelectionsByDate[dateKey];

    if (selections == null || !selections.containsValue(true)) return;

    setState(() => _loading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("auth_token") ?? "";
      final studentId = prefs.getInt("student_id") ?? 0;

      final weekdayIndex = _selectedDate.weekday % 7; // ✅
      final dayMenu = _weeklyMenu?["$weekdayIndex"];

      final body = {
        "student_id": studentId,
        "date": dateKey,
        "end_date": dateKey, // ✅ added
        "breakfast_menu_id":
            (selections["Breakfast"]! &&
                dayMenu?["breakfast"]?["items"]?.isNotEmpty == true)
            ? dayMenu!["breakfast"]["items"][0]["id"]
            : null,
        "lunch_menu_id":
            (selections["Lunch"]! &&
                dayMenu?["lunch"]?["items"]?.isNotEmpty == true)
            ? dayMenu["lunch"]["items"][0]["id"]
            : null,
        "snacks_menu_id":
            (selections["Snacks"]! &&
                dayMenu?["snacks"]?["items"]?.isNotEmpty == true)
            ? dayMenu["snacks"]["items"][0]["id"]
            : null,
      };

      final url = "${AppConfig.baseUrl}/food/schedule";

      final response = await http.post(
        Uri.parse(url),
        headers: {
          "accept": "application/json",
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("✅ Order Booked for $dateKey")));
      } else {
        print("❌ Error ${response.statusCode}: ${response.body}");
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Failed to Book order")));
      }
    } catch (e) {
      print("Submit API Error: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Error submitting order")));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadData() async {
    try {
      final days = await fetchWeekdays();
      setState(() {
        _weekdays = days;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchScheduleForDate(DateTime date) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("auth_token") ?? "";
      final studentId = prefs.getInt("student_id") ?? 0;

      final dateKey = DateFormat("yyyy-MM-dd").format(date);
      final apiDate =
          "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

      final url = "${AppConfig.baseUrl}/food/schedule/$studentId/$apiDate";

      final response = await http.get(
        Uri.parse(url),
        headers: {
          "accept": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _foodSelectionsByDate[dateKey] = {
            "Breakfast": (data["breakfast_menu_id"] ?? 0) != 0,
            "Lunch": (data["lunch_menu_id"] ?? 0) != 0,
            "Snacks": (data["snacks_menu_id"] ?? 0) != 0,
          };
        });
      } else {
        setState(() {
          _foodSelectionsByDate[dateKey] = {
            "Breakfast": false,
            "Lunch": false,
            "Snacks": false,
          };
        });
      }
    } catch (e) {
      print("Fetch schedule error: $e");
    }
  }

  Future<List<String>> fetchWeekdays() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/weekdays'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((day) => day['day'] as String).toList();
    } else {
      throw Exception('Failed to load weekdays');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _dateScroller(),
        _buildWeekdaysSection(),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _weeklyMenu == null
              ? const Center(child: Text("No menu available"))
              : Builder(
                  builder: (context) {
                    final weekdayIndex = _selectedDate.weekday % 7;
                    final dayMenu = _weeklyMenu?["$weekdayIndex"];
                    final dateKey = DateFormat(
                      "yyyy-MM-dd",
                    ).format(_selectedDate);

                    if (dayMenu == null ||
                        (dayMenu["breakfast"] == null &&
                            dayMenu["lunch"] == null &&
                            dayMenu["snacks"] == null)) {
                      return _buildNoMenuCard();
                    }

                    final breakfastItems = dayMenu["breakfast"]?["items"] ?? [];
                    final lunchItems = dayMenu["lunch"]?["items"] ?? [];
                    final snacksItems = dayMenu["snacks"]?["items"] ?? [];

                    final breakfastAvailable = breakfastItems.isNotEmpty;
                    final lunchAvailable = lunchItems.isNotEmpty;
                    final snacksAvailable = snacksItems.isNotEmpty;

                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        FoodTile(
                          keyName: "Breakfast-$weekdayIndex",
                          title: dayMenu["breakfast"] != null
                              ? "Breakfast (${dayMenu["breakfast"]["price"]}₹)"
                              : "Breakfast",
                          time: "8 : 30 am - 09 : 30 am",
                          items: breakfastItems,
                          checked:
                              (_foodSelectionsByDate[dateKey]?["Breakfast"] ??
                                  false) &&
                              breakfastAvailable,
                          enabled: breakfastAvailable,
                          onChanged: (v) => _toggleFood("Breakfast", v),
                        ),
                        FoodTile(
                          keyName: "Lunch-$weekdayIndex",
                          title: dayMenu["lunch"] != null
                              ? "Lunch (${dayMenu["lunch"]["price"]}₹)"
                              : "Lunch",
                          time: "12 : 30 pm - 01 : 30 pm",
                          items: lunchItems,
                          checked:
                              (_foodSelectionsByDate[dateKey]?["Lunch"] ??
                                  false) &&
                              lunchAvailable,
                          enabled: lunchAvailable,
                          onChanged: (v) => _toggleFood("Lunch", v),
                        ),
                        FoodTile(
                          keyName: "Snacks-$weekdayIndex",
                          title: dayMenu["snacks"] != null
                              ? "Snacks (${dayMenu["snacks"]["price"]}₹)"
                              : "Snacks",
                          time: "3 : 30 pm - 4 : 00 pm",
                          items: snacksItems,
                          checked:
                              (_foodSelectionsByDate[dateKey]?["Snacks"] ??
                                  false) &&
                              snacksAvailable,
                          enabled: snacksAvailable,
                          onChanged: (v) => _toggleFood("Snacks", v),
                        ),
                      ],
                    );
                  },
                ),
        ),
        // Book Button
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: _isAnySelected ? _submitFoodForSelectedDate : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isAnySelected
                  ? Colors.blue
                  : const Color(0xFFCCCCCC),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: const Text(
              "Book",
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }

  bool get _isAnySelected {
    final dateKey = DateFormat("yyyy-MM-dd").format(_selectedDate);
    final selections = _foodSelectionsByDate[dateKey] ?? {};

    final weekdayIndex = _selectedDate.weekday % 7;
    final dayMenu = _weeklyMenu?["$weekdayIndex"];

    if (dayMenu == null ||
        (dayMenu["breakfast"] == null &&
            dayMenu["lunch"] == null &&
            dayMenu["snacks"] == null)) {
      return false;
    }

    return selections.containsValue(true);
  }

  Widget _buildNoMenuCard() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: const [
                Icon(Icons.fastfood, size: 40, color: Colors.grey),
                SizedBox(height: 12),
                Text(
                  "No menu available for this day",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _dateScroller() {
    final screenWidth = MediaQuery.of(context).size.width;
    final arrowWidth = 30.0;
    final itemWidth = (screenWidth - 3 * arrowWidth) / 7;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 🔹 Month selector
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.black),
                onPressed: _previousMonth,
              ),
              Text(
                _monthYear,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E3192),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.black),
                onPressed: _nextMonth,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 🔹 Week scroll
          SizedBox(
            height: 70,
            child: Stack(
              children: [
                // Scrollable dates
                Positioned(
                  left: arrowWidth,
                  right: arrowWidth,
                  top: 0,
                  bottom: 0,
                  child: ListView.builder(
                    controller: _scroll,
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _visibleDates.length,
                    itemBuilder: (context, index) {
                      final date = _visibleDates[index];
                      final selected =
                          date.day == _centerDate.day &&
                          date.month == _centerDate.month &&
                          date.year == _centerDate.year;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _centerDate = date;
                            _selectedDate = date;
                          });

                          // initialize default selections
                          _foodSelectionsByDate.putIfAbsent(
                            DateFormat("yyyy-MM-dd").format(date),
                            () => {
                              "Breakfast": false,
                              "Lunch": false,
                              "Snacks": false,
                            },
                          );

                          _fetchMenu();
                          _fetchScheduleForDate(
                            date,
                          ); // ✅ also fetch schedule status
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
                              if (selected)
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.4),
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
                                  color: selected
                                      ? Colors.white
                                      : Colors.black87,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                date.day.toString(),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: selected
                                      ? Colors.white
                                      : Colors.black87,
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

                // Left arrow
                // Left arrow
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () {
                      setState(() {
                        _centerDate = _centerDate.subtract(
                          const Duration(days: 7),
                        );
                        _selectedDate = _centerDate; // ✅ update selected date
                        _startDate = _centerDate.subtract(
                          Duration(days: _centerDate.weekday - 1),
                        );
                        _generateVisibleDates();
                      });
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _centerCurrentDate();
                        _fetchMenu();
                        _fetchScheduleForDate(
                          _selectedDate,
                        ); // ✅ update weekdays section
                      });
                    },
                    child: const SizedBox(
                      width: 30,
                      height: 70,
                      child: Icon(
                        Icons.arrow_back_ios,
                        size: 20,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),

                // Right arrow
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () {
                      setState(() {
                        _centerDate = _centerDate.add(const Duration(days: 7));
                        _selectedDate = _centerDate; // ✅ update selected date
                        _startDate = _centerDate.subtract(
                          Duration(days: _centerDate.weekday - 1),
                        );
                        _generateVisibleDates();
                      });
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _centerCurrentDate();
                        _fetchMenu();
                        _fetchScheduleForDate(
                          _selectedDate,
                        ); // ✅ update weekdays section
                      });
                    },
                    child: const SizedBox(
                      width: 30,
                      height: 70,
                      child: Icon(
                        Icons.arrow_forward_ios,
                        size: 20,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdaysSection() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_weekdays.isEmpty) {
      return const Center(child: Text(""));
    }

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Weekdays",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E3192),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _weekdays.asMap().entries.map((entry) {
              final index = entry.key;
              final day = entry.value;
              final isSelected = _selectedDate.weekday - 1 == index;

              return ChoiceChip(
                label: Text(day),
                selected: isSelected,
                selectedColor: const Color(0xFF2E3192),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF2E3192),
                ),
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      // pick correct date for that weekday in current week
                      _selectedDate = _startDate.add(Duration(days: index));
                      _centerDate = _selectedDate;
                      _fetchMenu();
                    });
                  }
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
