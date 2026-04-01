import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../config/config.dart';

class DashboardCountsProvider with ChangeNotifier {
  static const String _storagePrefix = 'dashboard_badge_baseline_student_';
  static const Map<String, List<String>> _latestMessageAliases =
      <String, List<String>>{
        'notifications': <String>['notifications', 'notification'],
        'todo': <String>['todo', 'todos', 'homework', 'home_work'],
        'payments': <String>['payments', 'payment', 'fees', 'fee'],
        'messages': <String>['messages', 'message'],
        'library': <String>['library', 'books', 'book'],
        'achievements': <String>['achievements', 'achievement'],
      };

  int notifications = 0;
  int todo = 0;
  int payments = 0;
  int messages = 0;
  int library = 0;
  int achievements = 0;

  final Map<String, int> _rawCounts = <String, int>{
    'notifications': 0,
    'todo': 0,
    'payments': 0,
    'messages': 0,
    'library': 0,
    'achievements': 0,
  };
  final Map<String, int> _baselineCounts = <String, int>{};
  final Map<String, String> _latestMessages = <String, String>{};
  int? _currentStudentId;

  bool isLoading = false;
  String? error;

  String? latestMessageFor(String itemType) {
    for (final key in _latestMessageAliases[itemType] ?? <String>[itemType]) {
      final message = _latestMessages[key];
      if (message == null) {
        continue;
      }

      final trimmedMessage = message.trim();
      if (trimmedMessage.isNotEmpty) {
        return trimmedMessage;
      }
    }

    return null;
  }

  String? subtitleFor(String itemType, {String? fallback}) {
    return latestMessageFor(itemType) ?? fallback;
  }

  String _storageKey(int studentId) => '$_storagePrefix$studentId';

  Map<String, int> _decodeBaselineCounts(String? rawValue) {
    if (rawValue == null || rawValue.isEmpty) {
      return <String, int>{};
    }

    try {
      final decoded = json.decode(rawValue);
      if (decoded is! Map<String, dynamic>) {
        return <String, int>{};
      }

      return decoded.map<String, int>((key, value) {
        final parsed = value is int
            ? value
            : int.tryParse(value.toString()) ?? 0;
        return MapEntry(key, parsed);
      });
    } catch (_) {
      return <String, int>{};
    }
  }

  Map<String, String> _decodeLatestMessages(dynamic rawValue) {
    if (rawValue is! Map) {
      return <String, String>{};
    }

    final parsedMessages = <String, String>{};
    for (final entry in rawValue.entries) {
      final key = entry.key.toString().trim();
      final value = entry.value?.toString().trim() ?? '';
      if (key.isEmpty || value.isEmpty) {
        continue;
      }
      parsedMessages[key] = value;
    }
    return parsedMessages;
  }

  Future<void> _persistBaselineCounts() async {
    final studentId = _currentStudentId;
    if (studentId == null) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey(studentId), json.encode(_baselineCounts));
  }

  int _resolveVisibleCount(String itemType, void Function() onAdjusted) {
    final raw = _rawCounts[itemType] ?? 0;
    final baseline = _baselineCounts[itemType] ?? 0;

    if (raw < baseline) {
      _baselineCounts[itemType] = raw;
      onAdjusted();
      return 0;
    }

    return raw - baseline;
  }

  bool _applyVisibleCounts() {
    var adjusted = false;
    void markAdjusted() {
      adjusted = true;
    }

    notifications = _resolveVisibleCount('notifications', markAdjusted);
    todo = _resolveVisibleCount('todo', markAdjusted);
    payments = _resolveVisibleCount('payments', markAdjusted);
    messages = _resolveVisibleCount('messages', markAdjusted);
    library = _resolveVisibleCount('library', markAdjusted);
    achievements = _resolveVisibleCount('achievements', markAdjusted);
    return adjusted;
  }

  void _resetVisibleState() {
    notifications = 0;
    todo = 0;
    payments = 0;
    messages = 0;
    library = 0;
    achievements = 0;
    _rawCounts.updateAll((_, _) => 0);
    _baselineCounts.clear();
    _latestMessages.clear();
  }

  Future<void> fetchDashboardCounts(int studentId) async {
    if (isLoading) {
      return;
    }

    try {
      isLoading = true;
      error = null;
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("auth_token");

      if (token == null) {
        error = "No auth token found";
        isLoading = false;
        notifyListeners();
        return;
      }

      final studentChanged =
          _currentStudentId != null && _currentStudentId != studentId;
      _currentStudentId = studentId;
      if (studentChanged) {
        _resetVisibleState();
        notifyListeners();
      }
      _baselineCounts
        ..clear()
        ..addAll(
          _decodeBaselineCounts(prefs.getString(_storageKey(studentId))),
        );

      final response = await http.get(
        AppConfig.apiUri(
          '/dashboard/counts',
          queryParameters: {'studentId': studentId},
        ),
        headers: {
          "Authorization": "Bearer $token",
          "accept": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        _rawCounts['notifications'] = data["notifications"] ?? 0;
        _rawCounts['todo'] = data["todo"] ?? 0;
        _rawCounts['payments'] = data["payments"] ?? 0;
        _rawCounts['messages'] = data["messages"] ?? 0;
        _rawCounts['library'] = data["library"] ?? 0;
        _rawCounts['achievements'] = data["achievements"] ?? 0;
        _latestMessages
          ..clear()
          ..addAll(_decodeLatestMessages(data["latest_messages"]));

        final baselinesAdjusted = _applyVisibleCounts();
        if (baselinesAdjusted) {
          await _persistBaselineCounts();
        }
      } else {
        error = "Failed to load counts (${response.statusCode})";
      }
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> clearBadgeCount(String itemType) async {
    if (!_rawCounts.containsKey(itemType)) {
      return;
    }

    _baselineCounts[itemType] = _rawCounts[itemType] ?? 0;

    switch (itemType) {
      case 'notifications':
        notifications = 0;
        break;
      case 'todo':
        todo = 0;
        break;
      case 'payments':
        payments = 0;
        break;
      case 'messages':
        messages = 0;
        break;
      case 'library':
        library = 0;
        break;
      case 'achievements':
        achievements = 0;
        break;
      default:
        return;
    }

    await _persistBaselineCounts();
    notifyListeners();
  }
}
