import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/teacher_period_model.dart';
import 'package:school_app/config/config.dart';

class TimetableEntry {
  final String className;
  final String subject;
  final Map<String, int?> periodIds;

  TimetableEntry({
    required this.className,
    required this.subject,
    required this.periodIds,
  });

  factory TimetableEntry.fromJson(Map<String, dynamic> json) {
    return TimetableEntry(
      className: json['class'] ?? '',
      subject: json['subject'] ?? '',
      periodIds: {
        'monday': json['monday_period_id'],
        'tuesday': json['tuesday_period_id'],
        'wednesday': json['wednesday_period_id'],
        'thursday': json['thursday_period_id'],
        'friday': json['friday_period_id'],
        'saturday': json['saturday_period_id'],
      },
    );
  }
}

class TimetableProvider with ChangeNotifier {
  List<Period> periods = [];
  List<TimetableEntry> entries = [];
  bool loading = false;
  int selectedDayIndex = 0;

  final List<String> weekdays = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
  ];

  Future<void> loadAll() async {
    loading = true;
    notifyListeners();

    await fetchPeriods();
    await fetchTimetable();

    loading = false;
    notifyListeners();
  }

  Future<void> fetchPeriods() async {
    final url = Uri.parse('${AppConfig.baseUrl}/master/periods');
    final res = await http.get(url);
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as List;
      periods = data.map((e) => Period.fromJson(e)).toList();
    }
  }

  Future<void> fetchTimetable() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final url = Uri.parse(
      '${AppConfig.baseUrl}/staff/staff/timetable/${AppConfig.academicYear}',
    );
    final res = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as List;
      entries = data.map((e) => TimetableEntry.fromJson(e)).toList();
    }
  }

  void selectDay(int index) {
    selectedDayIndex = index;
    notifyListeners();
  }

  String? getClassSubject(int periodId) {
    final weekday = weekdays[selectedDayIndex];
    for (final entry in entries) {
      if (entry.periodIds[weekday] == periodId) {
        return '${entry.className} - ${entry.subject}';
      }
    }
    return null;
  }
}
