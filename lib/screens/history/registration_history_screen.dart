import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:study_hub/config/app_theme.dart';
import 'package:study_hub/models/study_log.dart';
import 'package:study_hub/providers/study_log_provider.dart';
import 'package:study_hub/utils/date_helpers.dart';

/// Full-screen view of all past study registrations.
/// Supports deletion with Notion sync and animated list entries.
class RegistrationHistoryScreen extends StatefulWidget {
  const RegistrationHistoryScreen({super.key});

  @override
  State<RegistrationHistoryScreen> createState() =>
      _RegistrationHistoryScreenState();
}

class _RegistrationHistoryScreenState extends State<RegistrationHistoryScreen> {
  String _filter = 'all'; // 'all', 'week', 'month'

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico de Registros'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<StudyLogProvider>(
        builder: (context, provider, _) {
          final allLogs = List<StudyLog>.from(provider.logs)
            ..sort((a, b) => b.date.compareTo(a.date));
          final filteredLogs = _applyFilter(allLogs);

          return Column(
            children: [
              // Filter chips
              _buildFilterBar(),

              // Log list
              Expanded(
                child: filteredLogs.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                        itemCount: filteredLogs.length,
                        itemBuilder: (context, index) {
                          return _HistoryLogCard(
                            log: filteredLogs[index],
                            index: index,
                            onDelete: () =>
                                _confirmDelete(context, filteredLogs[index]),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<StudyLog> _applyFilter(List<StudyLog> logs) {
    final now = DateTime.now();

    switch (_filter) {
      case 'week':
        final weekStart = now.subtract(Duration(days: now.weekday % 7));
        final start =
            DateTime(weekStart.year, weekStart.month, weekStart.day);
        return logs.where((l) => l.date.isAfter(start)).toList();
      case 'month':
        final start = DateTime(now.year, now.month, 1);
        return logs.where((l) => l.date.isAfter(start)).toList();
      default:
        return logs;
    }
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Row(
        children: [
          _FilterChip(
            label: 'Todos',
            isSelected: _filter == 'all',
            onTap: () => setState(() => _filter = 'all'),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Esta semana',
            isSelected: _filter == 'week',
            onTap: () => setState(() => _filter = 'week'),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Este mês',
            isSelected: _filter == 'month',
            onTap: () => setState(() => _filter = 'month'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_rounded,
            size: 64,
            color: AppColors.textHint.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'Nenhum registro encontrado',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textHint,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Seus registros de estudo aparecerão aqui',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textHint,
                ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, StudyLog log) async {
    final provider = context.read<StudyLogProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Excluir registro?'),
        content: Text(
          log.notionPageId != null
              ? 'Este registro será removido do app e arquivado no Notion.'
              : 'Este registro será removido permanentemente.',
        ),
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

    if (confirmed == true) {
      if (mounted) {
        await provider.deleteLogWithNotionSync(log.id);
      }
    }
  }
}

/// Individual history log card with animated entry.
class _HistoryLogCard extends StatelessWidget {
  final StudyLog log;
  final int index;
  final VoidCallback onDelete;

  const _HistoryLogCard({
    required this.log,
    required this.index,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // Extract display values from rawValues
    final title = _extractTitle();
    final studyTime = log.studyTimeMinutes;
    final dateStr = DateHelpers.formatShortDate(log.date);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 50).clamp(0, 300)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardGrey),
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
            // Color indicator
            Container(
              width: 4,
              height: 48,
              decoration: BoxDecoration(
                color: log.syncedWithNotion
                    ? AppColors.primaryGreen
                    : AppColors.amber,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 14),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded,
                          size: 12, color: AppColors.textHint),
                      const SizedBox(width: 4),
                      Text(
                        dateStr,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (studyTime > 0) ...[
                        const SizedBox(width: 12),
                        Icon(Icons.timer_rounded,
                            size: 12, color: AppColors.textHint),
                        const SizedBox(width: 4),
                        Text(
                          DateHelpers.formatDuration(studyTime),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Sync badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: log.syncedWithNotion
                    ? AppColors.primaryGreen.withValues(alpha: 0.1)
                    : AppColors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                log.syncedWithNotion
                    ? Icons.cloud_done_rounded
                    : Icons.cloud_off_rounded,
                size: 16,
                color:
                    log.syncedWithNotion ? AppColors.primaryGreen : AppColors.amber,
              ),
            ),

            const SizedBox(width: 8),

            // Delete button
            GestureDetector(
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: AppColors.error,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Extracts a display title from rawValues (first title or rich_text field).
  String _extractTitle() {
    for (final entry in log.schema.properties.entries) {
      if (entry.value.type == 'title') {
        final val = log.rawValues[entry.value.name];
        if (val != null && val.toString().isNotEmpty) return val.toString();
      }
    }
    // Fallback: try select fields
    for (final entry in log.schema.properties.entries) {
      if (entry.value.type == 'select' || entry.value.type == 'multi_select') {
        final val = log.rawValues[entry.value.name];
        if (val != null) {
          if (val is List && val.isNotEmpty) return val.join(', ');
          if (val.toString().isNotEmpty) return val.toString();
        }
      }
    }
    return 'Registro de ${DateHelpers.formatCompactDate(log.date)}';
  }
}

/// Small filter chip widget.
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.purple : AppColors.purple.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.purple,
          ),
        ),
      ),
    );
  }
}
