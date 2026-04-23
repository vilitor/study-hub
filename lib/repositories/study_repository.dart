import 'package:flutter/foundation.dart';
import 'package:study_hub/models/study_log.dart';
import 'package:study_hub/models/study_event.dart';
import 'package:study_hub/services/storage_service.dart';
import 'package:study_hub/services/google_calendar_service.dart';

/// Repository that orchestrates Study-related data operations
/// Handles the layer between raw Services and UI Providers (Clean Architecture)
class StudyRepository {
  final StorageService _storageService = StorageService();
  final GoogleCalendarService _googleCalendarService = GoogleCalendarService();

  // ── Study Logs ──

  /// Adds a log locally and attempts to sync with Notion
  Future<bool> saveLog(StudyLog log) async {
    // 1. Save locally first (Reliability)
    final currentLogs = await _storageService.getStudyLogs();
    // Replace if same ID exists, otherwise add
    final existingIndex = currentLogs.indexWhere((l) => l.id == log.id);
    if (existingIndex != -1) {
      currentLogs[existingIndex] = log;
    } else {
      currentLogs.add(log);
    }
    await _storageService.saveStudyLogs(currentLogs);

    // 2. Notion sync is now handled by the caller (page ID capture)
    return true;
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
    debugPrint('[StudyRepository] 📅 Scheduling event: ${event.id}');
    
    // 1. Sync with Google Calendar (Remote)
    final googleId = await _googleCalendarService.createEvent(event);
    
    if (googleId == null) {
      debugPrint('[StudyRepository] ⚠️ Remote sync failed, event will be local-only.');
    }

    // 2. Prepare event for storage (with sync status)
    final eventToSave = event.copyWith(
      calendarEventId: googleId,
      syncedWithCalendar: googleId != null,
    );

    // 3. Save locally
    final currentEvents = await _storageService.getStudyEvents();
    
    // Check if event ID already exists (idempotency safety)
    final existingIndex = currentEvents.indexWhere((e) => e.id == event.id);
    if (existingIndex != -1) {
      debugPrint('[StudyRepository] 🔄 Updating existing event in local storage.');
      currentEvents[existingIndex] = eventToSave;
    } else {
      currentEvents.add(eventToSave);
    }
    
    await _storageService.saveStudyEvents(currentEvents);
    return googleId;
  }

  /// Removes an event locally and from Google Calendar
  Future<bool> deleteEvent(StudyEvent event) async {
    debugPrint('[StudyRepository] 🗑️ Deleting event: ${event.id}');
    bool remoteDeleted = true;

    // 1. Try to delete from Google if synced
    if (event.syncedWithCalendar && event.calendarEventId != null) {
      remoteDeleted = await _googleCalendarService.deleteEvent(event.calendarEventId!);
    }

    // 2. Remove from local storage regardless of remote success if needed,
    // but here we follow the existing logic: if remote fails, we return false
    // unless the user forces it (handled in UI). 
    // Optimization: always fetch current list to ensure consistency.
    if (remoteDeleted) {
      final currentEvents = await _storageService.getStudyEvents();
      final countBefore = currentEvents.length;
      currentEvents.removeWhere((e) => e.id == event.id);
      
      if (currentEvents.length < countBefore) {
        await _storageService.saveStudyEvents(currentEvents);
        debugPrint('[StudyRepository] ✅ Local deletion successful.');
      }
      return true;
    }

    debugPrint('[StudyRepository] ❌ Remote deletion failed. Local state preserved.');
    return false;
  }

  /// Fetches events from local storage
  Future<List<StudyEvent>> getLocalEvents() async {
    return await _storageService.getStudyEvents();
  }
}
