import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:study_hub/config/app_theme.dart';
import 'package:study_hub/config/app_routes.dart';
import 'package:study_hub/providers/study_event_provider.dart';
import 'package:study_hub/providers/study_log_provider.dart';
import 'package:study_hub/providers/settings_provider.dart';
import 'package:study_hub/providers/goal_provider.dart';
import 'package:study_hub/utils/date_helpers.dart';
import 'package:study_hub/widgets/weekly_calendar.dart';
import 'package:study_hub/widgets/study_card.dart';
import 'package:study_hub/widgets/goal_card.dart';
import 'package:study_hub/widgets/streak_badge.dart';
import 'package:study_hub/screens/home/create_goal_sheet.dart';

/// Tela Inicial — Resumo do dia com calendário semanal e eventos
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(left: 20, right: 20, bottom: 140),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // ── Header: saudação + data ──
              _buildHeader(context),

              const SizedBox(height: 24),

              // ── Resumo rápido (cards de estatísticas) ──
              _buildQuickStats(context),

              const SizedBox(height: 24),

              // ── Calendário semanal ──
              _buildCalendarSection(context),

              const SizedBox(height: 24),

              // ── Metas ──
              _buildGoalsSection(context),

              const SizedBox(height: 24),

              // ── Lista de eventos do dia ──
              _buildEventsSection(context),

              const SizedBox(height: 24),

              // ── Botões de acesso rápido ──
              _buildQuickActions(context),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  /// Header com saudação personalizada e foto do usuário
  Widget _buildHeader(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        final userName = settings.settings.userName;
        final photoUrl = settings.settings.userPhotoUrl;
        
        // Extrai apenas o primeiro nome
        final firstName = (userName != null && userName.isNotEmpty)
            ? userName.split(' ')[0]
            : 'Estudante';

        // Define a saudação baseada na hora do dia
        final hour = DateTime.now().hour;
        String greeting;
        if (hour < 12) {
          greeting = 'Bom dia';
        } else if (hour < 18) {
          greeting = 'Boa tarde';
        } else {
          greeting = 'Boa noite';
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting 👋',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  firstName,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ],
            ),
            Row(
              children: [
                // Streak Badge
                Consumer<StudyLogProvider>(
                  builder: (context, logProvider, _) {
                    return StreakBadge(streakCount: logProvider.currentStreak);
                  },
                ),
                const SizedBox(width: 12),
                // Avatar dinâmico
                Container(
                  width: 52,
                  height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primaryGreen.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: (photoUrl != null && photoUrl.isNotEmpty)
                    ? Image.network(
                        photoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildFallbackAvatar(firstName),
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.primaryGreen),
                              ),
                            ),
                          );
                        },
                      )
                    : _buildFallbackAvatar(firstName),
              ),
            ),
            ],
          ),
          ],
        );
      },
    );
  }

  /// Avatar de fallback com iniciais ou ícone padrão
  Widget _buildFallbackAvatar(String name) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      color: AppColors.primaryGreen.withValues(alpha: 0.15),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: AppColors.primaryGreen,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStats(BuildContext context) {
    return Consumer2<StudyEventProvider, StudyLogProvider>(
      builder: (context, eventProvider, logProvider, _) {
        final date = eventProvider.selectedDate;
        final isToday = DateHelpers.isToday(date);
        
        final events = eventProvider.getEventsForDate(date);
        final logsCount = logProvider.getLogsForDate(date).length;
        final studyMins = logProvider.getStudyMinutesForDate(date);

        return Row(
          children: [
            // Eventos
            Expanded(
              child: _StatCard(
                icon: Icons.calendar_today_rounded,
                label: isToday ? 'Eventos hoje' : 'Eventos',
                value: '${events.length}',
                color: AppColors.primaryGreen,
                onTap: () {
                  // Pode rolar a página até a lista de eventos
                },
              ),
            ),
            const SizedBox(width: 12),
            // Tempo estudado
            Expanded(
              child: _StatCard(
                icon: Icons.timer_rounded,
                label: isToday ? 'Estudado hoje' : 'Estudado',
                value: DateHelpers.formatDuration(studyMins),
                color: AppColors.purple,
              ),
            ),
            const SizedBox(width: 12),
            // Registros
            Expanded(
              child: _StatCard(
                icon: Icons.edit_note_rounded,
                label: isToday ? 'Registros' : 'Registros',
                value: '$logsCount',
                color: AppColors.coral,
                onTap: () => Navigator.pushNamed(context, AppRoutes.history),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Seção do calendário semanal
  Widget _buildCalendarSection(BuildContext context) {
    return Consumer<StudyEventProvider>(
      builder: (context, provider, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sua Agenda',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Row(
                  children: [
                    // Botão Selecionar Data
                    IconButton(
                      icon: const Icon(
                        Icons.calendar_month_rounded,
                        color: AppColors.coral,
                        size: 24,
                      ),
                      onPressed: () => _showManualDatePicker(context, provider),
                    ),
                    const SizedBox(width: 4),
                    // Botão "Hoje"
                    GestureDetector(
                      onTap: () => provider.selectDate(DateTime.now()),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.coral.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Hoje',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.coral,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            WeeklyCalendar(
              selectedDate: provider.selectedDate,
              onDateSelected: (date) => provider.selectDate(date),
            ),
          ],
        );
      },
    );
  }

  /// Abre o seletor de data manual
  Future<void> _showManualDatePicker(
      BuildContext context, StudyEventProvider provider) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: provider.selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: 'Selecionar Data',
      cancelText: 'Cancelar',
      confirmText: 'Selecionar',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.coral,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      provider.selectDate(picked);
    }
  }

  /// Lista de eventos do dia selecionado
  Widget _buildEventsSection(BuildContext context) {
    return Consumer<StudyEventProvider>(
      builder: (context, provider, _) {
        final events = provider.getEventsForDate(provider.selectedDate);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateHelpers.isToday(provider.selectedDate)
                      ? 'Programado para hoje'
                      : 'Eventos do dia ${provider.selectedDate.day}/${provider.selectedDate.month}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  '${events.length} evento${events.length != 1 ? 's' : ''}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (events.isEmpty)
              // Estado vazio
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).dividerTheme.color ?? AppColors.cardGrey,
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.event_available_rounded,
                      size: 48,
                      color: AppColors.textHint.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Nenhum evento neste dia',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Toque no botão + para criar um evento',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.8),
                          ),
                    ),
                  ],
                ),
              )
            else
              // Lista de eventos
              ...events.asMap().entries.map((entry) {
                return StudyCard(
                  event: entry.value,
                  index: entry.key,
                );
              }),
          ],
        );
      },
    );
  }

  /// Botões de acesso rápido
  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Acesso Rápido',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _QuickActionButton(
                icon: Icons.add_circle_rounded,
                label: 'Evento',
                color: AppColors.primaryGreen,
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.createEvent),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _QuickActionButton(
                icon: Icons.edit_note_rounded,
                label: 'Registrar',
                color: AppColors.purple,
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.studyLog),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _QuickActionButton(
                icon: Icons.history_rounded,
                label: 'Histórico',
                color: AppColors.coral,
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.history),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Seção de Metas (Goals)
  Widget _buildGoalsSection(BuildContext context) {
    return Consumer2<GoalProvider, StudyLogProvider>(
      builder: (context, goalProvider, logProvider, _) {
        final weeklyGoal = goalProvider.activeWeeklyGoal;
        final monthlyGoal = goalProvider.activeMonthlyGoal;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Suas Metas',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  icon: const Icon(
                    Icons.add_circle_rounded,
                    color: AppColors.primaryGreen,
                  ),
                  onPressed: () => CreateGoalSheet.show(context),
                ),
              ],
            ),
            if (weeklyGoal == null && monthlyGoal == null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).dividerTheme.color ?? AppColors.cardGrey),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.flag_circle_rounded,
                      size: 40,
                      color: AppColors.textHint.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Nenhuma meta definida',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                    ),
                    TextButton(
                      onPressed: () => CreateGoalSheet.show(context),
                      child: const Text('Criar Meta'),
                    ),
                  ],
                ),
              )
            else ...[
              if (weeklyGoal != null)
                GoalCard(
                  goal: weeklyGoal,
                  progress: goalProvider.calculateProgress(
                      weeklyGoal, logProvider.logs),
                  studiedMinutes: goalProvider.getStudiedMinutes(
                      weeklyGoal, logProvider.logs),
                  onEdit: () =>
                      CreateGoalSheet.show(context, goal: weeklyGoal),
                  onDelete: () => _confirmDeleteGoal(context, weeklyGoal),
                ),
              if (monthlyGoal != null)
                GoalCard(
                  goal: monthlyGoal,
                  progress: goalProvider.calculateProgress(
                      monthlyGoal, logProvider.logs),
                  studiedMinutes: goalProvider.getStudiedMinutes(
                      monthlyGoal, logProvider.logs),
                  onEdit: () =>
                      CreateGoalSheet.show(context, goal: monthlyGoal),
                  onDelete: () => _confirmDeleteGoal(context, monthlyGoal),
                ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _confirmDeleteGoal(BuildContext context, dynamic goal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Excluir Meta?'),
        content: const Text('Você tem certeza que deseja excluir esta meta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      context.read<GoalProvider>().deleteGoal(goal.id);
    }
  }
}

/// Card de estatística individual
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, color: color, size: 22),
                  if (onTap != null)
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 10,
                      color: color.withValues(alpha: 0.5),
                    ),
                ],
              ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color.withValues(alpha: 0.8),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Botão de acesso rápido
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).dividerTheme.color ?? AppColors.cardGrey, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
