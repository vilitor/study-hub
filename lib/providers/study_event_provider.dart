import 'dart:async';

import 'package:flutter/material.dart';
import 'package:study_hub/models/study_event.dart';
import 'package:study_hub/repositories/study_repository.dart';

/// Provider that manages planned study events.
class StudyEventProvider extends ChangeNotifier {
  final StudyRepository _repository;
  final List<StudyEvent> _events = [];
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  String? _lastCalendarError;

  StudyEventProvider({StudyRepository? repository})
    : _repository = repository ?? StudyRepository() {
    loadEvents();
  }

  List<StudyEvent> get events => List.unmodifiable(_events);
  DateTime get selectedDate => _selectedDate;
  bool get isLoading => _isLoading;
  int get totalEvents => _events.length;
  String? get lastCalendarError => _lastCalendarError;

  List<StudyEvent> get eventsForSelectedDay => getEventsForDate(_selectedDate);
  List<StudyEvent> get todayEvents => getEventsForDate(DateTime.now());

  List<StudyEvent> getEventsForDate(DateTime date) {
    return _events.where((event) {
      return event.date.year == date.year &&
          event.date.month == date.month &&
          event.date.day == date.day;
    }).toList()..sort((a, b) {
      final aMinutes = a.startTime.hour * 60 + a.startTime.minute;
      final bMinutes = b.startTime.hour * 60 + b.startTime.minute;
      return aMinutes.compareTo(bMinutes);
    });
  }

  void selectDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  Future<void> loadEvents() async {
    _setLoading(true);
    try {
      final loadedEvents = await _repository.getLocalEvents();
      _events
        ..clear()
        ..addAll(loadedEvents);
      notifyListeners();
      unawaited(_retryPendingCalendarSync());
    } catch (e) {
      debugPrint('Error loading events: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> addEvent(StudyEvent event) async {
    if (_isLoading) {
      debugPrint('[StudyEventProvider] Blocked: operation in progress.');
      return false;
    }

    _setLoading(true);
    debugPrint('[StudyEventProvider] addEvent start: ${event.id}');

    try {
      final googleId = await _repository.scheduleEvent(event);
      _lastCalendarError = _repository.lastCalendarError;
      final syncedEvent = event.copyWith(
        calendarEventId: googleId,
        syncedWithCalendar: googleId != null,
        syncStatus: event.syncStatus,
      );

      final storedEvents = await _repository.getLocalEvents();
      final stored = storedEvents.firstWhere(
        (item) => item.id == event.id,
        orElse: () => syncedEvent,
      );
      _events.removeWhere((item) => item.id == stored.id);
      _events.add(stored);
      notifyListeners();
      debugPrint('[StudyEventProvider] addEvent complete.');
      return true;
    } catch (e) {
      debugPrint('[StudyEventProvider] Error adding event: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateEvent(StudyEvent updatedEvent) async {
    if (_isLoading) {
      debugPrint('[StudyEventProvider] Blocked: operation in progress.');
      return false;
    }

    _setLoading(true);
    final index = _events.indexWhere((event) => event.id == updatedEvent.id);
    try {
      await _repository.updateEvent(updatedEvent);
      if (index != -1) {
        _events[index] = updatedEvent;
      } else {
        _events.add(updatedEvent);
      }
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[StudyEventProvider] Error updating event: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void removeEvent(String eventId) {
    _events.removeWhere((event) => event.id == eventId);
    notifyListeners();
  }

  Future<bool> deleteEvent(StudyEvent event) async {
    if (_isLoading) {
      debugPrint('[StudyEventProvider] Blocked: deletion in progress.');
      return false;
    }

    _setLoading(true);
    debugPrint('[StudyEventProvider] deleteEvent start: ${event.id}');

    try {
      final success = await _repository.deleteEvent(event);
      if (success) {
        removeEvent(event.id);
      }
      return success;
    } catch (e) {
      debugPrint('[StudyEventProvider] Error deleting event: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> retryPendingCalendarSync() => _retryPendingCalendarSync();

  Future<void> _retryPendingCalendarSync() async {
    try {
      final synced = await _repository.syncPendingCalendarEvents();
      _lastCalendarError = _repository.lastCalendarError;
      if (synced == 0) return;
      final loadedEvents = await _repository.getLocalEvents();
      _events
        ..clear()
        ..addAll(loadedEvents);
      notifyListeners();
    } catch (e) {
      debugPrint('[StudyEventProvider] Calendar retry failed: $e');
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
