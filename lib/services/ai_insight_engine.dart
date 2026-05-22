import 'package:study_hub/models/ai_assistant.dart';
import 'package:study_hub/models/study_goal.dart';
import 'package:study_hub/services/ai_context_builder.dart';
import 'package:study_hub/services/ai_text_utils.dart';
import 'package:study_hub/utils/date_helpers.dart';

class AiInsightSummary {
  final int weeklyMinutes;
  final int monthlyMinutes;
  final int currentStreak;
  final String? strongestDay;
  final String? weakestSubject;
  final String? strongestSubject;
  final String headline;
  final String detail;
  final AiInsightTone tone;

  const AiInsightSummary({
    required this.weeklyMinutes,
    required this.monthlyMinutes,
    required this.currentStreak,
    required this.headline,
    required this.detail,
    required this.tone,
    this.strongestDay,
    this.weakestSubject,
    this.strongestSubject,
  });
}

class AiInsightEngine {
  const AiInsightEngine();

  AiInsightSummary summarize(AiContextSnapshot context) {
    final subjectMinutes = _subjectMinutes(context);
    final weekdayMinutes = _weekdayMinutes(context);
    final strongestSubject = _maxEntry(subjectMinutes)?.key;
    final weakestSubject = _neglectedSubject(subjectMinutes);
    final strongestDay = _maxEntry(weekdayMinutes)?.key;

    final activeGoals = context.goals.where((goal) {
      return goal.deletedAt == null && goal.coversDate(DateTime.now());
    }).toList();
    final hasGoalRisk = activeGoals.any((goal) {
      final studied = context.logs
          .where((log) => goal.coversDate(log.date))
          .fold<int>(0, (sum, log) => sum + log.studyTimeMinutes);
      return studied < goal.targetMinutes * 0.35 &&
          DateTime.now().isAfter(
            goal.periodStart.add(
              Duration(days: goal.type == GoalType.weekly ? 3 : 14),
            ),
          );
    });

    if (context.logs.isEmpty) {
      return const AiInsightSummary(
        weeklyMinutes: 0,
        monthlyMinutes: 0,
        currentStreak: 0,
        headline: 'Luma está pronta para acompanhar seus estudos.',
        detail:
            'Registre uma sessao para eu gerar padroes, dias fortes e sugestoes melhores.',
        tone: AiInsightTone.neutral,
      );
    }

    if (hasGoalRisk) {
      return AiInsightSummary(
        weeklyMinutes: context.weeklyStudyMinutes,
        monthlyMinutes: context.monthlyStudyMinutes,
        currentStreak: context.currentStreak,
        strongestDay: strongestDay,
        weakestSubject: weakestSubject,
        strongestSubject: strongestSubject,
        headline: 'Uma meta precisa de atencao.',
        detail:
            'Você estudou ${DateHelpers.formatDuration(context.weeklyStudyMinutes)} nesta semana. Um bloco curto hoje ajuda a proteger o ritmo.',
        tone: AiInsightTone.warning,
      );
    }

    if (weakestSubject != null) {
      return AiInsightSummary(
        weeklyMinutes: context.weeklyStudyMinutes,
        monthlyMinutes: context.monthlyStudyMinutes,
        currentStreak: context.currentStreak,
        strongestDay: strongestDay,
        weakestSubject: weakestSubject,
        strongestSubject: strongestSubject,
        headline: '$weakestSubject ficou mais quieto.',
        detail:
            'Uma revisao de 30 minutos pode equilibrar sua semana sem quebrar o foco atual.',
        tone: AiInsightTone.focus,
      );
    }

    return AiInsightSummary(
      weeklyMinutes: context.weeklyStudyMinutes,
      monthlyMinutes: context.monthlyStudyMinutes,
      currentStreak: context.currentStreak,
      strongestDay: strongestDay,
      weakestSubject: weakestSubject,
      strongestSubject: strongestSubject,
      headline: 'Seu ritmo está consistente.',
      detail:
          'Semana: ${DateHelpers.formatDuration(context.weeklyStudyMinutes)}. Sequencia atual: ${context.currentStreak} dia(s).',
      tone: AiInsightTone.success,
    );
  }

  List<AiResultItem> productivityCards(AiContextSnapshot context) {
    final summary = summarize(context);
    return [
      AiResultItem(
        title: 'Semana',
        subtitle: DateHelpers.formatDuration(summary.weeklyMinutes),
        detail: '${context.logs.length} registro(s) no historico local.',
      ),
      AiResultItem(
        title: 'Sequencia',
        subtitle: '${summary.currentStreak} dia(s)',
        detail: summary.currentStreak == 0
            ? 'Registre hoje para iniciar uma nova sequencia.'
            : 'Sua consistência está ativa.',
      ),
      if (summary.strongestDay != null)
        AiResultItem(
          title: 'Dia mais forte',
          subtitle: summary.strongestDay!,
          detail: 'Maior volume acumulado por dia da semana.',
        ),
      if (summary.weakestSubject != null)
        AiResultItem(
          title: 'Materia negligenciada',
          subtitle: summary.weakestSubject!,
          detail: 'Aparece menos nos registros recentes.',
        ),
    ];
  }

  Map<String, int> _subjectMinutes(AiContextSnapshot context) {
    final values = <String, int>{};
    for (final log in context.logs) {
      final subject = AiTextUtils.subjectForLog(log);
      values[subject] = (values[subject] ?? 0) + log.studyTimeMinutes;
    }
    return values;
  }

  Map<String, int> _weekdayMinutes(AiContextSnapshot context) {
    const names = {
      1: 'segunda',
      2: 'terca',
      3: 'quarta',
      4: 'quinta',
      5: 'sexta',
      6: 'sabado',
      7: 'domingo',
    };
    final values = <String, int>{};
    for (final log in context.logs) {
      final day = names[log.date.weekday] ?? 'dia';
      values[day] = (values[day] ?? 0) + log.studyTimeMinutes;
    }
    return values;
  }

  MapEntry<String, int>? _maxEntry(Map<String, int> map) {
    if (map.isEmpty) return null;
    return map.entries.reduce((a, b) => a.value >= b.value ? a : b);
  }

  String? _neglectedSubject(Map<String, int> subjectMinutes) {
    if (subjectMinutes.length < 2) return null;
    final sorted = subjectMinutes.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final weakest = sorted.first;
    final strongest = sorted.last;
    if (strongest.value - weakest.value < 45) return null;
    return weakest.key;
  }
}
