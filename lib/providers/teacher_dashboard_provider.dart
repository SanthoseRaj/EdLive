import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/config.dart';
import '../models/teacher_dashboard_counts.dart';

class DashboardProvider with ChangeNotifier {
  static const String _storagePrefix = 'dashboard_badge_baseline_teacher_';

  DashboardCounts? _counts;
  DashboardCounts? _rawCounts;
  bool _isLoading = false;
  final Map<String, int> _baselineCounts = <String, int>{};
  int? _currentTeacherId;

  DashboardCounts? get counts => _counts;
  bool get isLoading => _isLoading;

  String _storageKey(int? teacherId) => '$_storagePrefix${teacherId ?? 0}';

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

  Future<void> _persistBaselineCounts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey(_currentTeacherId),
      json.encode(_baselineCounts),
    );
  }

  int _resolveVisibleCount(
    String itemType,
    int rawValue,
    void Function() onAdjusted,
  ) {
    final baseline = _baselineCounts[itemType] ?? 0;
    if (rawValue < baseline) {
      _baselineCounts[itemType] = rawValue;
      onAdjusted();
      return 0;
    }

    return rawValue - baseline;
  }

  DashboardCounts _buildVisibleCounts(
    DashboardCounts raw,
    void Function() onAdjusted,
  ) {
    return raw.copyWith(
      notifications: _resolveVisibleCount(
        'notifications',
        raw.notifications,
        onAdjusted,
      ),
      todo: _resolveVisibleCount('todo', raw.todo, onAdjusted),
      payments: _resolveVisibleCount('payments', raw.payments, onAdjusted),
      messages: _resolveVisibleCount('messages', raw.messages, onAdjusted),
      library: _resolveVisibleCount('library', raw.library, onAdjusted),
      achievements: _resolveVisibleCount(
        'achievements',
        raw.achievements,
        onAdjusted,
      ),
    );
  }

  int _rawValueForItemType(String itemType, DashboardCounts counts) {
    switch (itemType) {
      case 'notifications':
        return counts.notifications;
      case 'todo':
        return counts.todo;
      case 'payments':
        return counts.payments;
      case 'messages':
        return counts.messages;
      case 'library':
        return counts.library;
      case 'achievements':
        return counts.achievements;
      default:
        return 0;
    }
  }

  bool _countsEqual(DashboardCounts? left, DashboardCounts? right) {
    if (identical(left, right)) {
      return true;
    }
    if (left == null || right == null) {
      return left == right;
    }

    return left.notifications == right.notifications &&
        left.todo == right.todo &&
        left.payments == right.payments &&
        left.messages == right.messages &&
        left.library == right.library &&
        left.achievements == right.achievements;
  }

  Future<void> fetchCounts({bool showLoading = true}) async {
    if (_isLoading) {
      return;
    }

    var shouldNotify = false;
    if (showLoading) {
      _isLoading = true;
      notifyListeners();
    } else {
      _isLoading = true;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      _currentTeacherId = prefs.getInt('teacher_id');
      _baselineCounts
        ..clear()
        ..addAll(
          _decodeBaselineCounts(
            prefs.getString(_storageKey(_currentTeacherId)),
          ),
        );

      final response = await http.get(
        AppConfig.apiUri('/dashboard/counts'),
        headers: {
          'accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final nextRawCounts = DashboardCounts.fromJson(data);

        var baselinesAdjusted = false;
        void markAdjusted() {
          baselinesAdjusted = true;
        }

        final nextVisibleCounts = _buildVisibleCounts(
          nextRawCounts,
          markAdjusted,
        );
        shouldNotify =
            shouldNotify || !_countsEqual(_counts, nextVisibleCounts);
        _rawCounts = nextRawCounts;
        _counts = nextVisibleCounts;
        if (baselinesAdjusted) {
          await _persistBaselineCounts();
        }
      } else if (showLoading) {
        shouldNotify = shouldNotify || _counts != null;
        _rawCounts = null;
        _counts = null;
      }
    } catch (_) {
      if (showLoading) {
        shouldNotify = shouldNotify || _counts != null;
      }
      if (showLoading) {
        _rawCounts = null;
        _counts = null;
      }
    }

    _isLoading = false;
    if (showLoading || shouldNotify) {
      notifyListeners();
    }
  }

  Future<void> markDashboardItemViewedByType({
    required String itemType,
    required int itemId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        return;
      }

      final response = await http.post(
        AppConfig.apiUri('/dashboard/viewed'),
        headers: {
          'accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'item_type': itemType, 'item_id': itemId}),
      );

      if (response.statusCode == 200) {
        debugPrint('Marked $itemType $itemId as viewed');
      } else {
        debugPrint('Failed to mark $itemType $itemId viewed: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error marking $itemType viewed: $e');
    }
  }

  Future<void> markDashboardItemViewed(int itemId) {
    return markDashboardItemViewedByType(itemType: 'payments', itemId: itemId);
  }

  Future<void> clearBadgeCount(String itemType) async {
    final rawCounts = _rawCounts;
    if (rawCounts == null) {
      return;
    }

    _baselineCounts[itemType] = _rawValueForItemType(itemType, rawCounts);
    _counts = _buildVisibleCounts(rawCounts, () {});

    await _persistBaselineCounts();
    notifyListeners();
  }
}
