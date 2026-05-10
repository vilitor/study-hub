import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:study_hub/models/cloud_sync.dart';
import 'package:study_hub/models/study_event.dart';
import 'package:study_hub/models/study_log.dart';
import 'package:study_hub/services/cloud_sync_service.dart';
import 'package:study_hub/services/google_calendar_service.dart';
import 'package:study_hub/services/storage_service.dart';

/// Repository that orchestrates Study-related data operations.
class StudyRepository {
  final StorageService _storageService = StorageService();
  final GoogleCalendarService _googleCalendarService = GoogleCalendarService();
  final CloudSyncService _cloudSyncService = CloudSyncService.instance;

  Future<bool> saveLog(StudyLog log) async {
    final logToSave = log.copyWith(
      updatedAt: DateTime.now(),
      syncStatus: CloudSyncStatus.pendingSync,
    );
    final currentLogs = await _storageService.getStudyLogs();
    final existingIndex = currentLogs.indexWhere((l) => l.id == logToSave.id);
    if (existingIndex != -1) {
      currentLogs[existingIndex] = logToSave;
    } else {
      currentLogs.add(logToSave);
    }
    await _storageService.saveStudyLogs(currentLogs);
    await _cloudSyncService.enqueueStudyLog(logToSave);
    unawaited(_cloudSyncService.flushQueue());
    return true;
  }

  Future<void> deleteLog(String logId) async {
    final currentLogs = await _storageService.getStudyLogs();
    currentLogs.removeWhere((l) => l.id == logId);
    await _storageService.saveStudyLogs(currentLogs);
    await _cloudSyncService.enqueueDelete(
      collection: CloudCollections.records,
      documentId: logId,
    );
    await _cloudSyncService.enqueueDelete(
      collection: CloudCollections.notes,
      documentId: logId,
    );
    unawaited(_cloudSyncService.flushQueue());
  }

  Future<List<StudyLog>> getLocalLogs() async {
    return await _storageService.getStudyLogs();
  }

  Future<String?> scheduleEvent(StudyEvent event) async {
    debugPrint('[StudyRepository] Scheduling event: ${event.id}');

    final pendingEvent = event.copyWith(
      updatedAt: DateTime.now(),
      syncStatus: CloudSyncStatus.pendingSync,
    );
    await _upsertEventLocally(pendingEvent);
    await _cloudSyncService.enqueueStudyEvent(pendingEvent);
    unawaited(_cloudSyncService.flushQueue());

    final googleId = await _googleCalendarService.createEvent(event);
    if (googleId == null) {
      debugPrint(
        '[StudyRepository] Remote Calendar sync failed; event stayed local.',
      );
      return null;
    }

    final syncedEvent = pendingEvent.copyWith(
      calendarEventId: googleId,
      syncedWithCalendar: true,
      updatedAt: DateTime.now(),
      syncStatus: CloudSyncStatus.pendingSync,
    );
    await _upsertEventLocally(syncedEvent);
    await _cloudSyncService.enqueueStudyEvent(syncedEvent);
    unawaited(_cloudSyncService.flushQueue());
    return googleId;
  }

  Future<void> updateEvent(StudyEvent event) async {
    final eventToSave = event.copyWith(
      updatedAt: DateTime.now(),
      syncStatus: CloudSyncStatus.pendingSync,
    );
    await _upsertEventLocally(eventToSave);
    await _cloudSyncService.enqueueStudyEvent(eventToSave);
    unawaited(_cloudSyncService.flushQueue());
  }

  Future<bool> deleteEvent(StudyEvent event) async {
    debugPrint('[StudyRepository] Deleting event: ${event.id}');
    var remoteDeleted = true;

    if (event.syncedWithCalendar && event.calendarEventId != null) {
      remoteDeleted = await _googleCalendarService.deleteEvent(
        event.calendarEventId!,
      );
    }

    if (!remoteDeleted) {
      debugPrint(
        '[StudyRepository] Calendar deletion failed. Local state preserved.',
      );
      return false;
    }

    final currentEvents = await _storageService.getStudyEvents();
    final countBefore = currentEvents.length;
    currentEvents.removeWhere((e) => e.id == event.id);
    if (currentEvents.length < countBefore) {
      await _storageService.saveStudyEvents(currentEvents);
      await _cloudSyncService.enqueueDelete(
        collection: CloudCollections.records,
        documentId: event.id,
      );
      unawaited(_cloudSyncService.flushQueue());
      debugPrint('[StudyRepository] Local deletion successful.');
    }
    return true;
  }

  Future<List<StudyEvent>> getLocalEvents() async {
    return await _storageService.getStudyEvents();
  }

  Future<void> _upsertEventLocally(StudyEvent event) async {
    final currentEvents = await _storageService.getStudyEvents();
    final existingIndex = currentEvents.indexWhere((e) => e.id == event.id);
    if (existingIndex == -1) {
      currentEvents.add(event);
    } else {
      currentEvents[existingIndex] = event;
    }
    await _storageService.saveStudyEvents(currentEvents);
  }
}
