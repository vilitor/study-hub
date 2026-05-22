import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_hub/config/app_routes.dart';
import 'package:study_hub/config/app_theme.dart';
import 'package:study_hub/models/achievement_progress.dart';
import 'package:study_hub/models/ai_assistant.dart';
import 'package:study_hub/models/certificate.dart';
import 'package:study_hub/models/notion_schema.dart';
import 'package:study_hub/models/study_log.dart';
import 'package:study_hub/services/ai_context_builder.dart';
import 'package:study_hub/services/ai_insight_engine.dart';
import 'package:study_hub/services/ai_intent_parser.dart';
import 'package:study_hub/services/ai_knowledge_base.dart';
import 'package:study_hub/services/ai_local_summarizer.dart';
import 'package:study_hub/services/local_study_schema_service.dart';
import 'package:study_hub/widgets/luma_dock_button.dart';

void main() {
  test('Luma parser extracts local event command details', () {
    final parser = AiIntentParser();
    final intent = parser.parse(
      'Create an event tomorrow at 9am for Biology',
      now: DateTime(2026, 5, 19, 12),
    );

    expect(intent.type, AiIntentType.createEvent);
    expect(intent.subject, 'Biology');
    expect(intent.date, DateTime(2026, 5, 20));
    expect(intent.startMinuteOfDay, 9 * 60);
  });

  test('Luma parser extracts weekly goal commands', () {
    final parser = AiIntentParser();
    final intent = parser.parse('Criar meta semanal de 2 horas para SQL');

    expect(intent.type, AiIntentType.createGoal);
    expect(intent.subject, 'Sql');
    expect(intent.targetMinutes, 120);
  });

  test('Knowledge base returns deterministic app help', () {
    final entry = const AiKnowledgeBase().find('Como certificados funcionam?');

    expect(entry, isNotNull);
    expect(entry!.title, contains('Certificados'));
    expect(entry.action?.routeName, AppRoutes.achievements);
  });

  test('Insight engine detects a neglected subject from local logs', () {
    final schema = LocalStudySchemaService.defaultSchema();
    final logs = [
      _log('Algebra', 180, DateTime(2026, 5, 18), schema),
      _log('Biologia', 30, DateTime(2026, 5, 17), schema),
    ];
    final snapshot = AiContextSnapshot(
      logs: logs,
      events: const [],
      goals: const [],
      totalStudyMinutes: 210,
      weeklyStudyMinutes: 210,
      monthlyStudyMinutes: 210,
      previousMonthStudyMinutes: 0,
      currentStreak: 2,
      certificateCount: 0,
      trustedCertificateCount: 0,
      achievementProgress: const AchievementProgress(
        currentRank: AchievementRank.bronze,
        nextRank: AchievementRank.silver,
        progressToNext: 0,
        nextMilestoneLabel: '',
      ),
      userName: 'Victor',
      googleConnected: false,
      notionConnected: false,
    );

    final summary = const AiInsightEngine().summarize(snapshot);

    expect(summary.weakestSubject, 'Biologia');
    expect(summary.tone, AiInsightTone.focus);
  });

  test('Local summarizer produces extractive bullets without cloud AI', () {
    final summary = const AiLocalSummarizer().summarize(
      'Flutter usa widgets para construir interfaces. Widgets podem ser '
      'combinados em arvores. O estado controla mudancas visuais. Testes '
      'ajudam a preservar comportamento durante refatoracoes.',
      maxSentences: 2,
    );

    expect(summary, contains('- '));
    expect(summary.split('\n'), hasLength(2));
  });

  testWidgets('Luma dock opens the local workspace route', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        routes: {
          AppRoutes.luma: (_) => const Scaffold(body: Text('Luma workspace')),
        },
        home: const Scaffold(body: Center(child: LumaDockButton())),
      ),
    );

    await tester.tap(find.byType(LumaDockButton));
    await tester.pumpAndSettle();

    expect(find.text('Luma workspace'), findsOneWidget);
  });

  testWidgets('Luma dock and notes action can occupy opposite floating slots', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        routes: {
          AppRoutes.luma: (_) => const Scaffold(body: Text('Luma workspace')),
        },
        home: Scaffold(
          body: Stack(
            children: [
              const Positioned(left: 20, bottom: 92, child: LumaDockButton()),
              Positioned(
                right: 16,
                bottom: 100,
                child: FloatingActionButton(
                  heroTag: 'notes-test',
                  onPressed: () {},
                  child: const Icon(Icons.edit_note_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final lumaRect = tester.getRect(find.byType(LumaDockButton));
    final notesRect = tester.getRect(find.byType(FloatingActionButton));

    expect(lumaRect.overlaps(notesRect), isFalse);
  });
}

StudyLog _log(
  String subject,
  int minutes,
  DateTime date,
  NotionDatabaseSchema schema,
) {
  return StudyLog(
    rawValues: {
      LocalStudyFields.title: 'Aula de $subject',
      LocalStudyFields.subject: subject,
      LocalStudyFields.category: subject,
      LocalStudyFields.studyTime: minutes,
      LocalStudyFields.notes: 'Notas sobre $subject',
    },
    schema: schema,
    studyTimeField: LocalStudyFields.studyTime,
    date: date,
  );
}
