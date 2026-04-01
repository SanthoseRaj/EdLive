import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:school_app/config/config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/co_curricular_stat.dart';

class CoCurricularProvider extends ChangeNotifier {
  static const String _storageKeyPrefix = 'co_curricular_stats_order_';
  static const int _maxStoredOrderItems = 100;

  List<CoCurricularStat> stats = [];
  bool isLoading = false;
  String? error;

  Future<void> fetchStats({int? classId, String? academicYear}) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        throw Exception("No token found");
      }

      final queryParameters = <String, String>{};

      if (classId != null) {
        queryParameters['classId'] = classId.toString();
      }
      if (academicYear != null && academicYear.trim().isNotEmpty) {
        queryParameters['academicYear'] = academicYear.trim();
      }

      final uri = AppConfig.apiUri(
        '/co-curricular/stats',
        queryParameters: queryParameters.isEmpty ? null : queryParameters,
      );

      final response = await http.get(
        uri,
        headers: {
          "Authorization": "Bearer $token",
          "Accept": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        stats = data.map((e) => CoCurricularStat.fromJson(e)).toList();
        _sortStatsNewestFirst();
        _applyStoredOrder(prefs);
      } else {
        error = "Failed to load stats (${response.statusCode})";
      }
    } catch (e) {
      error = e.toString();
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> prioritizeStat({
    required String activityName,
    required String categoryName,
    required String className,
  }) async {
    final statKey = _buildKey(
      activityName: activityName,
      categoryName: categoryName,
      className: className,
    );

    final didMove = _moveStatToTop(statKey);
    await _saveStoredOrder(statKey);

    if (didMove) {
      notifyListeners();
    }
  }

  void _sortStatsNewestFirst() {
    final hasCreatedAt = stats.any((stat) => stat.createdAt != null);
    if (!hasCreatedAt) {
      stats = stats.reversed.toList();
      return;
    }

    stats.sort((a, b) {
      final dateA = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final dateB = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return dateB.compareTo(dateA);
    });
  }

  void _applyStoredOrder(SharedPreferences prefs) {
    final teacherId = prefs.getInt('teacher_id');
    final orderedKeys = prefs.getStringList(_storageKey(teacherId));
    if (orderedKeys == null || orderedKeys.isEmpty || stats.length < 2) {
      return;
    }

    final remaining = List<CoCurricularStat>.from(stats);
    final orderedStats = <CoCurricularStat>[];

    for (final key in orderedKeys) {
      final matchIndex = remaining.indexWhere(
        (stat) => _buildKeyFromStat(stat) == key,
      );
      if (matchIndex == -1) {
        continue;
      }

      orderedStats.add(remaining.removeAt(matchIndex));
    }

    if (orderedStats.isEmpty) {
      return;
    }

    stats = [...orderedStats, ...remaining];
  }

  Future<void> _saveStoredOrder(String statKey) async {
    final prefs = await SharedPreferences.getInstance();
    final teacherId = prefs.getInt('teacher_id');
    final storageKey = _storageKey(teacherId);
    final orderedKeys = prefs.getStringList(storageKey)?.toList() ?? [];

    orderedKeys.remove(statKey);
    orderedKeys.insert(0, statKey);

    if (orderedKeys.length > _maxStoredOrderItems) {
      orderedKeys.removeRange(_maxStoredOrderItems, orderedKeys.length);
    }

    await prefs.setStringList(storageKey, orderedKeys);
  }

  bool _moveStatToTop(String statKey) {
    if (stats.length < 2) {
      return false;
    }

    final matchIndex = stats.indexWhere(
      (stat) => _buildKeyFromStat(stat) == statKey,
    );

    if (matchIndex <= 0) {
      return false;
    }

    final latestStat = stats.removeAt(matchIndex);
    stats.insert(0, latestStat);
    return true;
  }

  String _storageKey(int? teacherId) {
    return '$_storageKeyPrefix${teacherId ?? 0}';
  }

  String _buildKeyFromStat(CoCurricularStat stat) {
    return _buildKey(
      activityName: stat.activityName,
      categoryName: stat.categoryName,
      className: stat.className,
    );
  }

  String _buildKey({
    required String activityName,
    required String categoryName,
    required String className,
  }) {
    return [
      _normalize(activityName),
      _normalize(categoryName),
      _normalize(className),
    ].join('|');
  }

  String _normalize(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'\s+'), '').trim();
  }
}
