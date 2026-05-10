import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:study_hub/config/app_theme.dart';
import 'package:study_hub/models/study_event.dart';
import 'package:study_hub/providers/study_event_provider.dart';
import 'package:study_hub/services/app_haptics.dart';
import 'package:study_hub/utils/date_helpers.dart';
import 'package:study_hub/utils/snackbar_helper.dart';
import 'package:study_hub/widgets/app_modal.dart';
import 'package:study_hub/widgets/app_surface.dart';

/// Card de evento de estudo — inspirado na referência visual
/// Card colorido com matéria, título, horário e indicador de sincronização
class StudyCard extends StatefulWidget {
  final StudyEvent event;
  final Color? color;
  final VoidCallback? onTap;
  final int index;

  const StudyCard({
    super.key,
    required this.event,
    this.color,
    this.onTap,
    this.index = 0,
  });

  @override
  State<StudyCard> createState() => _StudyCardState();
}

class _StudyCardState extends State<StudyCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _wiggleController;
  late Animation<double> _wiggleAnimation;

  @override
  void initState() {
    super.initState();
    _wiggleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );

    _wiggleAnimation = Tween<double>(begin: 0.0, end: 0.01).animate(
      CurvedAnimation(parent: _wiggleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _wiggleController.dispose();
    super.dispose();
  }

  Future<void> _showActions() async {
    AppHaptics.selection();
    if (!mounted) return;
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
              _EventActionTile(
                icon: Icons.edit_rounded,
                title: 'Editar evento',
                subtitle: widget.event.syncedWithCalendar
                    ? 'Atualiza os dados locais do app.'
                    : 'Ajuste titulo, descrição, data e horário.',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showEditSheet();
                },
              ),
              SizedBox(height: sheetContext.spacing.xs),
              _EventActionTile(
                icon: Icons.delete_outline_rounded,
                title: 'Excluir evento',
                subtitle: 'Remove do cronograma após confirmação.',
                tone: sheetContext.colors.error,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showDeleteDialog();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showEditSheet() async {
    AppHaptics.selection();
    if (!mounted) return;
    await AppModal.showSheet<void>(
      context: context,
      builder: (_) => _EditEventSheet(event: widget.event),
    );
  }

  void _showDeleteDialog() async {
    // Começa a balançar (loop infinito indo e voltando)
    _wiggleController.repeat(reverse: true);

    final provider = context.read<StudyEventProvider>();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir evento?'),
        content: Text(
          'Deseja remover "${widget.event.title}" do seu cronograma?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    // Para de balançar
    _wiggleController.stop();
    _wiggleController.reset();

    if (confirm == true) {
      await AppHaptics.warning();
      if (mounted) {
        final success = await provider.deleteEvent(widget.event);

        if (!success && mounted) {
          // Sync failure handling
          final forceDelete = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Falha ao sincronizar'),
              content: const Text(
                'Não foi possível excluir no Google Calendar. Deseja remover apenas no app?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Manter'),
                ),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Remover do app'),
                ),
              ],
            ),
          );

          if (forceDelete == true && mounted) {
            AppHaptics.warning();
            provider.removeEvent(widget.event.id);
            SnackbarHelper.showInfo(context, 'Removido apenas do app.');
          }
        } else if (mounted) {
          SnackbarHelper.showSuccess(context, 'Evento excluído com sucesso.');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = widget.color ?? AppColors.getSubjectColor(widget.index);
    final isLightCard = _isLightColor(cardColor);

    return AnimatedBuilder(
      animation: _wiggleAnimation,
      builder: (context, child) {
        return Transform.rotate(angle: _wiggleAnimation.value, child: child);
      },
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: _showActions,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.white.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: cardColor.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Linha superior: Matéria + Menu
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Nome da matéria
                      Text(
                        widget.event.subject,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: cardColor,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      // Ícone de sincronização
                      if (widget.event.syncedWithCalendar)
                        Icon(
                          Icons.cloud_done_rounded,
                          color: isLightCard
                              ? AppColors.textPrimaryLight.withValues(
                                  alpha: 0.6,
                                )
                              : Colors.white.withValues(alpha: 0.8),
                          size: 20,
                        ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // Título do evento
                  Text(
                    widget.event.title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.color?.withValues(alpha: 0.8),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 12),

                  // Linha inferior: Horário + Duração
                  Row(
                    children: [
                      // Ícone de relógio + horário
                      Icon(
                        Icons.access_time_rounded,
                        size: 16,
                        color: isLightCard
                            ? AppColors.textPrimaryLight.withValues(alpha: 0.6)
                            : Colors.white.withValues(alpha: 0.8),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${DateHelpers.formatTime(widget.event.startTime.hour, widget.event.startTime.minute)} - ${DateHelpers.formatTime(widget.event.endTime.hour, widget.event.endTime.minute)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(width: 16),

                      // Duração
                      Icon(
                        Icons.timer_outlined,
                        size: 16,
                        color: isLightCard
                            ? AppColors.textPrimaryLight.withValues(alpha: 0.6)
                            : Colors.white.withValues(alpha: 0.8),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.event.formattedDuration,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Determina se a cor é clara (para ajustar cor do texto)
  bool _isLightColor(Color color) {
    return color.computeLuminance() > 0.5;
  }
}

class _EventActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? tone;
  final VoidCallback onTap;

  const _EventActionTile({
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

class _EditEventSheet extends StatefulWidget {
  final StudyEvent event;

  const _EditEventSheet({required this.event});

  @override
  State<_EditEventSheet> createState() => _EditEventSheetState();
}

class _EditEventSheetState extends State<_EditEventSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late DateTime _date;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late int _reminderMinutes;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.event.title);
    _descriptionController = TextEditingController(
      text: widget.event.description,
    );
    _date = widget.event.date;
    _startTime = widget.event.startTime;
    _endTime = widget.event.endTime;
    _reminderMinutes = widget.event.reminderMinutes;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return AppSurface(
      color: context.colors.modalSurface,
      shadow: context.elevations.high,
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
                    'Editar evento',
                    style: context.theme.textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            if (widget.event.syncedWithCalendar) ...[
              SizedBox(height: spacing.sm),
              Text(
                'Esta edição altera os dados locais do app. O evento sincronizado no Google Calendar será mantido.',
                style: context.theme.textTheme.bodySmall?.copyWith(
                  color: context.colors.warning,
                ),
              ),
            ],
            SizedBox(height: spacing.md),
            TextField(
              controller: _titleController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Titulo do evento',
                prefixIcon: Icon(Icons.title_rounded),
              ),
            ),
            SizedBox(height: spacing.md),
            TextField(
              controller: _descriptionController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Descrição',
                prefixIcon: Icon(Icons.description_rounded),
              ),
            ),
            SizedBox(height: spacing.md),
            _EditEventPicker(
              icon: Icons.calendar_today_rounded,
              label: 'Data',
              value: DateHelpers.formatShortDate(_date),
              onTap: _pickDate,
            ),
            SizedBox(height: spacing.sm),
            Row(
              children: [
                Expanded(
                  child: _EditEventPicker(
                    icon: Icons.play_arrow_rounded,
                    label: 'Inicio',
                    value: DateHelpers.formatTime(
                      _startTime.hour,
                      _startTime.minute,
                    ),
                    onTap: () => _pickTime(isStart: true),
                  ),
                ),
                SizedBox(width: spacing.sm),
                Expanded(
                  child: _EditEventPicker(
                    icon: Icons.stop_rounded,
                    label: 'Fim',
                    value: DateHelpers.formatTime(
                      _endTime.hour,
                      _endTime.minute,
                    ),
                    onTap: () => _pickTime(isStart: false),
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing.md),
            DropdownButtonFormField<int>(
              initialValue: _reminderMinutes,
              decoration: const InputDecoration(
                labelText: 'Lembrete',
                prefixIcon: Icon(Icons.notifications_rounded),
              ),
              items: const [0, 5, 10, 15, 30, 60]
                  .map(
                    (minutes) => DropdownMenuItem<int>(
                      value: minutes,
                      child: Text(
                        minutes == 0 ? 'Sem lembrete' : '$minutes min',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  AppHaptics.selection();
                  setState(() => _reminderMinutes = value);
                }
              },
            ),
            SizedBox(height: spacing.lg),
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(_isSaving ? 'Salvando...' : 'Salvar alterações'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    AppHaptics.selection();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null && mounted) {
      setState(() => _date = picked);
    }
  }

  Future<void> _pickTime({required bool isStart}) async {
    AppHaptics.selection();
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked != null && mounted) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      SnackbarHelper.showWarning(context, 'Informe um titulo para o evento.');
      return;
    }

    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final endMinutes = _endTime.hour * 60 + _endTime.minute;
    if (endMinutes <= startMinutes) {
      SnackbarHelper.showError(
        context,
        'A hora de fim deve ser depois do inicio.',
      );
      return;
    }

    setState(() => _isSaving = true);
    final updated = widget.event.copyWith(
      title: title,
      description: _descriptionController.text.trim(),
      date: _date,
      startTime: _startTime,
      endTime: _endTime,
      reminderMinutes: _reminderMinutes,
    );

    final saved = await context.read<StudyEventProvider>().updateEvent(updated);
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (saved) {
      AppHaptics.success();
      if (!mounted) return;
      Navigator.pop(context);
      SnackbarHelper.showSuccess(context, 'Evento atualizado.');
    } else {
      SnackbarHelper.showError(context, 'Não foi possível atualizar o evento.');
    }
  }
}

class _EditEventPicker extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _EditEventPicker({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(context.spacing.fieldRadius),
        child: Container(
          padding: EdgeInsets.all(context.spacing.md),
          decoration: BoxDecoration(
            color: context.colors.inputFill,
            borderRadius: BorderRadius.circular(context.spacing.fieldRadius),
            border: Border.all(color: context.colors.inputBorder),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: context.colors.textSecondary),
              SizedBox(width: context.spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: context.theme.textTheme.bodySmall),
                    const SizedBox(height: 2),
                    Text(value, style: context.theme.textTheme.labelLarge),
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
