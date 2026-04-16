import 'package:flutter/foundation.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:study_hub/models/study_event.dart';
import 'package:study_hub/services/auth_service.dart';
import 'package:study_hub/config/app_constants.dart';

/// Service responsible for integration with the Google Calendar API.
class GoogleCalendarService {
  final AuthService _authService = AuthService();

  /// Creates a calendar event based on the [StudyEvent] model.
  Future<String?> createEvent(StudyEvent event) async {
    try {
      final client = await _authService.getAuthenticatedClient();
      if (client == null) {
        debugPrint('[GoogleCalendarService] User not authenticated.');
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

      // Configure native mobile reminders
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
        colorId: '2', // Sage (Green)
      );

      final createdEvent = await calendarApi.events.insert(
        googleEvent,
        AppConstants.calendarId,
      );

      debugPrint('[GoogleCalendarService] Event created. ID: ${createdEvent.id}');
      return createdEvent.id;
    } catch (e) {
      debugPrint('[GoogleCalendarService] Error creating event: $e');
      return null;
    }
  }

  /// Removes an event from the user's primary Google Calendar.
  Future<bool> deleteEvent(String googleEventId) async {
    try {
      final client = await _authService.getAuthenticatedClient();
      if (client == null) {
        debugPrint('[GoogleCalendarService] Authentication failure during deletion.');
        return false;
      }

      final calendarApi = calendar.CalendarApi(client);
      
      await calendarApi.events.delete(AppConstants.calendarId, googleEventId);
      debugPrint('[GoogleCalendarService] Delete command successful.');

      return true;
    } catch (e) {
      debugPrint('[GoogleCalendarService] Error deleting event: $e');
      return false;
    }
  }
}
