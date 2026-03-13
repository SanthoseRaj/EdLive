import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class MonthFoodTab extends StatefulWidget {
  const MonthFoodTab({super.key});

  @override
  State<MonthFoodTab> createState() => _MonthFoodTabState();
}

class _MonthFoodTabState extends State<MonthFoodTab> {
  DateTime _selectedMonth = DateTime.now();
  DateTime _selectedDate = DateTime.now();
  Map<String, Map<String, bool>> _foodSelectionsByDate = {};
  Map<String, Map<String, bool>> _confirmedMealsByDate = {};
  Map<String, dynamic>? _weeklyMenu;
  bool _loading = false;
  double _totalAmount = 0.0;

 @override
void initState() {
  super.initState();
  _loadInitialData();
}

Future<void> _loadInitialData() async {
  setState(() => _loading = true);
  await _fetchMenu(); // wait for menu
  await _fetchMonthSchedule(); // then fetch confirmations
  setState(() => _loading = false);
}


  Future<void> _fetchMenu() async {
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("auth_token") ?? "";

      final formattedDate =
          "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";

      final url =
          "https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api/food/weekly-menu?date=$formattedDate";

      final response = await http.get(
        Uri.parse(url),
        headers: {
          "accept": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() => _weeklyMenu = data);
      } else {
        print("Error: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("API Error: $e");
    }
    setState(() => _loading = false);
    _calculateTotal();
  }

  Future<void> _fetchMonthSchedule() async {
  setState(() => _loading = true);
  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("auth_token") ?? "";
    final studentId = prefs.getInt("student_id") ?? 0;

    final firstDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final lastDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    final totalDays = lastDayOfMonth.day;

    Map<String, Map<String, bool>> confirmedMeals = {};
    Map<String, Map<String, bool>> selections = {};

    // 🌀 Run all API calls in parallel to avoid missing dates
    await Future.wait(List.generate(totalDays, (i) async {
      final date = firstDayOfMonth.add(Duration(days: i));
      final dateKey = DateFormat("yyyy-MM-dd").format(date);

      final url =
          "https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api/food/schedule/$studentId/$dateKey";

      try {
        final response = await http.get(
          Uri.parse(url),
          headers: {
            "accept": "application/json",
            "Authorization": "Bearer $token",
          },
        );

        if (response.statusCode == 200 && response.body.isNotEmpty) {
          final data = json.decode(response.body);

          // ✅ Confirm booked meals (from backend)
          final breakfastConfirmed = (data["breakfast_menu_id"] ?? 0) != 0;
          final lunchConfirmed = (data["lunch_menu_id"] ?? 0) != 0;
          final snacksConfirmed = (data["snacks_menu_id"] ?? 0) != 0;

          confirmedMeals[dateKey] = {
            "Breakfast": breakfastConfirmed,
            "Lunch": lunchConfirmed,
            "Snacks": snacksConfirmed,
          };
        } else {
          confirmedMeals[dateKey] = {
            "Breakfast": false,
            "Lunch": false,
            "Snacks": false,
          };
        }
      } catch (e) {
        confirmedMeals[dateKey] = {
          "Breakfast": false,
          "Lunch": false,
          "Snacks": false,
        };
      }

      // Default: user selection reset
      selections[dateKey] = {
        "Breakfast": false,
        "Lunch": false,
        "Snacks": false,
      };
    }));

    // ✅ After all API calls complete, update UI once
    setState(() {
      _confirmedMealsByDate = confirmedMeals;
      _foodSelectionsByDate = selections;
      _loading = false;
    });

    _calculateTotal();
  } catch (e) {
    print("Fetch month schedule error: $e");
    setState(() => _loading = false);
  }
}

  void _calculateTotal() {
    double total = 0.0;
    _foodSelectionsByDate.forEach((dateKey, meals) {
      final date = DateTime.parse(dateKey);
      final weekdayIndex = date.weekday % 7;
      final dayMenu = _weeklyMenu?["$weekdayIndex"];

      meals.forEach((meal, selected) {
        if (!selected) return;
        final mealData = dayMenu?[meal.toLowerCase()];
        if (mealData == null || !(mealData["items"]?.isNotEmpty ?? false)) return;
        total += (mealData["price"] ?? 0).toDouble();
      });
    });

    setState(() => _totalAmount = total);
  }

  void _toggleFood(String dateKey, String mealType) {
    setState(() {
      _foodSelectionsByDate.putIfAbsent(
        dateKey,
        () => {"Breakfast": false, "Lunch": false, "Snacks": false},
      );
      final current = _foodSelectionsByDate[dateKey]![mealType]!;
      _foodSelectionsByDate[dateKey]![mealType] = !current;
    });
    _calculateTotal();
  }

void _selectAllWeek() {
  setState(() {
    // Check if at least one meal is selected anywhere
    bool anySelected = _foodSelectionsByDate.values
        .any((meals) => meals.values.any((selected) => selected));

    // If any selected -> unselect all; else -> select all
    bool shouldSelectAll = !anySelected;

    final firstDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final lastDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    final totalDays = lastDayOfMonth.day;

    for (int i = 0; i < totalDays; i++) {
      final date = firstDayOfMonth.add(Duration(days: i));
      final dateKey = DateFormat("yyyy-MM-dd").format(date);
      final weekdayIndex = date.weekday % 7;
      final dayMenu = _weeklyMenu?["$weekdayIndex"];

      // Initialize if missing
      _foodSelectionsByDate.putIfAbsent(
        dateKey,
        () => {"Breakfast": false, "Lunch": false, "Snacks": false},
      );

      for (final meal in ["Breakfast", "Lunch", "Snacks"]) {
        final hasItems = dayMenu?[meal.toLowerCase()]?["items"]?.isNotEmpty ?? false;

        // Only change meals that have items
        if (hasItems) {
          _foodSelectionsByDate[dateKey]![meal] = shouldSelectAll;
        }
      }
    }
  });

  _calculateTotal();
}

  Future<void> _submitFoodForWeek() async {
    final selectedDays = _foodSelectionsByDate.entries
        .where((e) => e.value.containsValue(true))
        .toList();

    if (selectedDays.isEmpty) return;

    setState(() => _loading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("auth_token") ?? "";
      final studentId = prefs.getInt("student_id") ?? 0;

      for (final entry in selectedDays) {
        final dateKey = entry.key;
        final selections = entry.value;
        final date = DateTime.parse(dateKey);
        final weekdayIndex = date.weekday % 7;
        final dayMenu = _weeklyMenu?["$weekdayIndex"];

        final body = {
          "student_id": studentId,
          "date": dateKey,
          "end_date": dateKey,
          "breakfast_menu_id":
              (selections["Breakfast"]! &&
                      dayMenu?["breakfast"]?["items"]?.isNotEmpty == true)
                  ? dayMenu!["breakfast"]["items"][0]["id"]
                  : null,
          "lunch_menu_id":
              (selections["Lunch"]! &&
                      dayMenu?["lunch"]?["items"]?.isNotEmpty == true)
                  ? dayMenu!["lunch"]["items"][0]["id"]
                  : null,
          "snacks_menu_id":
              (selections["Snacks"]! &&
                      dayMenu?["snacks"]?["items"]?.isNotEmpty == true)
                  ? dayMenu!["snacks"]["items"][0]["id"]
                  : null,
        };

        final url =
            "https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api/food/schedule";

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
          print("✅ Food schedule booked for $dateKey");
        } else {
          print("❌ Failed for $dateKey => ${response.body}");
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Food schedule booked for all selected days!"),
        ),
      );
      _fetchMonthSchedule();
      _calculateTotal();
    } catch (e) {
      print("Submit Week API Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error submitting weekly schedule")),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final lastDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    final totalDays = lastDayOfMonth.day;
    final monthDates = List.generate(totalDays, (i) => firstDayOfMonth.add(Duration(days: i)));

    return Column(
      children: [
        // Month Header
      Padding(
  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      IconButton(
        icon: const Icon(Icons.arrow_left, size: 38),
        onPressed: () {
          setState(() {
            _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
            _selectedDate = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
            _fetchMenu();
            _fetchMonthSchedule();
          });
        },
      ),
      Expanded(
        child: Center(
          child: Text(
            DateFormat('MMMM yyyy').format(_selectedMonth),
            overflow: TextOverflow.ellipsis, // 👈 prevents overflow text
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E3192),
            ),
          ),
        ),
      ),
      IconButton(
        icon: const Icon(Icons.arrow_right, size: 38),
        onPressed: () {
          setState(() {
            _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
            _selectedDate = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
            _fetchMenu();
            _fetchMonthSchedule();
          });
        },
      ),
    ],
  ),
),
        // All Select
     Container(
  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
  color: Colors.white,
  child: Row(
    children: [
      const SizedBox(width: 10),
      GestureDetector(
        onTap: _selectAllWeek,
        child: Builder(
          builder: (_) {
            bool allSelected = true;
            bool anySelected = false;

            _foodSelectionsByDate.forEach((dateKey, dayMeals) {
              final weekdayIndex = DateTime.parse(dateKey).weekday % 7;
              final dayMenu = _weeklyMenu?["$weekdayIndex"];

              ["Breakfast", "Lunch", "Snacks"].forEach((meal) {
                final hasItems =
                    dayMenu?[meal.toLowerCase()]?["items"]?.isNotEmpty ?? false;
                final isSelected = dayMeals[meal] ?? false;
                if (hasItems) {
                  if (!isSelected) allSelected = false;
                  if (isSelected) anySelected = true;
                }
              });
            });

            IconData icon;
            Color color;

            if (allSelected && anySelected) {
              icon = Icons.check_box_rounded;
              color =Colors.blue; // dark blue
            } else if (anySelected) {
              icon = Icons.indeterminate_check_box_rounded;
              color =Colors.blue;
            } else {
              icon = Icons.check_box_outline_blank_rounded;
              color = Colors.grey;
            }

            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                icon,
                key: ValueKey(icon),
                size: 26,
                color: color,
              ),
            );
          },
        ),
      ),
      const SizedBox(width: 6),
      const Text(
        "All",
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
      const Spacer(),
    ],
  ),
),

        const SizedBox(height: 12),

        // Menu List
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  children: monthDates.map((date) {
                    final dateKey = DateFormat("yyyy-MM-dd").format(date);
                    final dayAbbrev = DateFormat('E').format(date);
                    final dayNum = date.day;
                    final weekdayIndex = date.weekday % 7;
                    final dayMenu = _weeklyMenu?["$weekdayIndex"];
                    final selections =
                        _foodSelectionsByDate[dateKey] ?? {"Breakfast": false, "Lunch": false, "Snacks": false};

                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 2,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Day label + select all
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                final allSelected = selections.values.every((v) => v);
                                selections.forEach((key, value) {
                                  final hasItems = dayMenu?[key.toLowerCase()]?["items"]?.isNotEmpty ?? false;
                                  if (hasItems) selections[key] = !allSelected;
                                });
                                _foodSelectionsByDate[dateKey] = selections;
                              });
                              _calculateTotal();
                            },
                            child: Container(
                              width: 40,
                              alignment: Alignment.center,
                              child: Column(
                                children: [
                                  Text(
                                    dayAbbrev,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                  Text(
                                    dayNum.toString(),
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  const SizedBox(height: 4),
                                  Icon(
                                    selections.values.every((v) => v)
                                        ? Icons.check_box
                                        : selections.values.any((v) => v)
                                            ? Icons.indeterminate_check_box
                                            : Icons.check_box_outline_blank,
                                    size: 20,
                                    color: selections.values.any((v) => v) ? Colors.blue : Colors.grey,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Meal Boxes
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: ["Breakfast", "Lunch", "Snacks"].map((meal) {
                                final mealData = dayMenu?[meal.toLowerCase()];
                                final hasItems = mealData?["items"]?.isNotEmpty ?? false;
                                final isAlreadyBooked = _confirmedMealsByDate[dateKey]?[meal] ?? false;
                                final checked = selections[meal] ?? false;
                                final mealPrice = mealData?["price"] ?? 0;
                                final firstItemName = hasItems ? mealData["items"][0]["name"] : "";

                                final screenWidth = MediaQuery.of(context).size.width;
                                final containerWidth = (screenWidth - 100) / 4;
                                final textScale = screenWidth / 400;

                                Color bgColor, borderColor, textColor, priceColor;

                                if (!hasItems) {
                                  // No menu
                                  bgColor = Colors.grey.shade200;
                                  borderColor = Colors.grey.shade300;
                                  textColor = Colors.grey.shade500;
                                  priceColor = Colors.grey.shade500;
                                } else if (isAlreadyBooked) {
                                  // Confirmed meal
                                  bgColor = Colors.blue.shade400;
                                  borderColor = Colors.blue.shade600;
                                  textColor = Colors.white;
                                  priceColor = Colors.white;
                                } else if (checked) {
                                  // Newly selected
                                  bgColor = const Color(0xFF2E3192);
                                  borderColor = const Color(0xFF2E3192);
                                  textColor = Colors.white;
                                  priceColor = Colors.white;
                                } else {
                                  // Available but not booked
                                  bgColor = Colors.white;
                                  borderColor = Colors.grey.shade300;
                                  textColor = Colors.black;
                                  priceColor = Colors.black54;
                                }

                                return GestureDetector(
                                  onTap: (!hasItems || isAlreadyBooked) ? null : () => _toggleFood(dateKey, meal),
                                  child: Container(
                                    width: containerWidth,
                                    margin: const EdgeInsets.symmetric(horizontal: 2),
                                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                                    decoration: BoxDecoration(
                                      color: bgColor,
                                      border: Border.all(color: borderColor),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          meal,
                                          style: TextStyle(
                                            color: textColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12 * textScale.clamp(0.9, 1.1),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                        ),
                                        Text(
                                          firstItemName,
                                          style: TextStyle(
                                            color: textColor,
                                            fontSize: 10 * textScale.clamp(0.9, 1.1),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          "₹$mealPrice",
                                          style: TextStyle(
                                            fontSize: 12 * textScale.clamp(0.9, 1.1),
                                            color: priceColor,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (isAlreadyBooked)
                                          const Padding(
                                            padding: EdgeInsets.only(top: 2),
                                            child: Icon(
                                              Icons.check_circle,
                                              size: 14,
                                              color: Colors.white,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),

        // Book Button with Total
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: _foodSelectionsByDate.values.any((day) => day.containsValue(true))
                ? _submitFoodForWeek
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _foodSelectionsByDate.values.any((day) => day.containsValue(true))
                  ? Colors.blue
                  : const Color(0xFFCCCCCC),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: Text(
              _totalAmount > 0
                  ? "Book All Selected Days (₹${_totalAmount.toStringAsFixed(0)})"
                  : "Book All Selected Days",
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }
}
