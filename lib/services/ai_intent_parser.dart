import 'package:study_hub/config/app_routes.dart';
import 'package:study_hub/models/ai_assistant.dart';
import 'package:study_hub/models/study_goal.dart';
import 'package:study_hub/services/ai_text_utils.dart';

class AiIntentParser {
  const AiIntentParser();

  AiParsedIntent parse(String input, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final query = input.trim();
    final normalized = AiTextUtils.normalize(query);

    if (normalized.isEmpty) {
      return AiParsedIntent(type: AiIntentType.unknown, query: query);
    }

    final route = _routeFor(normalized);
    if (route != null && _looksLikeOpenCommand(normalized)) {
      return AiParsedIntent(
        type: AiIntentType.openRoute,
        query: query,
        routeName: route,
      );
    }

    if (_looksLikeCreateEvent(normalized)) {
      final start = _parseStartMinute(normalized);
      final duration = _parseDuration(normalized) ?? 60;
      final end =
          _parseEndMinute(normalized) ??
          (start == null ? null : start + duration);
      return AiParsedIntent(
        type: AiIntentType.createEvent,
        query: query,
        subject: _extractSubject(normalized),
        date: _parseDate(normalized, reference) ?? reference,
        startMinuteOfDay: start ?? 9 * 60,
        endMinuteOfDay: end ?? 10 * 60,
        durationMinutes: duration,
      );
    }

    if (_looksLikeCreateGoal(normalized)) {
      return AiParsedIntent(
        type: AiIntentType.createGoal,
        query: query,
        subject: _extractSubject(normalized),
        targetMinutes: _parseDuration(normalized) ?? 120,
        goalType: normalized.contains('mensal') || normalized.contains('month')
            ? GoalType.monthly
            : GoalType.weekly,
      );
    }

    if (_looksLikeSummarize(normalized)) {
      return AiParsedIntent(type: AiIntentType.summarize, query: query);
    }

    if (_looksLikeInsight(normalized)) {
      return AiParsedIntent(
        type: AiIntentType.productivityInsight,
        query: query,
        subject: _extractSubject(normalized),
      );
    }

    if (_looksLikeHistorySearch(normalized)) {
      return AiParsedIntent(
        type: AiIntentType.historySearch,
        query: query,
        subject: _extractSubject(normalized),
        date: _parseDate(normalized, reference),
      );
    }

    if (_looksLikeHelp(normalized)) {
      return AiParsedIntent(type: AiIntentType.appHelp, query: query);
    }

    return AiParsedIntent(
      type: AiIntentType.historySearch,
      query: query,
      subject: _extractSubject(normalized),
      date: _parseDate(normalized, reference),
    );
  }

  bool _looksLikeCreateEvent(String value) {
    return (value.contains('criar') ||
            value.contains('create') ||
            value.contains('agendar') ||
            value.contains('schedule')) &&
        (value.contains('evento') ||
            value.contains('event') ||
            value.contains('sessao') ||
            value.contains('session'));
  }

  bool _looksLikeCreateGoal(String value) {
    return (value.contains('criar') || value.contains('create')) &&
        (value.contains('meta') || value.contains('goal'));
  }

  bool _looksLikeHistorySearch(String value) {
    return value.contains('estudei') ||
        value.contains('study') ||
        value.contains('studied') ||
        value.contains('historico') ||
        value.contains('history') ||
        value.contains('last notes') ||
        value.contains('ultimas notas') ||
        value.contains('notas sobre') ||
        value.contains('notes about') ||
        value.contains('quanto') ||
        value.contains('how much');
  }

  bool _looksLikeInsight(String value) {
    return value.contains('produtividade') ||
        value.contains('productivity') ||
        value.contains('desempenho') ||
        value.contains('insight') ||
        value.contains('forte') ||
        value.contains('strongest') ||
        value.contains('weak') ||
        value.contains('fraco') ||
        value.contains('neglig');
  }

  bool _looksLikeSummarize(String value) {
    return value.contains('resuma') ||
        value.contains('resumir') ||
        value.contains('summarize') ||
        value.contains('summary');
  }

  bool _looksLikeHelp(String value) {
    return value.startsWith('como ') ||
        value.startsWith('how ') ||
        value.contains('como faco') ||
        value.contains('how do i') ||
        value.contains('ajuda') ||
        value.contains('help');
  }

  bool _looksLikeOpenCommand(String value) {
    return value.contains('abrir') ||
        value.contains('open') ||
        value.contains('ir para') ||
        value.contains('go to');
  }

  String? _routeFor(String value) {
    if (value.contains('conquista') ||
        value.contains('achievement') ||
        value.contains('certificado')) {
      return AppRoutes.achievements;
    }
    if (value.contains('registro') || value.contains('log')) {
      return AppRoutes.studyLog;
    }
    if (value.contains('agenda') || value.contains('evento')) {
      return AppRoutes.createEvent;
    }
    if (value.contains('historico') || value.contains('history')) {
      return AppRoutes.history;
    }
    if (value.contains('config') || value.contains('settings')) {
      return AppRoutes.settings;
    }
    return null;
  }

  DateTime? _parseDate(String value, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    if (value.contains('hoje') || value.contains('today')) return today;
    if (value.contains('amanha') || value.contains('tomorrow')) {
      return today.add(const Duration(days: 1));
    }
    if (value.contains('ontem') || value.contains('yesterday')) {
      return today.subtract(const Duration(days: 1));
    }

    final explicit = RegExp(
      r'\b(\d{1,2})[/-](\d{1,2})(?:[/-](\d{2,4}))?\b',
    ).firstMatch(value);
    if (explicit != null) {
      final day = int.tryParse(explicit.group(1)!);
      final month = int.tryParse(explicit.group(2)!);
      var year = int.tryParse(explicit.group(3) ?? now.year.toString());
      if (year != null && year < 100) year += 2000;
      if (day != null && month != null && year != null) {
        return DateTime(year, month, day);
      }
    }

    const weekdays = {
      'segunda': 1,
      'monday': 1,
      'terca': 2,
      'tuesday': 2,
      'quarta': 3,
      'wednesday': 3,
      'quinta': 4,
      'thursday': 4,
      'sexta': 5,
      'friday': 5,
      'sabado': 6,
      'saturday': 6,
      'domingo': 7,
      'sunday': 7,
    };
    for (final entry in weekdays.entries) {
      if (!value.contains(entry.key)) continue;
      final isPast = value.contains('last') || value.contains('passad');
      var diff = entry.value - today.weekday;
      if (isPast && diff >= 0) diff -= 7;
      if (!isPast && diff < 0) diff += 7;
      return today.add(Duration(days: diff));
    }
    return null;
  }

  int? _parseStartMinute(String value) {
    final range = RegExp(
      r'\b(?:das|from)?\s*(\d{1,2})(?::|h)?(\d{2})?\s*(am|pm)?\s*(?:as|to|-)\s*(\d{1,2})(?::|h)?(\d{2})?\s*(am|pm)?',
    ).firstMatch(value);
    if (range != null) {
      return _minuteOfDay(range.group(1), range.group(2), range.group(3));
    }

    final at = RegExp(
      r'\b(?:at|as|às|a)\s*(\d{1,2})(?::|h)?(\d{2})?\s*(am|pm)?\b',
    ).firstMatch(value);
    if (at != null) return _minuteOfDay(at.group(1), at.group(2), at.group(3));

    final simple = RegExp(r'\b(\d{1,2})(?::|h)(\d{2})\b').firstMatch(value);
    if (simple != null) {
      return _minuteOfDay(simple.group(1), simple.group(2), null);
    }
    return null;
  }

  int? _parseEndMinute(String value) {
    final range = RegExp(
      r'\b(?:das|from)?\s*(\d{1,2})(?::|h)?(\d{2})?\s*(am|pm)?\s*(?:as|to|-)\s*(\d{1,2})(?::|h)?(\d{2})?\s*(am|pm)?',
    ).firstMatch(value);
    if (range == null) return null;
    return _minuteOfDay(range.group(4), range.group(5), range.group(6));
  }

  int? _parseDuration(String value) {
    final hours = RegExp(
      r'\b(\d{1,2})\s*(?:h|hora|horas|hour|hours)\b',
    ).firstMatch(value);
    final minutes = RegExp(
      r'\b(\d{1,3})\s*(?:min|minutos|minutes)\b',
    ).firstMatch(value);
    var total = 0;
    if (hours != null) total += (int.tryParse(hours.group(1)!) ?? 0) * 60;
    if (minutes != null) total += int.tryParse(minutes.group(1)!) ?? 0;
    return total > 0 ? total : null;
  }

  int? _minuteOfDay(String? hourText, String? minuteText, String? marker) {
    var hour = int.tryParse(hourText ?? '');
    final minute = int.tryParse(minuteText ?? '0') ?? 0;
    if (hour == null || hour > 24 || minute > 59) return null;
    if (marker == 'pm' && hour < 12) hour += 12;
    if (marker == 'am' && hour == 12) hour = 0;
    if (hour == 24) hour = 0;
    return hour * 60 + minute;
  }

  String? _extractSubject(String value) {
    final patterns = [
      RegExp(r'\b(?:for|para|sobre|about)\s+([a-z0-9][a-z0-9\s-]{1,40})'),
      RegExp(r'\b(?:materia|subject)\s+([a-z0-9][a-z0-9\s-]{1,40})'),
      RegExp(r'\bde\s+(?!\d)([a-z0-9][a-z0-9\s-]{1,40})'),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(value);
      if (match == null) continue;
      var subject = match.group(1)!.trim();
      subject = subject
          .replaceAll(
            RegExp(
              r'\b(tomorrow|today|amanha|hoje|ontem|at|as|from|to|das|por|durante|with|com|this|week|semana|mes|month|hora|horas|hour|hours|min|minutos|minutes)\b.*$',
            ),
            '',
          )
          .replaceAll(RegExp(r'^\d+\s*'), '')
          .replaceAll(RegExp(r'\bpara\b.*$'), '')
          .trim();
      if (subject.isNotEmpty) return _titleCase(subject);
    }
    return null;
  }

  String _titleCase(String value) {
    return value
        .split(' ')
        .where((part) => part.trim().isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }
}
