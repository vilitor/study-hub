import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

/// Modelo: Evento de Estudo
/// Representa uma sessão de estudo agendada na agenda/calendário
class StudyEvent {
  final String id;
  final String subject; // Matéria (ex: "Flutter", "SQL")
  final String title; // Título do evento
  final String description; // Descrição detalhada
  final DateTime date; // Data do evento
  final TimeOfDay startTime; // Hora de início
  final TimeOfDay endTime; // Hora de fim
  final int durationMinutes; // Duração em minutos
  final int reminderMinutes; // Lembrete (minutos antes)
  final String? calendarEventId; // ID do evento no Google Calendar
  final bool syncedWithCalendar; // Se já foi enviado ao Calendar

  StudyEvent({
    String? id,
    required this.subject,
    required this.title,
    this.description = '',
    required this.date,
    required this.startTime,
    required this.endTime,
    this.durationMinutes = 0,
    this.reminderMinutes = 15,
    this.calendarEventId,
    this.syncedWithCalendar = false,
  }) : id = id ?? const Uuid().v4();

  /// Calcula a duração automaticamente a partir de startTime e endTime
  int get calculatedDurationMinutes {
    final startMinutes = startTime.hour * 60 + startTime.minute;
    final endMinutes = endTime.hour * 60 + endTime.minute;
    final diff = endMinutes - startMinutes;
    return diff > 0 ? diff : 0;
  }

  /// Retorna a duração formatada (ex: "1h 30min")
  String get formattedDuration {
    final mins = calculatedDurationMinutes;
    final hours = mins ~/ 60;
    final remainingMins = mins % 60;
    if (hours > 0 && remainingMins > 0) {
      return '${hours}h ${remainingMins}min';
    } else if (hours > 0) {
      return '${hours}h';
    } else {
      return '${remainingMins}min';
    }
  }

  /// Converte startTime para DateTime completo (data + hora)
  DateTime get startDateTime => DateTime(
        date.year,
        date.month,
        date.day,
        startTime.hour,
        startTime.minute,
      );

  /// Converte endTime para DateTime completo
  DateTime get endDateTime => DateTime(
        date.year,
        date.month,
        date.day,
        endTime.hour,
        endTime.minute,
      );

  /// Cria uma cópia do evento com campos alterados
  StudyEvent copyWith({
    String? subject,
    String? title,
    String? description,
    DateTime? date,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    int? durationMinutes,
    int? reminderMinutes,
    String? calendarEventId,
    bool? syncedWithCalendar,
  }) {
    return StudyEvent(
      id: id,
      subject: subject ?? this.subject,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      calendarEventId: calendarEventId ?? this.calendarEventId,
      syncedWithCalendar: syncedWithCalendar ?? this.syncedWithCalendar,
    );
  }

  /// Converte para Map (para salvar localmente)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subject': subject,
      'title': title,
      'description': description,
      'date': date.toIso8601String(),
      'startTimeHour': startTime.hour,
      'startTimeMinute': startTime.minute,
      'endTimeHour': endTime.hour,
      'endTimeMinute': endTime.minute,
      'durationMinutes': durationMinutes,
      'reminderMinutes': reminderMinutes,
      'calendarEventId': calendarEventId,
      'syncedWithCalendar': syncedWithCalendar,
    };
  }

  /// Cria um StudyEvent a partir de um Map
  factory StudyEvent.fromMap(Map<String, dynamic> map) {
    return StudyEvent(
      id: map['id'] as String,
      subject: map['subject'] as String,
      title: map['title'] as String,
      description: map['description'] as String? ?? '',
      date: DateTime.parse(map['date'] as String),
      startTime: TimeOfDay(
        hour: map['startTimeHour'] as int,
        minute: map['startTimeMinute'] as int,
      ),
      endTime: TimeOfDay(
        hour: map['endTimeHour'] as int,
        minute: map['endTimeMinute'] as int,
      ),
      durationMinutes: map['durationMinutes'] as int? ?? 0,
      reminderMinutes: map['reminderMinutes'] as int? ?? 15,
      calendarEventId: map['calendarEventId'] as String?,
      syncedWithCalendar: map['syncedWithCalendar'] as bool? ?? false,
    );
  }

  @override
  String toString() => 'StudyEvent($subject: $title em ${date.day}/${date.month})';
}
