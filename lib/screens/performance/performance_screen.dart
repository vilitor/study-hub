import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:study_hub/config/app_theme.dart';
import 'package:study_hub/models/study_goal.dart';
import 'package:study_hub/models/study_log.dart';
import 'package:study_hub/providers/goal_provider.dart';
import 'package:study_hub/providers/study_log_provider.dart';
import 'package:study_hub/utils/date_helpers.dart';
import 'package:study_hub/widgets/app_surface.dart';
import 'package:study_hub/widgets/luma_recommendation_card.dart';
import 'package:study_hub/widgets/study_heatmap.dart';

class PerformanceScreen extends StatelessWidget {
  const PerformanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Scaffold(
      appBar: AppBar(title: const Text('Desempenho')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            spacing.screenPadding,
            spacing.lg,
            spacing.screenPadding,
            140 + MediaQuery.of(context).padding.bottom,
          ),
          child: Consumer2<StudyLogProvider, GoalProvider>(
            builder: (context, logProvider, goalProvider, _) {
              final logs = logProvider.logs;
              final activeGoal =
                  goalProvider.activeWeeklyGoal ??
                  goalProvider.activeMonthlyGoal;
              final model = _PerformanceModel.fromLogs(
                logs,
                activeGoal: activeGoal,
                goalProvider: goalProvider,
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppSectionHeader(
                    title: 'Dashboard',
                    subtitle:
                        'Insights e comparativos gerados a partir dos registros locais.',
                  ),
                  SizedBox(height: spacing.sectionGap),
                  const LumaRecommendationCard(title: 'Leitura do desempenho'),
                  SizedBox(height: spacing.sectionGap),
                  _SummaryRow(model: model),
                  SizedBox(height: spacing.sectionGap),
                  _InsightsSection(model: model),
                  SizedBox(height: spacing.sectionGap),
                  _StudyTrendChart(model: model),
                  SizedBox(height: spacing.sectionGap),
                  _SubjectDistributionChart(model: model),
                  SizedBox(height: spacing.sectionGap),
                  _GoalSection(model: model),
                  SizedBox(height: spacing.sectionGap),
                  AppSurface(
                    child: StudyHeatmap(datasets: logProvider.heatmapDataset),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final _PerformanceModel model;

  const _SummaryRow({required this.model});

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            title: 'Semana',
            value: DateHelpers.formatDuration(model.weeklyMinutes),
            detail: '${model.weeklySessions} sessões',
            tone: context.colors.accent,
          ),
        ),
        SizedBox(width: spacing.md),
        Expanded(
          child: _SummaryCard(
            title: 'Mês',
            value: DateHelpers.formatDuration(model.monthlyMinutes),
            detail: model.monthlyDeltaLabel,
            tone: context.colors.accentSecondary,
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String detail;
  final Color tone;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.detail,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          Text(value, style: context.theme.textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text(
            detail,
            style: context.theme.textTheme.labelMedium?.copyWith(color: tone),
          ),
        ],
      ),
    );
  }
}

class _InsightsSection extends StatelessWidget {
  final _PerformanceModel model;

  const _InsightsSection({required this.model});

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final insights = model.insights;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionHeader(
          title: 'Insights',
          subtitle: 'Padrões identificados automaticamente.',
        ),
        SizedBox(height: spacing.md),
        if (insights.isEmpty)
          const _FallbackPanel(
            title: 'Dados insuficientes',
            subtitle:
                'Registre mais sessões para gerar comparativos e padrões.',
          )
        else
          ...insights.map(
            (insight) => Padding(
              padding: EdgeInsets.only(bottom: spacing.sm),
              child: AppSurface(
                child: Row(
                  children: [
                    Icon(insight.icon, color: insight.tone),
                    const SizedBox(width: 12),
                    Expanded(child: Text(insight.message)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _StudyTrendChart extends StatelessWidget {
  final _PerformanceModel model;

  const _StudyTrendChart({required this.model});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final bars = model.last7Days;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionHeader(
          title: 'Tendência semanal',
          subtitle: 'Minutos estudados nos últimos sete dias.',
        ),
        const SizedBox(height: 16),
        AppSurface(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final chartHeight = constraints.maxWidth < 360 ? 176.0 : 208.0;
              final rawMax = bars.fold<int>(
                0,
                (max, item) => item.minutes > max ? item.minutes : max,
              );
              final maxY = (rawMax == 0 ? 60 : (rawMax * 1.2).clamp(60, 240))
                  .toDouble();
              final interval = maxY <= 120 ? 30.0 : 60.0;

              return ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: chartHeight,
                  maxHeight: chartHeight,
                ),
                child: Padding(
                  padding: EdgeInsets.only(
                    top: spacing.xs,
                    right: spacing.xxs,
                    bottom: spacing.xs,
                  ),
                  child: ClipRect(
                    child: BarChart(
                      BarChartData(
                        minY: 0,
                        alignment: BarChartAlignment.spaceAround,
                        maxY: maxY,
                        groupsSpace: constraints.maxWidth < 360 ? 10 : 14,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: interval,
                          getDrawingHorizontalLine: (_) => FlLine(
                            color: colors.borderSubtle,
                            strokeWidth: 1,
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          leftTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 28,
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();
                                if (index < 0 || index >= bars.length) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: EdgeInsets.only(top: spacing.xs),
                                  child: Text(
                                    bars[index].label,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.theme.textTheme.bodySmall,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        barGroups: [
                          for (int i = 0; i < bars.length; i++)
                            BarChartGroupData(
                              x: i,
                              barRods: [
                                BarChartRodData(
                                  toY: bars[i].minutes.toDouble().clamp(
                                    0,
                                    maxY,
                                  ),
                                  width: constraints.maxWidth < 360 ? 10 : 12,
                                  borderRadius: BorderRadius.circular(6),
                                  color: colors.accent,
                                  backDrawRodData: BackgroundBarChartRodData(
                                    show: true,
                                    toY: maxY,
                                    color: colors.surface2,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SubjectDistributionChart extends StatelessWidget {
  final _PerformanceModel model;

  const _SubjectDistributionChart({required this.model});

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    if (model.subjectBreakdown.isEmpty) {
      return const _FallbackPanel(
        title: 'Sem distribuição por matéria',
        subtitle:
            'As matérias aparecem conforme os registros forem classificados.',
      );
    }

    final maxMinutes = model.subjectBreakdown.values.reduce(
      (a, b) => a > b ? a : b,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionHeader(
          title: 'Tempo por matéria',
          subtitle: 'Comparativo dos assuntos mais frequentes.',
        ),
        SizedBox(height: spacing.md),
        AppSurface(
          child: Column(
            children: model.subjectBreakdown.entries.map((entry) {
              final ratio = maxMinutes == 0 ? 0.0 : entry.value / maxMinutes;
              return Padding(
                padding: EdgeInsets.only(bottom: spacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.key,
                            style: context.theme.textTheme.labelLarge,
                          ),
                        ),
                        Text(
                          DateHelpers.formatDuration(entry.value),
                          style: context.theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                    SizedBox(height: spacing.xs),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: ratio.clamp(0, 1),
                        minHeight: 8,
                        backgroundColor: context.colors.surface2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.getSubjectColor(
                            model.subjectBreakdown.keys.toList().indexOf(
                              entry.key,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _GoalSection extends StatelessWidget {
  final _PerformanceModel model;

  const _GoalSection({required this.model});

  @override
  Widget build(BuildContext context) {
    if (model.goalProgress == null) {
      return const _FallbackPanel(
        title: 'Sem meta ativa',
        subtitle:
            'Crie uma meta semanal ou mensal na tela inicial para acompanhar o progresso aqui.',
      );
    }

    final goal = model.goalProgress!;
    return AppSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionHeader(
            title: 'Progresso da meta',
            subtitle: 'Execução da meta ativa no período atual.',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  goal.label,
                  style: context.theme.textTheme.titleMedium,
                ),
              ),
              Text(
                '${(goal.progress * 100).round()}%',
                style: context.theme.textTheme.labelLarge?.copyWith(
                  color: context.colors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: goal.progress,
            minHeight: 10,
            borderRadius: BorderRadius.circular(999),
            backgroundColor: context.colors.surface2,
            valueColor: AlwaysStoppedAnimation<Color>(context.colors.accent),
          ),
          const SizedBox(height: 8),
          Text(
            '${DateHelpers.formatDuration(goal.studiedMinutes)} de ${DateHelpers.formatDuration(goal.targetMinutes)}',
            style: context.theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _FallbackPanel extends StatelessWidget {
  final String title;
  final String subtitle;

  const _FallbackPanel({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(subtitle, style: context.theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _InsightItem {
  final String message;
  final IconData icon;
  final Color tone;

  const _InsightItem({
    required this.message,
    required this.icon,
    required this.tone,
  });
}

class _GoalProgressModel {
  final String label;
  final double progress;
  final int studiedMinutes;
  final int targetMinutes;

  const _GoalProgressModel({
    required this.label,
    required this.progress,
    required this.studiedMinutes,
    required this.targetMinutes,
  });
}

class _DayPoint {
  final String label;
  final int minutes;

  const _DayPoint({required this.label, required this.minutes});
}

class _PerformanceModel {
  final int weeklyMinutes;
  final int weeklySessions;
  final int monthlyMinutes;
  final int previousMonthMinutes;
  final Map<String, int> subjectBreakdown;
  final List<_InsightItem> insights;
  final List<_DayPoint> last7Days;
  final _GoalProgressModel? goalProgress;

  const _PerformanceModel({
    required this.weeklyMinutes,
    required this.weeklySessions,
    required this.monthlyMinutes,
    required this.previousMonthMinutes,
    required this.subjectBreakdown,
    required this.insights,
    required this.last7Days,
    required this.goalProgress,
  });

  String get monthlyDeltaLabel {
    if (previousMonthMinutes == 0) return 'Primeiro mês com dados';
    final delta =
        ((monthlyMinutes - previousMonthMinutes) / previousMonthMinutes) * 100;
    final prefix = delta >= 0 ? '+' : '';
    return '$prefix${delta.round()}% vs mês anterior';
  }

  factory _PerformanceModel.fromLogs(
    List<StudyLog> logs, {
    required StudyGoal? activeGoal,
    required GoalProvider goalProvider,
  }) {
    final now = DateTime.now();
    final startOfWeek = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday % 7));
    final startOfMonth = DateTime(now.year, now.month, 1);
    final prevMonthDate = DateTime(now.year, now.month - 1, 1);
    final previousMonth = logs
        .where(
          (log) =>
              log.date.year == prevMonthDate.year &&
              log.date.month == prevMonthDate.month,
        )
        .toList();
    final weeklyLogs = logs
        .where((log) => !log.date.isBefore(startOfWeek))
        .toList();
    final monthlyLogs = logs
        .where((log) => !log.date.isBefore(startOfMonth))
        .toList();

    final subjectBreakdown = <String, int>{};
    for (final log in logs) {
      final subject = _extractSubject(log);
      subjectBreakdown[subject] =
          (subjectBreakdown[subject] ?? 0) + log.studyTimeMinutes;
    }

    final sortedSubjects = subjectBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final weekdayBreakdown = <int, int>{};
    for (final log in logs) {
      weekdayBreakdown[log.date.weekday] =
          (weekdayBreakdown[log.date.weekday] ?? 0) + log.studyTimeMinutes;
    }

    final insights = <_InsightItem>[];
    if (sortedSubjects.isNotEmpty) {
      insights.add(
        _InsightItem(
          message:
              '${sortedSubjects.first.key} é a matéria mais consistente até agora.',
          icon: Icons.school_rounded,
          tone: AppColors.primaryGreen,
        ),
      );
    }
    if (weekdayBreakdown.isNotEmpty) {
      final bestDay = weekdayBreakdown.entries.reduce(
        (a, b) => a.value >= b.value ? a : b,
      );
      const names = {
        1: 'segunda',
        2: 'terça',
        3: 'quarta',
        4: 'quinta',
        5: 'sexta',
        6: 'sábado',
        7: 'domingo',
      };
      insights.add(
        _InsightItem(
          message: 'Seu melhor volume acontece na ${names[bestDay.key]}.',
          icon: Icons.calendar_view_week_rounded,
          tone: AppColors.purple,
        ),
      );
    }
    if (logs.isNotEmpty) {
      final avg =
          logs.fold<int>(0, (sum, log) => sum + log.studyTimeMinutes) /
          logs.length;
      insights.add(
        _InsightItem(
          message: 'Sua sessão média tem ${avg.round()} minutos de foco.',
          icon: Icons.timer_rounded,
          tone: AppColors.coral,
        ),
      );
    }

    final last7Days = List.generate(7, (index) {
      final date = DateTime(now.year, now.month, now.day - (6 - index));
      final dailyMinutes = logs
          .where(
            (log) =>
                log.date.year == date.year &&
                log.date.month == date.month &&
                log.date.day == date.day,
          )
          .fold<int>(0, (sum, log) => sum + log.studyTimeMinutes);
      const dayNames = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];
      return _DayPoint(
        label: dayNames[date.weekday % 7],
        minutes: dailyMinutes,
      );
    });

    return _PerformanceModel(
      weeklyMinutes: weeklyLogs.fold<int>(
        0,
        (sum, log) => sum + log.studyTimeMinutes,
      ),
      weeklySessions: weeklyLogs.length,
      monthlyMinutes: monthlyLogs.fold<int>(
        0,
        (sum, log) => sum + log.studyTimeMinutes,
      ),
      previousMonthMinutes: previousMonth.fold<int>(
        0,
        (sum, log) => sum + log.studyTimeMinutes,
      ),
      subjectBreakdown: {
        for (final entry in sortedSubjects.take(5)) entry.key: entry.value,
      },
      insights: insights,
      last7Days: last7Days,
      goalProgress: activeGoal == null
          ? null
          : _GoalProgressModel(
              label: activeGoal.languages.isEmpty
                  ? (activeGoal.type == GoalType.weekly
                        ? 'Meta semanal'
                        : 'Meta mensal')
                  : activeGoal.languages.join(', '),
              progress: goalProvider.calculateProgress(activeGoal, logs),
              studiedMinutes: goalProvider.getStudiedMinutes(activeGoal, logs),
              targetMinutes: activeGoal.targetMinutes,
            ),
    );
  }
}

String _extractSubject(StudyLog log) {
  for (final entry in log.schema.properties.entries) {
    final prop = entry.value;
    final raw = log.rawValues[prop.name];
    if ((prop.type == 'select' || prop.type == 'title') &&
        raw != null &&
        raw.toString().isNotEmpty) {
      return raw.toString();
    }
    if (prop.type == 'multi_select' && raw is List && raw.isNotEmpty) {
      return raw.first.toString();
    }
  }
  return 'Geral';
}
