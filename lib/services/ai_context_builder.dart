import 'package:study_hub/models/achievement_progress.dart';
import 'package:study_hub/models/study_event.dart';
import 'package:study_hub/models/study_goal.dart';
import 'package:study_hub/models/study_log.dart';
import 'package:study_hub/providers/certificate_provider.dart';
import 'package:study_hub/providers/goal_provider.dart';
import 'package:study_hub/providers/settings_provider.dart';
import 'package:study_hub/providers/study_event_provider.dart';
import 'package:study_hub/providers/study_log_provider.dart';

class AiContextSnapshot {
  final List<StudyLog> logs;
  final List<StudyEvent> events;
  final List<StudyGoal> goals;
  final int totalStudyMinutes;
  final int weeklyStudyMinutes;
  final int monthlyStudyMinutes;
  final int previousMonthStudyMinutes;
  final int currentStreak;
  final int certificateCount;
  final int trustedCertificateCount;
  final AchievementProgress achievementProgress;
  final String userName;
  final bool googleConnected;
  final bool notionConnected;

  const AiContextSnapshot({
    required this.logs,
    required this.events,
    required this.goals,
    required this.totalStudyMinutes,
    required this.weeklyStudyMinutes,
    required this.monthlyStudyMinutes,
    required this.previousMonthStudyMinutes,
    required this.currentStreak,
    required this.certificateCount,
    required this.trustedCertificateCount,
    required this.achievementProgress,
    required this.userName,
    required this.googleConnected,
    required this.notionConnected,
  });
}

class AiContextBuilder {
  const AiContextBuilder();

  AiContextSnapshot build({
    required StudyLogProvider logs,
    required StudyEventProvider events,
    required GoalProvider goals,
    required CertificateProvider certificates,
    required SettingsProvider settings,
  }) {
    if (!settings.settings.lumaPersonalizationEnabled) {
      return AiContextSnapshot(
        logs: const [],
        events: const [],
        goals: const [],
        totalStudyMinutes: 0,
        weeklyStudyMinutes: 0,
        monthlyStudyMinutes: 0,
        previousMonthStudyMinutes: 0,
        currentStreak: 0,
        certificateCount: 0,
        trustedCertificateCount: 0,
        achievementProgress: AchievementRankCalculator.calculate(
          certificateCount: 0,
          totalStudyMinutes: 0,
          completedGoals: 0,
          currentStreak: 0,
        ),
        userName: 'Estudante',
        googleConnected: settings.isGoogleConnected,
        notionConnected: settings.isNotionConnected,
      );
    }

    final totalStudyMinutes = logs.logs.fold<int>(
      0,
      (sum, log) => sum + log.studyTimeMinutes,
    );
    final completedGoals = goals.goals.where((goal) {
      return goals.calculateProgress(goal, logs.logs) >= 1;
    }).length;
    final progress = certificates.progressFor(
      totalStudyMinutes: totalStudyMinutes,
      currentStreak: logs.currentStreak,
      completedGoals: completedGoals,
    );

    return AiContextSnapshot(
      logs: logs.logs,
      events: events.events,
      goals: goals.goals,
      totalStudyMinutes: totalStudyMinutes,
      weeklyStudyMinutes: logs.weeklyStudyMinutes,
      monthlyStudyMinutes: logs.monthlyStudyMinutes,
      previousMonthStudyMinutes: logs.previousMonthStudyMinutes,
      currentStreak: logs.currentStreak,
      certificateCount: certificates.totalCertificates,
      trustedCertificateCount: certificates.trustedCertificates,
      achievementProgress: progress,
      userName: settings.settings.userName ?? 'Estudante',
      googleConnected: settings.isGoogleConnected,
      notionConnected: settings.isNotionConnected,
    );
  }
}
