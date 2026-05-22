import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:study_hub/config/app_routes.dart';
import 'package:study_hub/config/app_theme.dart';
import 'package:study_hub/models/certificate.dart';
import 'package:study_hub/models/study_goal.dart';
import 'package:study_hub/providers/auth_session_provider.dart';
import 'package:study_hub/providers/certificate_provider.dart';
import 'package:study_hub/providers/goal_provider.dart';
import 'package:study_hub/providers/navigation_provider.dart';
import 'package:study_hub/providers/settings_provider.dart';
import 'package:study_hub/services/app_haptics.dart';
import 'package:study_hub/providers/study_event_provider.dart';
import 'package:study_hub/providers/study_log_provider.dart';
import 'package:study_hub/screens/home/create_goal_sheet.dart';
import 'package:study_hub/utils/date_helpers.dart';
import 'package:study_hub/widgets/app_modal.dart';
import 'package:study_hub/widgets/app_surface.dart';
import 'package:study_hub/widgets/certificate_widgets.dart';
import 'package:study_hub/widgets/goal_card.dart';
import 'package:study_hub/widgets/luma_recommendation_card.dart';
import 'package:study_hub/widgets/streak_badge.dart';
import 'package:study_hub/widgets/study_card.dart';
import 'package:study_hub/widgets/weekly_calendar.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            spacing.screenPadding,
            spacing.lg,
            spacing.screenPadding,
            140,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeaderSection(),
              SizedBox(height: spacing.sectionGap),
              _InsightsCard(),
              SizedBox(height: spacing.sectionGap),
              const LumaRecommendationCard(),
              SizedBox(height: spacing.sectionGap),
              _QuickStatsRow(),
              SizedBox(height: spacing.sectionGap),
              _AchievementsPreviewSection(),
              SizedBox(height: spacing.sectionGap),
              _CalendarSection(),
              SizedBox(height: spacing.sectionGap),
              _GoalsSection(),
              SizedBox(height: spacing.sectionGap),
              _EventsSection(),
              SizedBox(height: spacing.sectionGap),
              _QuickActionsSection(),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        AuthSessionProvider? auth;
        try {
          auth = context.watch<AuthSessionProvider>();
        } on ProviderNotFoundException {
          auth = null;
        }
        final userName = auth == null || auth.isSignedIn
            ? auth?.displayName ?? settings.settings.userName
            : null;
        final photoUrl = auth == null || auth.isSignedIn
            ? auth?.photoUrl ?? settings.settings.userPhotoUrl
            : null;
        final firstName = (userName != null && userName.isNotEmpty)
            ? userName.split(' ').first
            : 'Estudante';
        final greeting = switch (DateTime.now().hour) {
          < 12 => 'Bom dia',
          < 18 => 'Boa tarde',
          _ => 'Boa noite',
        };

        return Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(greeting, style: context.theme.textTheme.bodySmall),
                  SizedBox(height: spacing.xs),
                  Text(
                    firstName,
                    style: context.theme.textTheme.headlineMedium,
                  ),
                ],
              ),
            ),
            Consumer<StudyLogProvider>(
              builder: (context, provider, _) {
                return StreakBadge(streakCount: provider.currentStreak);
              },
            ),
            SizedBox(width: spacing.sm),
            _AchievementHeaderButton(),
            SizedBox(width: spacing.sm),
            _Avatar(
              key: ValueKey('home-avatar-${photoUrl ?? 'fallback'}'),
              photoUrl: photoUrl,
              firstName: firstName,
            ),
          ],
        );
      },
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? photoUrl;
  final String firstName;

  const _Avatar({super.key, required this.photoUrl, required this.firstName});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final initial = firstName.isNotEmpty ? firstName[0].toUpperCase() : '?';
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.surface2,
        border: Border.all(color: colors.borderStrong),
      ),
      child: ClipOval(
        child: photoUrl != null && photoUrl!.isNotEmpty
            ? Image.network(
                _cacheAwarePhotoUrl(photoUrl!),
                key: ValueKey('home-avatar-image-$photoUrl'),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _fallback(colors, initial),
              )
            : _fallback(colors, initial),
      ),
    );
  }

  Widget _fallback(AppColorTokens colors, String initial) {
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          color: colors.accent,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      ),
    );
  }

  String _cacheAwarePhotoUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return url;
    final queryParameters = Map<String, String>.from(uri.queryParameters);
    queryParameters['studyhub_avatar'] = url.hashCode.abs().toString();
    return uri.replace(queryParameters: queryParameters).toString();
  }
}

class _AchievementHeaderButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer3<CertificateProvider, StudyLogProvider, GoalProvider>(
      builder: (context, certificates, logs, goals, _) {
        final progress = certificates.progressFor(
          totalStudyMinutes: _totalStudyMinutes(logs),
          currentStreak: logs.currentStreak,
          completedGoals: _completedGoals(goals, logs),
        );

        return Tooltip(
          message: 'Conquistas',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () {
                AppHaptics.selection();
                Navigator.pushNamed(context, AppRoutes.achievements);
              },
              child: AchievementRankBadge(rank: progress.currentRank, size: 52),
            ),
          ),
        );
      },
    );
  }
}

class _InsightsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    return Consumer<StudyLogProvider>(
      builder: (context, logProvider, _) {
        final weekly = logProvider.weeklyStudyMinutes;
        final streak = logProvider.currentStreak;
        final summary = weekly == 0
            ? 'Comece registrando uma sessão para gerar insights.'
            : 'Você estudou ${DateHelpers.formatDuration(weekly)} nesta semana e manteve uma sequência de $streak dia(s).';

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(context.spacing.cardRadius),
            onTap: () {
              context.read<NavigationProvider>().setIndex(1);
            },
            child: AppSurface(
              color: colors.surfaceElevated,
              shadow: context.elevations.medium,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Insights',
                          style: context.theme.textTheme.titleMedium?.copyWith(
                            color: colors.accent,
                          ),
                        ),
                        SizedBox(height: spacing.xs),
                        Text(
                          summary,
                          style: context.theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: spacing.md),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: colors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _QuickStatsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Consumer2<StudyEventProvider, StudyLogProvider>(
      builder: (context, eventProvider, logProvider, _) {
        final date = eventProvider.selectedDate;
        final isToday = DateHelpers.isToday(date);
        final events = eventProvider.getEventsForDate(date);
        final studyMinutes = logProvider.getStudyMinutesForDate(date);

        return Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.calendar_today_rounded,
                label: isToday ? 'Eventos hoje' : 'Eventos',
                value: '${events.length}',
                tone: context.colors.accent,
              ),
            ),
            SizedBox(width: spacing.md),
            Expanded(
              child: _StatCard(
                icon: Icons.timer_rounded,
                label: isToday ? 'Estudado hoje' : 'Estudado',
                value: DateHelpers.formatDuration(studyMinutes),
                tone: context.colors.accentSecondary,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AchievementsPreviewSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Consumer3<CertificateProvider, StudyLogProvider, GoalProvider>(
      builder: (context, certificates, logs, goals, _) {
        final totalMinutes = _totalStudyMinutes(logs);
        final progress = certificates.progressFor(
          totalStudyMinutes: totalMinutes,
          currentStreak: logs.currentStreak,
          completedGoals: _completedGoals(goals, logs),
        );
        final rankAccent = progress.currentRank.accentColor;
        final isEmpty =
            totalMinutes == 0 && certificates.totalCertificates == 0;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(spacing.cardRadius),
            onTap: () {
              AppHaptics.selection();
              Navigator.pushNamed(context, AppRoutes.achievements);
            },
            child: AppSurface(
              color: Color.alphaBlend(
                rankAccent.withValues(alpha: 0.035),
                context.colors.surfaceElevated,
              ),
              shadow: context.elevations.medium,
              border: Border.all(color: rankAccent.withValues(alpha: 0.18)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AchievementRankBadge(rank: progress.currentRank),
                      SizedBox(width: spacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Conquistas',
                              style: context.theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${progress.currentRank.label} • ${certificates.totalCertificates} certificado(s)',
                              style: context.theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: context.colors.textSecondary,
                      ),
                    ],
                  ),
                  if (isEmpty) ...[
                    SizedBox(height: spacing.md),
                    AppSurface.subtle(
                      padding: EdgeInsets.all(spacing.md),
                      child: Row(
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            color: rankAccent,
                            size: 20,
                          ),
                          SizedBox(width: spacing.sm),
                          Expanded(
                            child: Text(
                              'Complete seu primeiro registro e comece a construir sua jornada.',
                              style: context.theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (!isEmpty) ...[
                    SizedBox(height: spacing.md),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress.progressToNext,
                        minHeight: 8,
                        backgroundColor: context.colors.surface2,
                        valueColor: AlwaysStoppedAnimation<Color>(rankAccent),
                      ),
                    ),
                    SizedBox(height: spacing.sm),
                    Row(
                      children: [
                        Icon(
                          Icons.verified_rounded,
                          size: 16,
                          color: context.colors.success,
                        ),
                        SizedBox(width: spacing.xs),
                        Expanded(
                          child: Text(
                            '${certificates.trustedCertificates} link(s) confiaveis',
                            style: context.theme.textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: spacing.xs),
                    Text(
                      progress.nextMilestoneLabel,
                      style: context.theme.textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color tone;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tone, size: 20),
          const SizedBox(height: 12),
          Text(value, style: context.theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(label, style: context.theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _CalendarSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Consumer<StudyEventProvider>(
      builder: (context, provider, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSectionHeader(
              title: 'Agenda',
              subtitle: 'Visualize seus eventos por dia.',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => _showManualDatePicker(context, provider),
                    icon: const Icon(Icons.calendar_month_rounded),
                  ),
                  TextButton(
                    onPressed: () => provider.selectDate(DateTime.now()),
                    child: const Text('Hoje'),
                  ),
                ],
              ),
            ),
            SizedBox(height: spacing.md),
            AppSurface(
              padding: EdgeInsets.all(spacing.md),
              child: WeeklyCalendar(
                selectedDate: provider.selectedDate,
                onDateSelected: provider.selectDate,
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showManualDatePicker(
    BuildContext context,
    StudyEventProvider provider,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: provider.selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      provider.selectDate(picked);
    }
  }
}

class _GoalsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Consumer2<GoalProvider, StudyLogProvider>(
      builder: (context, goalProvider, logProvider, _) {
        final weeklyGoal = goalProvider.activeWeeklyGoal;
        final monthlyGoal = goalProvider.activeMonthlyGoal;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSectionHeader(
              title: 'Metas',
              subtitle: 'Acompanhe a execução das metas ativas.',
              trailing: IconButton(
                onPressed: () => CreateGoalSheet.show(context),
                icon: const Icon(Icons.add_rounded),
              ),
            ),
            SizedBox(height: spacing.md),
            if (weeklyGoal == null && monthlyGoal == null)
              const _EmptyPanel(
                icon: Icons.flag_circle_rounded,
                title: 'Nenhuma meta definida',
                subtitle:
                    'Crie uma meta semanal ou mensal para acompanhar sua consistência.',
              )
            else ...[
              if (weeklyGoal != null)
                GoalCard(
                  goal: weeklyGoal,
                  progress: goalProvider.calculateProgress(
                    weeklyGoal,
                    logProvider.logs,
                  ),
                  studiedMinutes: goalProvider.getStudiedMinutes(
                    weeklyGoal,
                    logProvider.logs,
                  ),
                  onEdit: () => CreateGoalSheet.show(context, goal: weeklyGoal),
                  onDelete: () => _confirmDeleteGoal(context, weeklyGoal),
                ),
              if (monthlyGoal != null) ...[
                SizedBox(height: spacing.md),
                GoalCard(
                  goal: monthlyGoal,
                  progress: goalProvider.calculateProgress(
                    monthlyGoal,
                    logProvider.logs,
                  ),
                  studiedMinutes: goalProvider.getStudiedMinutes(
                    monthlyGoal,
                    logProvider.logs,
                  ),
                  onEdit: () =>
                      CreateGoalSheet.show(context, goal: monthlyGoal),
                  onDelete: () => _confirmDeleteGoal(context, monthlyGoal),
                ),
              ],
            ],
          ],
        );
      },
    );
  }

  Future<void> _confirmDeleteGoal(BuildContext context, StudyGoal goal) async {
    final confirmed = await AppModal.showDialogCard<bool>(
      context: context,
      builder: (dialogContext) {
        return AppSurface(
          color: dialogContext.colors.modalSurface,
          shadow: dialogContext.elevations.high,
          padding: EdgeInsets.all(dialogContext.spacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Excluir meta?',
                style: dialogContext.theme.textTheme.titleLarge,
              ),
              SizedBox(height: dialogContext.spacing.sm),
              Text(
                'Esta ação remove a meta ativa do período atual.',
                style: dialogContext.theme.textTheme.bodySmall,
              ),
              SizedBox(height: dialogContext.spacing.xl),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  SizedBox(width: dialogContext.spacing.md),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('Excluir'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (confirmed == true && context.mounted) {
      AppHaptics.warning();
      await context.read<GoalProvider>().deleteGoal(goal.id);
      if (!context.mounted) return;
      AppHaptics.success();
    }
  }
}

class _EventsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Consumer<StudyEventProvider>(
      builder: (context, provider, _) {
        final events = provider.getEventsForDate(provider.selectedDate);
        final title = DateHelpers.isToday(provider.selectedDate)
            ? 'Programado para hoje'
            : 'Eventos do dia ${provider.selectedDate.day}/${provider.selectedDate.month}';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSectionHeader(
              title: title,
              subtitle: '${events.length} evento(s)',
            ),
            SizedBox(height: spacing.md),
            if (events.isEmpty)
              const _EmptyPanel(
                icon: Icons.event_available_rounded,
                title: 'Nenhum evento neste dia',
                subtitle:
                    'Use Agenda para programar uma nova sessão de estudo.',
              )
            else
              ...events.asMap().entries.map(
                (entry) => Padding(
                  padding: EdgeInsets.only(bottom: spacing.sm),
                  child: StudyCard(event: entry.value, index: entry.key),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _QuickActionsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionHeader(
          title: 'Acesso rápido',
          subtitle: 'Ações principais do dia.',
        ),
        SizedBox(height: spacing.md),
        Row(
          children: [
            Expanded(
              child: _QuickActionButton(
                icon: Icons.add_circle_rounded,
                label: 'Evento',
                color: context.colors.accent,
                onTap: () {
                  AppHaptics.selection();
                  context.read<NavigationProvider>().setIndex(2);
                },
              ),
            ),
            SizedBox(width: spacing.sm),
            Expanded(
              child: _QuickActionButton(
                icon: Icons.edit_note_rounded,
                label: 'Registrar',
                color: context.colors.accentSecondary,
                onTap: () {
                  AppHaptics.selection();
                  context.read<NavigationProvider>().setIndex(3);
                },
              ),
            ),
            SizedBox(width: spacing.sm),
            Expanded(
              child: _QuickActionButton(
                icon: Icons.history_rounded,
                label: 'Histórico',
                color: context.colors.accentTertiary,
                onTap: () {
                  AppHaptics.selection();
                  Navigator.pushNamed(context, AppRoutes.history);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(context.spacing.cardRadius),
        child: AppSurface(
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 10),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.theme.textTheme.labelMedium?.copyWith(
                  color: context.colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyPanel({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      child: Column(
        children: [
          Icon(icon, size: 40, color: context.colors.textDisabled),
          const SizedBox(height: 12),
          Text(title, style: context.theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: context.theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

int _totalStudyMinutes(StudyLogProvider provider) {
  return provider.logs.fold<int>(0, (sum, log) => sum + log.studyTimeMinutes);
}

int _completedGoals(GoalProvider goals, StudyLogProvider logs) {
  return goals.goals.where((goal) {
    return goals.calculateProgress(goal, logs.logs) >= 1;
  }).length;
}
