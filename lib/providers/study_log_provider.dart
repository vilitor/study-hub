import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:study_hub/models/study_log.dart';
import 'package:study_hub/models/notion_schema.dart';
import 'package:study_hub/repositories/study_repository.dart';
import 'package:study_hub/services/storage_service.dart';
import 'package:study_hub/services/notion_service.dart';
import 'package:study_hub/services/local_study_schema_service.dart';

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
    final target = _dateKey(date);
    return _logs.where((log) {
      return _dateKey(log.date) == target;
    }).toList();
  }

  /// Calculates total study minutes for a specific date.
  int getStudyMinutesForDate(DateTime date) {
    return getLogsForDate(
      date,
    ).fold(0, (sum, log) => sum + log.studyTimeMinutes);
  }

  /// Calculates the current streak of consecutive days studied.
  int get currentStreak {
    if (_logs.isEmpty) return 0;

    // Extract unique dates (ignoring time) as DateTime objects at midnight
    final uniqueDates = _logs
        .map((l) => DateTime(l.date.year, l.date.month, l.date.day))
        .toSet();

    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final yesterday = today.subtract(const Duration(days: 1));

    DateTime currentDateToCheck;
    int streak = 0;

    // Logic: If today has a log, start from today.
    // If not, check if yesterday has a log (maintain streak).
    if (uniqueDates.contains(today)) {
      currentDateToCheck = today;
    } else if (uniqueDates.contains(yesterday)) {
      currentDateToCheck = yesterday;
    } else {
      // No logs today or yesterday -> streak broken
      return 0;
    }

    // Count backwards as long as consecutive days exist in uniqueDates
    while (uniqueDates.contains(currentDateToCheck)) {
      streak++;
      currentDateToCheck = currentDateToCheck.subtract(const Duration(days: 1));
    }

    return streak;
  }

  /// Returns a map of date to total minutes for the heatmap.
  Map<DateTime, int> get heatmapDataset {
    final Map<DateTime, int> dataset = {};
    for (var log in _logs) {
      final date = _dateKey(log.date);
      dataset[date] = (dataset[date] ?? 0) + log.studyTimeMinutes;
    }
    return dataset;
  }

  /// Returns total study minutes for the current week.
  int get weeklyStudyMinutes {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday % 7));
    final midnightStart = DateTime(
      startOfWeek.year,
      startOfWeek.month,
      startOfWeek.day,
    );

    return _logs
        .where(
          (l) =>
              l.date.isAfter(midnightStart) ||
              l.date.isAtSameMomentAs(midnightStart),
        )
        .fold(0, (sum, log) => sum + log.studyTimeMinutes);
  }

  /// Returns total study minutes for the current month.
  int get monthlyStudyMinutes {
    final now = DateTime.now();
    return _logs
        .where((l) => l.date.year == now.year && l.date.month == now.month)
        .fold(0, (sum, log) => sum + log.studyTimeMinutes);
  }

  /// Returns total study minutes for the previous month (for comparison).
  int get previousMonthStudyMinutes {
    final now = DateTime.now();
    final prevMonth = now.month == 1 ? 12 : now.month - 1;
    final year = now.month == 1 ? now.year - 1 : now.year;

    return _logs
        .where((l) => l.date.year == year && l.date.month == prevMonth)
        .fold(0, (sum, log) => sum + log.studyTimeMinutes);
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
      final saved = await _repository.saveLog(log);
      if (!saved) return false;

      final existingIndex = _logs.indexWhere((l) => l.id == log.id);
      if (existingIndex == -1) {
        _logs.add(log);
      } else {
        _logs[existingIndex] = log;
      }
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error adding log: $e');
      return false;
    }
  }

  Future<bool> saveLocalLog(StudyLog log) => addLog(log);

  Future<String?> syncLocalLogToNotion({
    required StudyLog localLog,
    required NotionDatabaseSchema notionSchema,
    required String? notionTimeField,
  }) async {
    final notionRawValues = localLog.source == StudyLogSource.notion
        ? localLog.rawValues
        : LocalStudySchemaService.mapToNotionRawValues(
            localValues: localLog.rawValues,
            notionSchema: notionSchema,
            notionTimeField: notionTimeField,
          );
    if (notionRawValues.isEmpty) return null;

    final notionLog = StudyLog(
      rawValues: notionRawValues,
      schema: notionSchema,
      localNote: localLog.localNote,
      source: StudyLogSource.notion,
      studyTimeField: notionTimeField,
    );

    final pageId = await NotionService().createStudyLog(notionLog);
    if (pageId == null) return null;

    final syncedLog = localLog.copyWith(
      syncedWithNotion: true,
      notionPageId: pageId,
      source: localLog.source,
    );
    await updateLog(syncedLog);
    return pageId;
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
        debugPrint(
          '[StudyLogProvider] ⚠️ Notion archive failed, removing locally anyway.',
        );
      }
    }

    await removeLog(logId);
    return true;
  }

  // ── Notion Schema Management ──

  /// Loads the pre-existing schema from local cache.
  Future<void> loadSchemaFromCache() async {
    final storage = StorageService();
    final token = await storage.getNotionToken();
    final dbId = await storage.getNotionDatabaseId();
    if (token == null || token.isEmpty || dbId == null || dbId.isEmpty) {
      _cachedSchema = null;
      await storage.clearNotionSchema();
      notifyListeners();
      return;
    }

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

  Future<void> clearCachedSchema() async {
    _cachedSchema = null;
    await StorageService().clearNotionSchema();
    notifyListeners();
  }

  /// Syncs the Notion table schema (columns) with the API.
  Future<bool> syncSchemaFromNotion() async {
    _setLoading(true);
    final previousSchema = _cachedSchema;
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
      if (previousSchema == null) {
        _cachedSchema = null;
        await storage.clearNotionSchema();
        notifyListeners();
      }
      return false;
    } catch (e) {
      if (previousSchema == null) {
        _cachedSchema = null;
        await StorageService().clearNotionSchema();
        notifyListeners();
      }
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

  DateTime _dateKey(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }
}
