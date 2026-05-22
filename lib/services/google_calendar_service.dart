import 'package:flutter/foundation.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:study_hub/config/app_constants.dart';
import 'package:study_hub/models/study_event.dart';
import 'package:study_hub/services/auth_service.dart';

class CalendarCreateResult {
  final String? eventId;
  final String? errorMessage;
  final bool duplicateSuppressed;

  const CalendarCreateResult._({
    this.eventId,
    this.errorMessage,
    this.duplicateSuppressed = false,
  });

  bool get isSuccess => eventId != null && eventId!.isNotEmpty;

  const CalendarCreateResult.success(String eventId) : this._(eventId: eventId);

  const CalendarCreateResult.failure(String message)
    : this._(errorMessage: message);

  const CalendarCreateResult.duplicate()
    : this._(
        errorMessage: 'Solicitação duplicada bloqueada.',
        duplicateSuppressed: true,
      );
}

/// Service responsible for integration with the Google Calendar API.
class GoogleCalendarService {
  final AuthService _authService;

  GoogleCalendarService({AuthService? authService})
    : _authService = authService ?? AuthService();

  static final Map<String, DateTime> _recentRequests = {};
  static const Duration _duplicateWindow = Duration(seconds: 10);

  bool _isDuplicate(StudyEvent event) {
    final key = '${event.id}_${event.startDateTime.toIso8601String()}';
    final now = DateTime.now();
    final lastRequestTime = _recentRequests[key];
    if (lastRequestTime != null &&
        now.difference(lastRequestTime) < _duplicateWindow) {
      return true;
    }

    _recentRequests[key] = now;
    _recentRequests.removeWhere(
      (_, time) => now.difference(time) > _duplicateWindow,
    );
    return false;
  }

  Future<String?> createEvent(StudyEvent event) async {
    final result = await createEventWithResult(event);
    return result.eventId;
  }

  Future<CalendarCreateResult> createEventWithResult(StudyEvent event) async {
    debugPrint('[CALENDAR] create requested ${event.id}');

    if (event.syncedWithCalendar && event.calendarEventId != null) {
      debugPrint('[CALENDAR] API success existing ${event.calendarEventId}');
      return CalendarCreateResult.success(event.calendarEventId!);
    }

    if (_isDuplicate(event)) {
      debugPrint('[CALENDAR] retry queued duplicate suppressed ${event.id}');
      return const CalendarCreateResult.duplicate();
    }

    try {
      final client = await _authService.getAuthenticatedClient();
      if (client == null) {
        debugPrint('[CALENDAR] auth connected false');
        debugPrint('[CALENDAR] token invalid');
        debugPrint('[CALENDAR] retry queued ${event.id}');
        return const CalendarCreateResult.failure(
          'Conta Google sem token válido para Calendar.',
        );
      }

      debugPrint('[CALENDAR] auth connected true');
      debugPrint('[CALENDAR] token valid');

      final calendarApi = calendar.CalendarApi(client);
      final googleEvent = calendar.Event(
        summary: '[${event.subject}] ${event.title}',
        description: event.description.isNotEmpty ? event.description : null,
        start: calendar.EventDateTime(dateTime: event.startDateTime.toUtc()),
        end: calendar.EventDateTime(dateTime: event.endDateTime.toUtc()),
        reminders: calendar.EventReminders(
          useDefault: false,
          overrides: [
            calendar.EventReminder(
              method: 'popup',
              minutes: event.reminderMinutes,
            ),
          ],
        ),
        colorId: '2',
      );

      final createdEvent = await calendarApi.events.insert(
        googleEvent,
        AppConstants.calendarId,
      );
      final eventId = createdEvent.id;
      if (eventId == null || eventId.isEmpty) {
        debugPrint('[CALENDAR] API failure empty event id');
        debugPrint('[CALENDAR] retry queued ${event.id}');
        return const CalendarCreateResult.failure(
          'Calendar respondeu sem ID de evento.',
        );
      }

      debugPrint('[CALENDAR] API success $eventId');
      return CalendarCreateResult.success(eventId);
    } catch (e) {
      debugPrint('[CALENDAR] API failure $e');
      debugPrint('[CALENDAR] retry queued ${event.id}');
      return CalendarCreateResult.failure(_friendlyCalendarError(e));
    }
  }

  Future<bool> deleteEvent(String googleEventId) async {
    debugPrint('[CALENDAR] delete requested $googleEventId');
    try {
      final client = await _authService.getAuthenticatedClient();
      if (client == null) {
        debugPrint('[CALENDAR] auth connected false');
        debugPrint('[CALENDAR] token invalid');
        return false;
      }

      debugPrint('[CALENDAR] auth connected true');
      debugPrint('[CALENDAR] token valid');
      final calendarApi = calendar.CalendarApi(client);
      await calendarApi.events.delete(AppConstants.calendarId, googleEventId);
      debugPrint('[CALENDAR] API success delete $googleEventId');
      return true;
    } catch (e) {
      debugPrint('[CALENDAR] API failure delete $e');
      return false;
    }
  }

  static String friendlyCalendarError(Object error) =>
      _friendlyCalendarError(error);

  static String _friendlyCalendarError(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('calendar api has not been used') ||
        text.contains('calendar-json.googleapis.com') ||
        text.contains('disabled')) {
      return 'A API Google Calendar está desativada no projeto Google Cloud/Firebase. Ative calendar-json.googleapis.com no projeto 539437186516 e tente novamente.';
    }
    if (text.contains('status: 403') || text.contains('insufficient')) {
      return 'O Google recusou a criação no Calendar por permissão insuficiente. Entre novamente com Google e autorize o acesso ao Calendar.';
    }
    if (text.contains('status: 401') || text.contains('unauthorized')) {
      return 'A sessão Google expirou. Entre novamente para sincronizar com o Calendar.';
    }
    if (text.contains('network') || text.contains('socket')) {
      return 'Sem conexão estável com o Google Calendar. O evento ficou salvo no app e será tentado novamente.';
    }
    return 'Não foi possível sincronizar com o Google Calendar agora. O evento ficou salvo no app para nova tentativa.';
  }
}
