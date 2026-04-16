import 'package:study_hub/models/study_log.dart';
import 'package:study_hub/models/study_event.dart';
import 'package:study_hub/services/notion_service.dart';
import 'package:study_hub/services/storage_service.dart';
import 'package:study_hub/services/google_calendar_service.dart';

/// Repository that orchestrates Study-related data operations
/// Handles the layer between raw Services and UI Providers (Clean Architecture)
class StudyRepository {
  final NotionService _notionService = NotionService();
  final StorageService _storageService = StorageService();
  final GoogleCalendarService _googleCalendarService = GoogleCalendarService();

  // ── Study Logs ──

  /// Adds a log locally and attempts to sync with Notion
  Future<bool> saveLog(StudyLog log) async {
    // 1. Save locally first (Reliability)
    final currentLogs = await _storageService.getStudyLogs();
    currentLogs.add(log);
    await _storageService.saveStudyLogs(currentLogs);

    // 2. Effort to sync with Notion
    return await _notionService.createStudyLog(log);
  }

  /// Removes a log locally
  Future<void> deleteLog(String logId) async {
    final currentLogs = await _storageService.getStudyLogs();
    currentLogs.removeWhere((l) => l.id == logId);
    await _storageService.saveStudyLogs(currentLogs);
  }

  /// Fetches logs from local storage
  Future<List<StudyLog>> getLocalLogs() async {
    return await _storageService.getStudyLogs();
  }

  // ── Study Events ──

  /// Saves an event locally and to Google Calendar
  Future<String?> scheduleEvent(StudyEvent event) async {
    // 1. Sync with Google Calendar
    final googleId = await _googleCalendarService.createEvent(event);
    
    // 2. Prepare event for storage (with sync status)
    final eventToSave = event.copyWith(
      calendarEventId: googleId,
      syncedWithCalendar: googleId != null,
    );

    // 3. Save locally
    final currentEvents = await _storageService.getStudyEvents();
    currentEvents.add(eventToSave);
    await _storageService.saveStudyEvents(currentEvents);

    return googleId;
  }

  /// Removes an event locally and from Google Calendar
  Future<bool> deleteEvent(StudyEvent event) async {
    bool remoteDeleted = true;

    // 1. Try to delete from Google if synced
    if (event.syncedWithCalendar && event.calendarEventId != null) {
      remoteDeleted = await _googleCalendarService.deleteEvent(event.calendarEventId!);
    }

    // 2. If remote delete succeeded (or wasn't synced), remove local
    if (remoteDeleted) {
      final currentEvents = await _storageService.getStudyEvents();
      currentEvents.removeWhere((e) => e.id == event.id);
      await _storageService.saveStudyEvents(currentEvents);
      return true;
    }

    return false;
  }

  /// Fetches events from local storage
  Future<List<StudyEvent>> getLocalEvents() async {
    return await _storageService.getStudyEvents();
  }
}
