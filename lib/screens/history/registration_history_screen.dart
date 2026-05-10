import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:study_hub/config/app_theme.dart';
import 'package:study_hub/models/study_log.dart';
import 'package:study_hub/providers/study_log_provider.dart';
import 'package:study_hub/services/app_haptics.dart';
import 'package:study_hub/utils/date_helpers.dart';
import 'package:study_hub/utils/snackbar_helper.dart';
import 'package:study_hub/widgets/app_modal.dart';
import 'package:study_hub/widgets/app_surface.dart';

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
                            onEditNote: () =>
                                _editNote(context, filteredLogs[index]),
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
        final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
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
            'Nenhum registro encontrado.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppColors.textHint),
          ),
          const SizedBox(height: 4),
          Text(
            'Seus registros de estudo aparecerão aqui.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textHint),
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
      await AppHaptics.warning();
      if (mounted) {
        await provider.deleteLogWithNotionSync(log.id);
      }
    }
  }

  Future<void> _editNote(BuildContext context, StudyLog log) async {
    AppHaptics.selection();
    if (!mounted) return;

    final subjectController = TextEditingController(
      text: log.localNote?.subject ?? '',
    );
    final contentController = TextEditingController(
      text: log.localNote?.contentName ?? '',
    );
    final summaryController = TextEditingController(
      text: log.localNote?.summary ?? '',
    );

    try {
      await AppModal.showSheet<void>(
        context: context,
        builder: (sheetContext) {
          final spacing = sheetContext.spacing;
          return AppSurface(
            color: sheetContext.colors.modalSurface,
            shadow: sheetContext.elevations.high,
            padding: EdgeInsets.all(spacing.lg),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Editar notas',
                          style: sheetContext.theme.textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  SizedBox(height: spacing.md),
                  TextField(
                    controller: subjectController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Assunto',
                      prefixIcon: Icon(Icons.bookmark_outline_rounded),
                    ),
                  ),
                  SizedBox(height: spacing.md),
                  TextField(
                    controller: contentController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Conteudo estudado',
                      prefixIcon: Icon(Icons.menu_book_rounded),
                    ),
                  ),
                  SizedBox(height: spacing.md),
                  TextField(
                    controller: summaryController,
                    minLines: 5,
                    maxLines: 10,
                    keyboardType: TextInputType.multiline,
                    decoration: const InputDecoration(
                      alignLabelWithHint: true,
                      labelText: 'Notas',
                      prefixIcon: Padding(
                        padding: EdgeInsets.only(bottom: 88),
                        child: Icon(Icons.notes_rounded),
                      ),
                    ),
                  ),
                  SizedBox(height: spacing.lg),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final note = StudyLogNote(
                        subject: subjectController.text.trim(),
                        contentName: contentController.text.trim(),
                        summary: summaryController.text.trim(),
                      );
                      final updatedLog = StudyLog(
                        id: log.id,
                        rawValues: Map<String, dynamic>.from(log.rawValues),
                        syncedWithNotion: log.syncedWithNotion,
                        notionPageId: log.notionPageId,
                        schema: log.schema,
                        date: log.date,
                        localNote: note.isNotEmpty ? note : null,
                      );
                      await sheetContext.read<StudyLogProvider>().updateLog(
                        updatedLog,
                      );
                      await AppHaptics.success();
                      if (sheetContext.mounted) {
                        Navigator.pop(sheetContext);
                        SnackbarHelper.showSuccess(
                          sheetContext,
                          'Notas atualizadas.',
                        );
                      }
                    },
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Salvar notas'),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } finally {
      subjectController.dispose();
      contentController.dispose();
      summaryController.dispose();
    }
  }
}

/// Individual history log card with animated entry.
class _HistoryLogCard extends StatelessWidget {
  final StudyLog log;
  final int index;
  final VoidCallback onEditNote;
  final VoidCallback onDelete;

  const _HistoryLogCard({
    required this.log,
    required this.index,
    required this.onEditNote,
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
      child: GestureDetector(
        onLongPress: () => _showActions(context),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Theme.of(context).dividerTheme.color ?? AppColors.cardGrey,
            ),
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
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 12,
                          color: AppColors.textHint,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          dateStr,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (studyTime > 0) ...[
                          const SizedBox(width: 12),
                          Icon(
                            Icons.timer_rounded,
                            size: 12,
                            color: AppColors.textHint,
                          ),
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
              if (log.localNote?.isNotEmpty == true) ...[
                GestureDetector(
                  onTap: () {
                    AppHaptics.selection();
                    _showLocalNote(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.edit_note_rounded,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],

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
                  color: log.syncedWithNotion
                      ? AppColors.primaryGreen
                      : AppColors.amber,
                ),
              ),

              const SizedBox(width: 8),

              // Delete button
              GestureDetector(
                onTap: () {
                  AppHaptics.selection();
                  onDelete();
                },
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
      ),
    );
  }

  Future<void> _showActions(BuildContext context) async {
    await AppHaptics.selection();
    if (!context.mounted) return;
    await AppModal.showSheet<void>(
      context: context,
      builder: (sheetContext) {
        return AppSurface(
          color: sheetContext.colors.modalSurface,
          shadow: sheetContext.elevations.high,
          padding: EdgeInsets.all(sheetContext.spacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (log.localNote?.isNotEmpty == true)
                _HistoryActionTile(
                  icon: Icons.visibility_rounded,
                  title: 'Ver notas',
                  subtitle: 'Abre as notas salvas neste registro.',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showLocalNote(context);
                  },
                ),
              _HistoryActionTile(
                icon: Icons.edit_note_rounded,
                title: 'Editar notas',
                subtitle: 'Atualiza apenas as notas locais do registro.',
                onTap: () {
                  Navigator.pop(sheetContext);
                  onEditNote();
                },
              ),
              _HistoryActionTile(
                icon: Icons.delete_outline_rounded,
                title: 'Excluir registro',
                subtitle: 'Remove do app após confirmação.',
                tone: sheetContext.colors.error,
                onTap: () {
                  Navigator.pop(sheetContext);
                  onDelete();
                },
              ),
            ],
          ),
        );
      },
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

  Future<void> _showLocalNote(BuildContext context) async {
    final note = log.localNote;
    if (note == null || note.isEmpty) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        final spacing = modalContext.spacing;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            spacing.md,
            spacing.md,
            spacing.md,
            spacing.md + MediaQuery.of(modalContext).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: modalContext.colors.modalSurface,
              borderRadius: BorderRadius.circular(spacing.cardRadius),
              boxShadow: modalContext.elevations.high,
            ),
            padding: EdgeInsets.all(spacing.lg),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.edit_note_rounded,
                        color: modalContext.colors.accent,
                      ),
                      SizedBox(width: spacing.sm),
                      Expanded(
                        child: Text(
                          'Notas do registro',
                          style: modalContext.theme.textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(modalContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  SizedBox(height: spacing.md),
                  if (note.subject.trim().isNotEmpty)
                    _NoteDetail(label: 'Assunto', value: note.subject),
                  if (note.contentName.trim().isNotEmpty)
                    _NoteDetail(
                      label: 'Conteudo estudado',
                      value: note.contentName,
                    ),
                  if (note.summary.trim().isNotEmpty)
                    _NoteDetail(label: 'Notas', value: note.summary),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NoteDetail extends StatelessWidget {
  final String label;
  final String value;

  const _NoteDetail({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _HistoryActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? tone;
  final VoidCallback onTap;

  const _HistoryActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.tone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = tone ?? context.colors.accent;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(context.spacing.fieldRadius),
        child: Padding(
          padding: EdgeInsets.all(context.spacing.sm),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              SizedBox(width: context.spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(subtitle, style: context.theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
          color: isSelected
              ? AppColors.purple
              : Theme.of(context).colorScheme.surfaceContainerLow,
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
