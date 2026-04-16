import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:study_hub/config/app_theme.dart';
import 'package:study_hub/config/app_routes.dart';
import 'package:study_hub/providers/study_event_provider.dart';
import 'package:study_hub/providers/study_log_provider.dart';
import 'package:study_hub/utils/date_helpers.dart';
import 'package:study_hub/widgets/weekly_calendar.dart';
import 'package:study_hub/widgets/study_card.dart';

/// Tela Inicial — Resumo do dia com calendário semanal e eventos
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
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

  /// Header com saudação personalizada
  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${DateHelpers.getGreeting()} 👋',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Victor',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
        // Avatar / ícone de perfil
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.primaryGreen.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.person_rounded,
            color: AppColors.primaryGreen,
            size: 28,
          ),
        ),
      ],
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
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.cardGrey,
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
                            color: AppColors.textHint,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Toque no botão + para criar um evento',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textHint,
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
                label: 'Criar Evento',
                color: AppColors.primaryGreen,
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.createEvent),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionButton(
                icon: Icons.edit_note_rounded,
                label: 'Registrar',
                color: AppColors.purple,
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.studyLog),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Card de estatística individual
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardGrey, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: AppColors.textHint,
            ),
          ],
        ),
      ),
    );
  }
}
