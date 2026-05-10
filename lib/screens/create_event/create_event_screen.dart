import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:study_hub/config/app_routes.dart';
import 'package:study_hub/config/app_constants.dart';
import 'package:study_hub/config/app_theme.dart';
import 'package:study_hub/models/study_event.dart';
import 'package:study_hub/providers/settings_provider.dart';
import 'package:study_hub/providers/study_event_provider.dart';
import 'package:study_hub/providers/study_log_provider.dart';
import 'package:study_hub/repositories/subject_repository.dart';
import 'package:study_hub/services/app_haptics.dart';
import 'package:study_hub/utils/date_helpers.dart';
import 'package:study_hub/utils/snackbar_helper.dart';
import 'package:study_hub/utils/validators.dart';
import 'package:study_hub/widgets/app_modal.dart';
import 'package:study_hub/widgets/custom_button.dart';
import 'package:study_hub/widgets/custom_text_field.dart';
import 'package:study_hub/widgets/full_screen_success_overlay.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  static const SubjectRepository _subjectRepository = SubjectRepository();
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedSubject = AppConstants.defaultSubjects.first;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);
  int _reminderMinutes = 15;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Criar evento de estudo'),
        backgroundColor: Colors.transparent,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Positioned(
            top: -50,
            right: -50,
            child: _BlurGlow(
              color: AppColors.primaryGreen.withValues(alpha: 0.1),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -50,
            child: _BlurGlow(color: AppColors.coral.withValues(alpha: 0.1)),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: 140,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSubjectSelector(),
                    const SizedBox(height: 24),
                    CustomTextField(
                      label: 'Título do evento',
                      hint: 'Ex: Estudar Widgets do Flutter',
                      prefixIcon: Icons.title_rounded,
                      controller: _titleController,
                      validator: (v) => Validators.required(v, 'Título'),
                    ),
                    const SizedBox(height: 24),
                    CustomTextField(
                      label: 'Descrição (opcional)',
                      hint: 'Detalhes sobre o que estudar...',
                      prefixIcon: Icons.description_rounded,
                      controller: _descriptionController,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),
                    _buildDatePicker(),
                    const SizedBox(height: 24),
                    _buildTimePickers(),
                    const SizedBox(height: 16),
                    _buildDurationDisplay(),
                    const SizedBox(height: 24),
                    _buildNotificationSwitch(),
                    const SizedBox(height: 32),
                    CustomButton(
                      label: 'Salvar evento',
                      icon: Icons.check_circle_rounded,
                      isLoading: _isLoading,
                      onPressed: _saveEvent,
                    ),
                    const SizedBox(height: 16),
                    CustomButton(
                      label: 'Salvar no Google Calendar',
                      icon: Icons.event_rounded,
                      isOutlined: true,
                      color: AppColors.coral,
                      isLoading: _isLoading,
                      onPressed: _saveToGoogleCalendar,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectSelector() {
    final settingsProvider = context.watch<SettingsProvider>();
    final logProvider = context.watch<StudyLogProvider>();
    final settings = settingsProvider.settings;

    final categories = _subjectRepository.getSubjects(
      settings: settings,
      schema: logProvider.cachedSchema,
    );

    if (categories.isNotEmpty && !categories.contains(_selectedSubject)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _selectedSubject = categories.first);
        }
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'Matéria',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            TextButton.icon(
              onPressed: _showManageCategoriesDialog,
              icon: const Icon(Icons.settings_rounded, size: 16),
              label: const Text('Matérias', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: categories.map((subject) {
            final isSelected = _selectedSubject == subject;
            final index = categories.indexOf(subject);
            final color = AppColors.getSubjectColor(index);

            return GestureDetector(
              onTap: () {
                AppHaptics.selection();
                setState(() => _selectedSubject = subject);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? color : color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? color : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  subject,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : color,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDatePicker() {
    return GestureDetector(
      onTap: _pickDate,
      child: AbsorbPointer(
        child: CustomTextField(
          label: 'Data',
          hint: DateHelpers.formatShortDate(_selectedDate),
          prefixIcon: Icons.calendar_today_rounded,
          readOnly: true,
          onTap: _pickDate,
        ),
      ),
    );
  }

  Widget _buildTimePickers() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _pickTime(isStart: true),
            child: _TimeCard(
              label: 'Início',
              icon: Icons.play_arrow_rounded,
              iconColor: AppColors.primaryGreen,
              time: DateHelpers.formatTime(_startTime.hour, _startTime.minute),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Icon(
            Icons.arrow_forward_rounded,
            color:
                Theme.of(context).textTheme.bodySmall?.color ??
                AppColors.textHint,
            size: 20,
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () => _pickTime(isStart: false),
            child: _TimeCard(
              label: 'Fim',
              icon: Icons.stop_rounded,
              iconColor: AppColors.coral,
              time: DateHelpers.formatTime(_endTime.hour, _endTime.minute),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDurationDisplay() {
    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final endMinutes = _endTime.hour * 60 + _endTime.minute;
    final duration = endMinutes - startMinutes;
    final isValid = duration > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isValid
            ? AppColors.primaryGreen.withValues(alpha: 0.08)
            : AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            Icons.timer_rounded,
            size: 18,
            color: isValid ? AppColors.primaryGreen : AppColors.error,
          ),
          const SizedBox(width: 8),
          Text(
            isValid
                ? 'Duração: ${DateHelpers.formatDuration(duration)}'
                : 'A hora de fim deve ser depois do início.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isValid ? AppColors.primaryGreen : AppColors.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationSwitch() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Notificação',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).dividerTheme.color ?? AppColors.cardGrey,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.notifications_active_rounded,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lembrete antes do início',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Escolha com quantos minutos de antecedência salvar o lembrete.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildReminderSelector(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReminderSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: AppConstants.reminderOptions.map((minutes) {
        final isSelected = _reminderMinutes == minutes;
        return GestureDetector(
          onTap: () {
            AppHaptics.selection();
            setState(() => _reminderMinutes = minutes);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primaryGreen
                  : Theme.of(context).dividerTheme.color ?? AppColors.cardGrey,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${minutes}min',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _showManageCategoriesDialog() {
    AppHaptics.selection();
    AppModal.showSheet(
      context: context,
      builder: (context) => const _ManageCategoriesSheet(),
    );
  }

  Future<void> _pickDate() async {
    AppHaptics.selection();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime({required bool isStart}) async {
    AppHaptics.selection();
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _saveEvent() async {
    if (_isLoading || !_formKey.currentState!.validate()) {
      return;
    }

    final timeError = Validators.timeRange(
      _startTime.hour,
      _startTime.minute,
      _endTime.hour,
      _endTime.minute,
    );
    if (timeError != null) {
      SnackbarHelper.showError(context, timeError);
      return;
    }

    final event = _buildEvent();
    setState(() => _isLoading = true);

    try {
      final saved = await context.read<StudyEventProvider>().addEvent(event);
      if (!mounted) {
        return;
      }
      if (!saved) {
        SnackbarHelper.showError(context, 'Erro ao criar evento.');
        return;
      }
      await _showEventSuccessAndFinish();
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Erro ao criar evento: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveToGoogleCalendar() async {
    if (_isLoading || !_formKey.currentState!.validate()) {
      return;
    }

    final timeError = Validators.timeRange(
      _startTime.hour,
      _startTime.minute,
      _endTime.hour,
      _endTime.minute,
    );
    if (timeError != null) {
      SnackbarHelper.showError(context, timeError);
      return;
    }

    if (!context.read<SettingsProvider>().isGoogleConnected) {
      SnackbarHelper.showWarning(
        context,
        'Você precisa entrar com o Google nas configurações.',
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final saved = await context.read<StudyEventProvider>().addEvent(
        _buildEvent(),
      );
      if (!mounted) {
        return;
      }
      if (!saved) {
        SnackbarHelper.showError(context, 'Erro ao criar evento.');
        return;
      }
      await _showEventSuccessAndFinish();
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Erro ao criar evento: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  StudyEvent _buildEvent() {
    return StudyEvent(
      subject: _selectedSubject,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      date: _selectedDate,
      startTime: _startTime,
      endTime: _endTime,
      reminderMinutes: _reminderMinutes,
    );
  }

  void _finishSuccessFlow() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
      return;
    }

    _titleController.clear();
    _descriptionController.clear();
    setState(() {
      _selectedSubject = AppConstants.defaultSubjects.first;
      _selectedDate = DateTime.now();
      _startTime = const TimeOfDay(hour: 9, minute: 0);
      _endTime = const TimeOfDay(hour: 10, minute: 0);
      _reminderMinutes = 15;
    });
    _formKey.currentState?.reset();
  }

  Future<void> _showEventSuccessAndFinish() async {
    await FullScreenSuccessOverlay.show(context, message: 'Evento concluído');
    if (!mounted) return;
    _finishSuccessFlow();
  }
}

class _TimeCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color iconColor;
  final String time;

  const _TimeCard({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerTheme.color ?? Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 6),
              Text(time, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ],
      ),
    );
  }
}

class _BlurGlow extends StatelessWidget {
  final Color color;

  const _BlurGlow({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      height: 300,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color, blurRadius: 100, spreadRadius: 50)],
      ),
    );
  }
}

class _ManageCategoriesSheet extends StatefulWidget {
  const _ManageCategoriesSheet();

  @override
  State<_ManageCategoriesSheet> createState() => _ManageCategoriesSheetState();
}

class _ManageCategoriesSheetState extends State<_ManageCategoriesSheet> {
  static const SubjectRepository _subjectRepository = SubjectRepository();
  final _categoryController = TextEditingController();

  @override
  void dispose() {
    _categoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final logProvider = context.watch<StudyLogProvider>();
    final settings = settingsProvider.settings;
    final hasValidNotionDatabase =
        settings.isNotionConnected &&
        settings.notionDatabaseId != null &&
        settings.notionDatabaseId!.isNotEmpty;
    final schema = hasValidNotionDatabase ? logProvider.cachedSchema : null;

    final selectProperties = _subjectRepository.getSelectableSubjectFields(
      schema,
    );
    final subjects = _subjectRepository.getSubjects(
      settings: settings,
      schema: schema,
    );
    final usesNotionSubjects = _subjectRepository.isUsingNotionSubjects(
      settings: settings,
      schema: schema,
    );

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Gerenciar matérias',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.purple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text(
                    'Vincular ao Notion',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Usa a mesma origem de matérias aplicada em metas e eventos.',
                  ),
                  value: settings.linkCategoriesToNotion,
                  activeThumbColor: AppColors.purple,
                  onChanged: settingsProvider.setLinkCategoriesToNotion,
                  contentPadding: EdgeInsets.zero,
                ),
                if (settings.linkCategoriesToNotion) ...[
                  const Divider(),
                  if (!hasValidNotionDatabase)
                    _NotionSubjectSetupState(
                      onSelectTable: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, AppRoutes.settings);
                      },
                    )
                  else if (schema == null)
                    _NotionSubjectSchemaState(
                      isLoading: logProvider.isLoading,
                      onSync: () async {
                        final success = await context
                            .read<StudyLogProvider>()
                            .syncSchemaFromNotion();
                        if (!context.mounted) return;
                        if (!success) {
                          SnackbarHelper.showError(
                            context,
                            'Não foi possível carregar as colunas do Notion.',
                          );
                        }
                      },
                    )
                  else if (selectProperties.isEmpty)
                    const _NotionSubjectEmptyColumnsState()
                  else
                    DropdownButtonFormField<String>(
                      initialValue:
                          selectProperties.contains(
                            settings.notionCategoryField,
                          )
                          ? settings.notionCategoryField
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Coluna de matéria',
                        border: OutlineInputBorder(),
                      ),
                      items: selectProperties
                          .map(
                            (prop) => DropdownMenuItem<String>(
                              value: prop,
                              child: Text(prop),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          settingsProvider.setNotionCategoryField(value);
                        }
                      },
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (usesNotionSubjects) ...[
            Text(
              'Matérias do Notion',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: subjects
                  .map(
                    (subject) => ActionChip(
                      label: Text(
                        subject,
                        style: const TextStyle(fontSize: 12),
                      ),
                      avatar: const Icon(Icons.lock_outline_rounded, size: 16),
                      onPressed: () => SnackbarHelper.showWarning(
                        context,
                        'Esta matéria vem do Notion e só pode ser alterada na tabela vinculada.',
                      ),
                      backgroundColor: AppColors.purple.withValues(alpha: 0.1),
                    ),
                  )
                  .toList(),
            ),
          ] else if (!settings.linkCategoriesToNotion) ...[
            Text(
              'Matérias locais',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: subjects
                  .map(
                    (cat) => Chip(
                      label: Text(cat, style: const TextStyle(fontSize: 12)),
                      onDeleted: () => _confirmDeleteCategory(cat),
                      deleteIcon: const Icon(Icons.cancel_rounded, size: 16),
                      backgroundColor: AppColors.primaryGreen.withValues(
                        alpha: 0.1,
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _categoryController,
                    decoration: const InputDecoration(
                      hintText: 'Nova matéria...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: () {
                    final value = _categoryController.text.trim();
                    if (value.isNotEmpty) {
                      AppHaptics.success();
                      settingsProvider.addCustomCategory(value);
                      _categoryController.clear();
                    }
                  },
                  icon: const Icon(Icons.add_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                  ),
                ),
              ],
            ),
          ] else ...[
            Text(
              'As matérias serão carregadas da coluna vinculada no Notion.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteCategory(String category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir matéria?'),
        content: const Text(
          'Essa matéria será removida das listas locais do aplicativo. Essa ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      AppHaptics.warning();
      await context.read<SettingsProvider>().removeLocalCategory(category);
      if (mounted) {
        SnackbarHelper.showSuccess(context, 'Matéria excluída.');
      }
    }
  }
}

class _NotionSubjectSetupState extends StatelessWidget {
  final VoidCallback onSelectTable;

  const _NotionSubjectSetupState({required this.onSelectTable});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selecione uma tabela do Notion',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Para sincronizar matérias, primeiro vincule ou selecione uma tabela do Notion. Depois disso, o aplicativo poderá carregar as colunas disponíveis.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onSelectTable,
            icon: const Icon(Icons.storage_rounded),
            label: const Text('Selecionar tabela'),
          ),
        ],
      ),
    );
  }
}

class _NotionSubjectSchemaState extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onSync;

  const _NotionSubjectSchemaState({
    required this.isLoading,
    required this.onSync,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Carregue as colunas da tabela',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'A tabela do Notion está vinculada, mas as colunas ainda não foram carregadas neste dispositivo.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: isLoading ? null : onSync,
            icon: isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded),
            label: Text(isLoading ? 'Carregando...' : 'Carregar colunas'),
          ),
        ],
      ),
    );
  }
}

class _NotionSubjectEmptyColumnsState extends StatelessWidget {
  const _NotionSubjectEmptyColumnsState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        'Nenhuma coluna Select ou Multi-select foi encontrada na tabela vinculada.',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: context.colors.error),
      ),
    );
  }
}
