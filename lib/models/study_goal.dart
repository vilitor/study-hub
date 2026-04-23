import 'package:uuid/uuid.dart';

/// Type of study goal period.
enum GoalType { weekly, monthly }

/// Represents a study goal for a specific week or month.
class StudyGoal {
  final String id;
  final GoalType type;
  final int targetMinutes;
  final List<String> languages;
  final DateTime periodStart; // Start of the week (Sunday) or month (1st)
  final DateTime createdAt;

  StudyGoal({
    String? id,
    required this.type,
    required this.targetMinutes,
    required this.languages,
    required this.periodStart,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  StudyGoal copyWith({
    GoalType? type,
    int? targetMinutes,
    List<String>? languages,
    DateTime? periodStart,
  }) {
    return StudyGoal(
      id: id,
      type: type ?? this.type,
      targetMinutes: targetMinutes ?? this.targetMinutes,
      languages: languages ?? this.languages,
      periodStart: periodStart ?? this.periodStart,
      createdAt: createdAt,
    );
  }

  /// Returns the end date of the goal period.
  DateTime get periodEnd {
    if (type == GoalType.weekly) {
      return periodStart.add(const Duration(days: 7));
    } else {
      // End of month
      return DateTime(periodStart.year, periodStart.month + 1, 1);
    }
  }

  /// Checks if this goal covers the given date.
  bool coversDate(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final start = DateTime(periodStart.year, periodStart.month, periodStart.day);
    final end = periodEnd;
    return !d.isBefore(start) && d.isBefore(end);
  }

  /// Returns the period label (e.g., "Semana 14/04 - 20/04" or "Abril 2026").
  String get periodLabel {
    if (type == GoalType.weekly) {
      final end = periodStart.add(const Duration(days: 6));
      return '${periodStart.day}/${periodStart.month} - ${end.day}/${end.month}';
    } else {
      const months = [
        '', 'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
        'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
      ];
      return '${months[periodStart.month]} ${periodStart.year}';
    }
  }

  /// Serializes to a Map for persistence.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type == GoalType.weekly ? 'weekly' : 'monthly',
      'targetMinutes': targetMinutes,
      'languages': languages,
      'periodStart': periodStart.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Deserializes from a Map.
  factory StudyGoal.fromMap(Map<String, dynamic> map) {
    return StudyGoal(
      id: map['id'] as String,
      type: map['type'] == 'weekly' ? GoalType.weekly : GoalType.monthly,
      targetMinutes: map['targetMinutes'] as int,
      languages: List<String>.from(map['languages'] as List),
      periodStart: DateTime.parse(map['periodStart'] as String),
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  // ── Static helpers for period boundaries ──

  /// Returns the start of the current week (Sunday).
  static DateTime currentWeekStart() {
    final now = DateTime.now();
    final sunday = now.subtract(Duration(days: now.weekday % 7));
    return DateTime(sunday.year, sunday.month, sunday.day);
  }

  /// Returns the start of the current month.
  static DateTime currentMonthStart() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }
}
