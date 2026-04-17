import 'package:flutter/foundation.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:study_hub/models/study_event.dart';
import 'package:study_hub/services/auth_service.dart';
import 'package:study_hub/config/app_constants.dart';

/// Service responsible for integration with the Google Calendar API.
class GoogleCalendarService {
  final AuthService _authService = AuthService();

  // Static guard to prevent duplicate requests from any part of the app
  static final Map<String, DateTime> _recentRequests = {};
  static const Duration _duplicateWindow = Duration(seconds: 10);

  /// Checks if a request for the same event was sent very recently.
  bool _isDuplicate(StudyEvent event) {
    final key = '${event.title}_${event.startDateTime.toIso8601String()}';
    final now = DateTime.now();
    
    if (_recentRequests.containsKey(key)) {
      final lastRequestTime = _recentRequests[key]!;
      if (now.difference(lastRequestTime) < _duplicateWindow) {
        return true;
      }
    }
    
    _recentRequests[key] = now;
    // Cleanup old requests periodically
    _recentRequests.removeWhere((_, time) => now.difference(time) > _duplicateWindow);
    return false;
  }

  /// Creates a calendar event based on the [StudyEvent] model.
  Future<String?> createEvent(StudyEvent event) async {
    final timestamp = DateTime.now().toIso8601String();
    debugPrint('[$timestamp] [GoogleCalendarService] 🛫 Starting event creation for: ${event.title}');
    
    if (_isDuplicate(event)) {
      debugPrint('[$timestamp] [GoogleCalendarService] 🛡️ BLOCKING DUPLICATE REQUEST for: ${event.title}');
      return null;
    }
    try {
      final client = await _authService.getAuthenticatedClient();
      if (client == null) {
        debugPrint('[GoogleCalendarService] ❌ Authentication failed.');
        return null;
      }

      final calendarApi = calendar.CalendarApi(client);

      // Convert local time to UTC for API consistency
      final startDateTime = calendar.EventDateTime(
        dateTime: event.startDateTime.toUtc(),
      );

      final endDateTime = calendar.EventDateTime(
        dateTime: event.endDateTime.toUtc(),
      );

      final reminders = calendar.EventReminders(
        useDefault: false,
        overrides: [
          calendar.EventReminder(
            method: 'popup', 
            minutes: event.reminderMinutes,
          ),
        ],
      );

      final googleEvent = calendar.Event(
        summary: '[${event.subject}] ${event.title}',
        description: event.description.isNotEmpty ? event.description : null,
        start: startDateTime,
        end: endDateTime,
        reminders: reminders,
        colorId: '2', 
      );

      final createdEvent = await calendarApi.events.insert(
        googleEvent,
        AppConstants.calendarId,
      );

      debugPrint('[GoogleCalendarService] ✅ Event successfully created. ID: ${createdEvent.id}');
      return createdEvent.id;
    } catch (e) {
      debugPrint('[GoogleCalendarService] ❌ CRITICAL ERROR creating event: $e');
      return null;
    }
  }

  /// Removes an event from the user's primary Google Calendar.
  Future<bool> deleteEvent(String googleEventId) async {
    debugPrint('[GoogleCalendarService] 🗑️ Attempting to delete event: $googleEventId');
    try {
      final client = await _authService.getAuthenticatedClient();
      if (client == null) {
        debugPrint('[GoogleCalendarService] ❌ Auth failure during deletion.');
        return false;
      }

      final calendarApi = calendar.CalendarApi(client);
      
      await calendarApi.events.delete(AppConstants.calendarId, googleEventId);
      debugPrint('[GoogleCalendarService] ✅ Event deleted from Google Calendar.');

      return true;
    } catch (e) {
      debugPrint('[GoogleCalendarService] ❌ ERROR deleting event: $e');
      return false;
    }
  }
}
