import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:study_hub/models/study_log.dart';
import 'package:study_hub/models/notion_schema.dart';
import 'package:study_hub/repositories/study_repository.dart';
import 'package:study_hub/services/storage_service.dart';
import 'package:study_hub/services/notion_service.dart';

/// Provider that manages the state of study log entries.
/// It interacts with the [StudyRepository] to persist data.
class StudyLogProvider extends ChangeNotifier {
  final StudyRepository _repository = StudyRepository();
  final List<StudyLog> _logs = [];
  bool _isLoading = false;
  NotionDatabaseSchema? _cachedSchema;

  // ── Getters ──

  List<StudyLog> get logs => List.unmodifiable(_logs);
  bool get isLoading => _isLoading;
  int get totalLogs => _logs.length;
  NotionDatabaseSchema? get cachedSchema => _cachedSchema;

  /// Returns logs filtered by a specific date.
  List<StudyLog> getLogsForDate(DateTime date) {
    return _logs.where((log) {
      return log.date.year == date.year &&
          log.date.month == date.month &&
          log.date.day == date.day;
    }).toList();
  }

  /// Calculates total study minutes for a specific date.
  int getStudyMinutesForDate(DateTime date) {
    return getLogsForDate(date).fold(0, (sum, log) => sum + log.studyTimeMinutes);
  }

  /// Calculates the current streak of consecutive days studied.
  int get currentStreak {
    if (_logs.isEmpty) return 0;

    // Extract unique dates (ignoring time)
    final uniqueDates = _logs.map((l) => DateTime(l.date.year, l.date.month, l.date.day)).toSet().toList();
    // Sort descending (newest first)
    uniqueDates.sort((a, b) => b.compareTo(a));

    int streak = 0;
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    DateTime currentDateToCheck = today;

    // Check if there's a log for today
    if (uniqueDates.contains(today)) {
      streak = 1;
      currentDateToCheck = today.subtract(const Duration(days: 1));
    } else if (uniqueDates.contains(today.subtract(const Duration(days: 1)))) {
      // If no log today, but there's one yesterday, streak continues from yesterday
      streak = 1;
      currentDateToCheck = today.subtract(const Duration(days: 2));
    } else {
      // No log today or yesterday -> streak broken
      return 0;
    }

    // Count backwards for consecutive days
    for (int i = 0; i < uniqueDates.length; i++) {
      if (uniqueDates.contains(currentDateToCheck)) {
        streak++;
        currentDateToCheck = currentDateToCheck.subtract(const Duration(days: 1));
      } else {
        // Only break if we are checking days before the streak start
        if (uniqueDates[i].isBefore(currentDateToCheck)) break;
      }
    }

    return streak;
  }

  // ── Life Cycle ──

  StudyLogProvider() {
    _init();
  }

  /// Initial entry point to load data and config.
  Future<void> _init() async {
    await loadLogs();
    await loadSchemaFromCache();
  }

  // ── Actions ──

  /// Loads all logs from the repository.
  Future<void> loadLogs() async {
    _setLoading(true);
    try {
      final loadedLogs = await _repository.getLocalLogs();
      _logs.clear();
      _logs.addAll(loadedLogs);
    } catch (e) {
      debugPrint('Error loading logs: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Saves a new study entry and triggers a Notion sync attempt.
  Future<bool> addLog(StudyLog log) async {
    try {
      _logs.add(log);
      notifyListeners();
      return await _repository.saveLog(log);
    } catch (e) {
      debugPrint('Error adding log: $e');
      return false;
    }
  }

  /// Updates an existing log (e.g., after a manual sync).
  Future<void> updateLog(StudyLog updatedLog) async {
    final index = _logs.indexWhere((l) => l.id == updatedLog.id);
    if (index != -1) {
      _logs[index] = updatedLog;
      await _repository.saveLog(updatedLog); // Overwrites local storage
      notifyListeners();
    }
  }

  /// Removes a log from the application state and local storage.
  Future<void> removeLog(String logId) async {
    try {
      _logs.removeWhere((l) => l.id == logId);
      await _repository.deleteLog(logId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error removing log: $e');
    }
  }

  /// Removes a log locally AND archives it in Notion (if synced).
  Future<bool> deleteLogWithNotionSync(String logId) async {
    final log = _logs.where((l) => l.id == logId).firstOrNull;
    if (log == null) return false;

    // Archive in Notion first if we have a page ID
    if (log.notionPageId != null && log.notionPageId!.isNotEmpty) {
      final notionService = NotionService();
      final archived = await notionService.archivePage(log.notionPageId!);
      if (!archived) {
        debugPrint('[StudyLogProvider] ⚠️ Notion archive failed, removing locally anyway.');
      }
    }

    await removeLog(logId);
    return true;
  }

  // ── Notion Schema Management ──

  /// Loads the pre-existing schema from local cache.
  Future<void> loadSchemaFromCache() async {
    final storage = StorageService();
    final jsonString = await storage.getNotionSchema();
    if (jsonString != null && jsonString.isNotEmpty) {
      try {
        _cachedSchema = NotionDatabaseSchema.fromJson(jsonDecode(jsonString));
        notifyListeners();
      } catch (e) {
        debugPrint('Error parsing cached schema: $e');
      }
    }
  }

  /// Syncs the Notion table schema (columns) with the API.
  Future<bool> syncSchemaFromNotion() async {
    _setLoading(true);
    try {
      final storage = StorageService();
      final dbId = await storage.getNotionDatabaseId();
      if (dbId == null || dbId.isEmpty) return false;

      final service = NotionService();
      final fetched = await service.fetchDatabaseSchema(dbId);
      
      if (fetched != null) {
        _cachedSchema = fetched;
        await storage.saveNotionSchema(jsonEncode(fetched.toJson()));
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error syncing schema: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ── Helpers ──

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
