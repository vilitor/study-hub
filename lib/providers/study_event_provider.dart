import 'package:flutter/material.dart';
import 'package:study_hub/models/study_event.dart';
import 'package:study_hub/repositories/study_repository.dart';

/// Provider that manages the state of planned study events.
/// It synchronizes with [StudyRepository] for local and remote (Google Calendar) persistence.
class StudyEventProvider extends ChangeNotifier {
  final StudyRepository _repository = StudyRepository();
  final List<StudyEvent> _events = [];
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  // ── Getters ──

  List<StudyEvent> get events => List.unmodifiable(_events);
  DateTime get selectedDate => _selectedDate;
  bool get isLoading => _isLoading;
  int get totalEvents => _events.length;

  /// Returns events scheduled for the selected calendar day.
  List<StudyEvent> get eventsForSelectedDay => getEventsForDate(_selectedDate);

  /// Returns events scheduled for today.
  List<StudyEvent> get todayEvents => getEventsForDate(DateTime.now());

  /// Returns filtered and sorted events for a specific date.
  List<StudyEvent> getEventsForDate(DateTime date) {
    return _events.where((event) {
      return event.date.year == date.year &&
          event.date.month == date.month &&
          event.date.day == date.day;
    }).toList()
      ..sort((a, b) {
        final aMinutes = a.startTime.hour * 60 + a.startTime.minute;
        final bMinutes = b.startTime.hour * 60 + b.startTime.minute;
        return aMinutes.compareTo(bMinutes);
      });
  }

  // ── Life Cycle ──

  StudyEventProvider() {
    loadEvents();
  }

  // ── Actions ──

  /// Changes the currently selected date in the horizontal calendar.
  void selectDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  /// Initial load of events from local storage.
  Future<void> loadEvents() async {
    _setLoading(true);
    try {
      final loadedEvents = await _repository.getLocalEvents();
      _events.clear();
      _events.addAll(loadedEvents);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading events: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Adds a new event to the schedule and attempts to sync with Google Calendar.
  Future<void> addEvent(StudyEvent event) async {
    try {
      // The repository handles both remote sync and local storage
      final googleId = await _repository.scheduleEvent(event);
      
      // Update local state with the synced version
      final syncedEvent = event.copyWith(
        calendarEventId: googleId,
        syncedWithCalendar: googleId != null,
      );
      
      _events.add(syncedEvent);
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding event: $e');
    }
  }

  /// Updates an existing event state.
  void updateEvent(StudyEvent updatedEvent) {
    final index = _events.indexWhere((e) => e.id == updatedEvent.id);
    if (index != -1) {
      _events[index] = updatedEvent;
      notifyListeners();
    }
  }

  /// Simple removal from local state.
  void removeEvent(String eventId) {
    _events.removeWhere((e) => e.id == eventId);
    notifyListeners();
  }

  /// Removes an event and its remote counterpart (if synced).
  /// Returns [true] if successfully deleted (or not synced).
  Future<bool> deleteEvent(StudyEvent event) async {
    try {
      final success = await _repository.deleteEvent(event);
      if (success) {
        removeEvent(event.id);
      }
      return success;
    } catch (e) {
      debugPrint('Error deleting event: $e');
      return false;
    }
  }

  // ── Helpers ──

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
