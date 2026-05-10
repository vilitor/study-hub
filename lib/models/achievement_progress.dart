import 'package:study_hub/models/certificate.dart';

class AchievementProgress {
  final AchievementRank currentRank;
  final AchievementRank? nextRank;
  final double progressToNext;
  final String nextMilestoneLabel;

  const AchievementProgress({
    required this.currentRank,
    required this.nextRank,
    required this.progressToNext,
    required this.nextMilestoneLabel,
  });
}

class AchievementRankCalculator {
  const AchievementRankCalculator._();

  static AchievementProgress calculate({
    required int certificateCount,
    required int totalStudyMinutes,
    required int completedGoals,
    required int currentStreak,
  }) {
    final hours = totalStudyMinutes / 60;
    final current = _rankFor(
      certificateCount: certificateCount,
      studyHours: hours,
      completedGoals: completedGoals,
      currentStreak: currentStreak,
    );
    final next = _nextRank(current);

    if (next == null) {
      return const AchievementProgress(
        currentRank: AchievementRank.master,
        nextRank: null,
        progressToNext: 1,
        nextMilestoneLabel: 'Nível máximo alcançado',
      );
    }

    final requirement = _requirements[next]!;
    final certificateRatio = _ratio(certificateCount, requirement.certificates);
    final hoursRatio = _ratio(hours, requirement.studyHours);
    final goalsRatio = requirement.completedGoals == 0
        ? 1.0
        : _ratio(completedGoals, requirement.completedGoals);
    final consistencyRatio = requirement.streakDays == 0
        ? 1.0
        : _ratio(currentStreak, requirement.streakDays);

    final progress =
        (certificateRatio * 0.42) +
        (hoursRatio * 0.36) +
        (goalsRatio * 0.12) +
        (consistencyRatio * 0.10);

    return AchievementProgress(
      currentRank: current,
      nextRank: next,
      progressToNext: progress.clamp(0, 1),
      nextMilestoneLabel: _nextLabel(
        next,
        certificateCount,
        hours,
        completedGoals,
        currentStreak,
      ),
    );
  }

  static AchievementRank _rankFor({
    required int certificateCount,
    required double studyHours,
    required int completedGoals,
    required int currentStreak,
  }) {
    if (certificateCount >= 30 &&
        studyHours >= 200 &&
        (currentStreak >= 14 || completedGoals >= 2)) {
      return AchievementRank.master;
    }
    if (certificateCount >= 15 && studyHours >= 100 && completedGoals >= 1) {
      return AchievementRank.diamond;
    }
    if (certificateCount >= 7 && studyHours >= 40) {
      return AchievementRank.gold;
    }
    if (certificateCount >= 3 && studyHours >= 15) {
      return AchievementRank.silver;
    }
    if (certificateCount >= 1 || studyHours >= 5) {
      return AchievementRank.bronze;
    }
    return AchievementRank.bronze;
  }

  static AchievementRank? _nextRank(AchievementRank current) {
    return switch (current) {
      AchievementRank.bronze => AchievementRank.silver,
      AchievementRank.silver => AchievementRank.gold,
      AchievementRank.gold => AchievementRank.diamond,
      AchievementRank.diamond => AchievementRank.master,
      AchievementRank.master => null,
    };
  }

  static String _nextLabel(
    AchievementRank next,
    int certificates,
    double hours,
    int goals,
    int streak,
  ) {
    final requirement = _requirements[next]!;
    final missing = <String>[];

    if (certificates < requirement.certificates) {
      missing.add('${requirement.certificates - certificates} certificado(s)');
    }
    if (hours < requirement.studyHours) {
      missing.add('${(requirement.studyHours - hours).ceil()}h de estudo');
    }
    if (goals < requirement.completedGoals) {
      missing.add('${requirement.completedGoals - goals} meta(s) concluída(s)');
    }
    if (streak < requirement.streakDays) {
      missing.add('${requirement.streakDays - streak} dia(s) de sequência');
    }

    if (missing.isEmpty) return 'Você está pronto para ${next.label}';
    return 'Faltam ${missing.take(2).join(' e ')} para ${next.label}';
  }

  static double _ratio(num value, num target) {
    if (target <= 0) return 1;
    return (value / target).clamp(0, 1).toDouble();
  }

  static const Map<AchievementRank, _RankRequirement> _requirements = {
    AchievementRank.bronze: _RankRequirement(certificates: 1, studyHours: 5),
    AchievementRank.silver: _RankRequirement(certificates: 3, studyHours: 15),
    AchievementRank.gold: _RankRequirement(certificates: 7, studyHours: 40),
    AchievementRank.diamond: _RankRequirement(
      certificates: 15,
      studyHours: 100,
      completedGoals: 1,
    ),
    AchievementRank.master: _RankRequirement(
      certificates: 30,
      studyHours: 200,
      completedGoals: 2,
      streakDays: 14,
    ),
  };
}

class _RankRequirement {
  final int certificates;
  final int studyHours;
  final int completedGoals;
  final int streakDays;

  const _RankRequirement({
    required this.certificates,
    required this.studyHours,
    this.completedGoals = 0,
    this.streakDays = 0,
  });
}
