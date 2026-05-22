import 'package:flutter/material.dart';
import 'package:study_hub/models/study_event.dart';
import 'package:study_hub/models/study_goal.dart';

enum AiMessageAuthor { user, luma, system }

enum AiMessageKind { text, insight, searchResults, help, actionDraft, summary }

enum AiActionType { createEvent, createGoal, openRoute }

enum AiInsightTone { neutral, success, warning, focus }

enum AiIntentType {
  appHelp,
  createEvent,
  createGoal,
  historySearch,
  productivityInsight,
  summarize,
  openRoute,
  unknown,
}

class AiMessage {
  final String id;
  final AiMessageAuthor author;
  final AiMessageKind kind;
  final String title;
  final String body;
  final DateTime createdAt;
  final List<AiResultItem> results;
  final AiActionDraft? actionDraft;

  AiMessage({
    String? id,
    required this.author,
    required this.kind,
    this.title = '',
    required this.body,
    DateTime? createdAt,
    this.results = const [],
    this.actionDraft,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
       createdAt = createdAt ?? DateTime.now();
}

class AiResultItem {
  final String title;
  final String subtitle;
  final String detail;
  final DateTime? date;

  const AiResultItem({
    required this.title,
    required this.subtitle,
    this.detail = '',
    this.date,
  });
}

class AiActionDraft {
  final AiActionType type;
  final String title;
  final String description;
  final String? subject;
  final DateTime? date;
  final int? startMinuteOfDay;
  final int? endMinuteOfDay;
  final int reminderMinutes;
  final GoalType? goalType;
  final int? targetMinutes;
  final List<String> goalSubjects;
  final String? routeName;

  const AiActionDraft({
    required this.type,
    required this.title,
    this.description = '',
    this.subject,
    this.date,
    this.startMinuteOfDay,
    this.endMinuteOfDay,
    this.reminderMinutes = 15,
    this.goalType,
    this.targetMinutes,
    this.goalSubjects = const [],
    this.routeName,
  });

  StudyEvent toStudyEvent() {
    final start = startMinuteOfDay ?? 9 * 60;
    final end = endMinuteOfDay ?? start + 60;
    return StudyEvent(
      subject: subject ?? 'Geral',
      title: title,
      description: description,
      date: date ?? DateTime.now(),
      startTime: _timeFromMinutes(start),
      endTime: _timeFromMinutes(end),
      reminderMinutes: reminderMinutes,
    );
  }

  StudyGoal toStudyGoal() {
    final type = goalType ?? GoalType.weekly;
    return StudyGoal(
      type: type,
      targetMinutes: targetMinutes ?? 120,
      languages: goalSubjects,
      periodStart: type == GoalType.weekly
          ? StudyGoal.currentWeekStart()
          : StudyGoal.currentMonthStart(),
    );
  }

  static TimeOfDay _timeFromMinutes(int minutes) {
    final clamped = minutes.clamp(0, 23 * 60 + 59);
    final hour = clamped ~/ 60;
    final minute = clamped % 60;
    return TimeOfDay(hour: hour, minute: minute);
  }
}

class AiRecommendation {
  final String title;
  final String body;
  final AiInsightTone tone;
  final AiActionDraft? actionDraft;

  const AiRecommendation({
    required this.title,
    required this.body,
    this.tone = AiInsightTone.neutral,
    this.actionDraft,
  });
}

class AiParsedIntent {
  final AiIntentType type;
  final String query;
  final String? subject;
  final DateTime? date;
  final int? startMinuteOfDay;
  final int? endMinuteOfDay;
  final int? durationMinutes;
  final int? targetMinutes;
  final GoalType? goalType;
  final String? routeName;

  const AiParsedIntent({
    required this.type,
    required this.query,
    this.subject,
    this.date,
    this.startMinuteOfDay,
    this.endMinuteOfDay,
    this.durationMinutes,
    this.targetMinutes,
    this.goalType,
    this.routeName,
  });
}
