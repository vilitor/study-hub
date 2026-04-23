import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:study_hub/models/study_goal.dart';
import 'package:study_hub/models/study_log.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider that manages study goals with local persistence.
/// Calculates progress by matching StudyLog entries against goal criteria.
class GoalProvider extends ChangeNotifier {
  final List<StudyGoal> _goals = [];
  bool _isLoading = false;

  static const String _storageKey = 'persisted_study_goals';

  // ── Getters ──

  List<StudyGoal> get goals => List.unmodifiable(_goals);
  bool get isLoading => _isLoading;

  /// Returns the active weekly goal for the current week, if any.
  StudyGoal? get activeWeeklyGoal {
    final now = DateTime.now();
    return _goals
        .where((g) => g.type == GoalType.weekly && g.coversDate(now))
        .firstOrNull;
  }

  /// Returns the active monthly goal for the current month, if any.
  StudyGoal? get activeMonthlyGoal {
    final now = DateTime.now();
    return _goals
        .where((g) => g.type == GoalType.monthly && g.coversDate(now))
        .firstOrNull;
  }

  // ── Lifecycle ──

  GoalProvider() {
    _loadGoals();
  }

  // ── Progress Calculation ──

  /// Calculates progress (0.0 to 1.0) for a goal based on study logs.
  /// Matches logs by date range AND languages.
  double calculateProgress(StudyGoal goal, List<StudyLog> logs) {
    if (goal.targetMinutes <= 0) return 0.0;

    final matchingLogs = logs.where((log) {
      // Check date is within goal period
      if (!goal.coversDate(log.date)) return false;

      // Check if any of the log's languages match the goal's languages
      if (goal.languages.isEmpty) return true; // No language filter
      return _logMatchesLanguages(log, goal.languages);
    });

    final totalMinutes =
        matchingLogs.fold<int>(0, (sum, log) => sum + log.studyTimeMinutes);

    final progress = totalMinutes / goal.targetMinutes;
    return progress.clamp(0.0, 1.0);
  }

  /// Returns actual studied minutes for a goal.
  int getStudiedMinutes(StudyGoal goal, List<StudyLog> logs) {
    final matchingLogs = logs.where((log) {
      if (!goal.coversDate(log.date)) return false;
      if (goal.languages.isEmpty) return true;
      return _logMatchesLanguages(log, goal.languages);
    });

    return matchingLogs.fold<int>(0, (sum, log) => sum + log.studyTimeMinutes);
  }

  /// Checks if a log's language fields match any of the goal languages.
  bool _logMatchesLanguages(StudyLog log, List<String> goalLanguages) {
    for (final entry in log.schema.properties.entries) {
      final prop = entry.value;
      final value = log.rawValues[prop.name];

      if (prop.type == 'select' && value != null) {
        if (goalLanguages.contains(value.toString())) return true;
      }

      if (prop.type == 'multi_select' && value is List) {
        for (final v in value) {
          if (goalLanguages.contains(v.toString())) return true;
        }
      }
    }
    return false;
  }

  // ── Actions ──

  /// Adds a new goal. Returns false if a duplicate exists for the same period.
  Future<bool> addGoal(StudyGoal goal) async {
    // Check for duplicates
    final hasDuplicate = _goals.any((g) =>
        g.type == goal.type &&
        g.periodStart.year == goal.periodStart.year &&
        g.periodStart.month == goal.periodStart.month &&
        g.periodStart.day == goal.periodStart.day);

    if (hasDuplicate) return false;

    _goals.add(goal);
    await _saveGoals();
    notifyListeners();
    return true;
  }

  /// Updates an existing goal.
  Future<void> updateGoal(StudyGoal updatedGoal) async {
    final index = _goals.indexWhere((g) => g.id == updatedGoal.id);
    if (index != -1) {
      _goals[index] = updatedGoal;
      await _saveGoals();
      notifyListeners();
    }
  }

  /// Deletes a goal by ID.
  Future<void> deleteGoal(String goalId) async {
    _goals.removeWhere((g) => g.id == goalId);
    await _saveGoals();
    notifyListeners();
  }

  // ── Persistence ──

  Future<void> _loadGoals() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_storageKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        _goals.clear();
        _goals.addAll(
          decoded.map((e) => StudyGoal.fromMap(e as Map<String, dynamic>)),
        );
      }
    } catch (e) {
      debugPrint('[GoalProvider] Error loading goals: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _saveGoals() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(_goals.map((g) => g.toMap()).toList());
    await prefs.setString(_storageKey, jsonStr);
  }
}
