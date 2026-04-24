import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:study_hub/config/app_theme.dart';
import 'package:study_hub/config/app_constants.dart';
import 'package:study_hub/models/study_event.dart';
import 'package:study_hub/providers/study_event_provider.dart';
import 'package:study_hub/providers/settings_provider.dart';
import 'package:study_hub/widgets/custom_text_field.dart';
import 'package:study_hub/widgets/custom_button.dart';
import 'package:study_hub/utils/validators.dart';
import 'package:study_hub/utils/date_helpers.dart';
import 'package:study_hub/utils/snackbar_helper.dart';

/// Tela: Criar Evento de Estudo
/// Formulário completo para agendar uma sessão de estudo
class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controladores dos campos de texto
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Valores selecionados
  String _selectedSubject = AppConstants.defaultSubjects.first;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);
  int _reminderMinutes = 15;
  bool _isSaving = false;

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
        title: const Text('Criar Evento de Estudo'),
        leading: Navigator.canPop(context) 
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 140),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Matéria ──
              _buildSubjectSelector(),

              const SizedBox(height: 20),

              // ── Título ──
              CustomTextField(
                label: 'Título do Evento',
                hint: 'Ex: Estudar Widgets do Flutter',
                prefixIcon: Icons.title_rounded,
                controller: _titleController,
                validator: (v) => Validators.required(v, 'Título'),
              ),

              const SizedBox(height: 20),

              // ── Descrição ──
              CustomTextField(
                label: 'Descrição (opcional)',
                hint: 'Detalhes sobre o que estudar...',
                prefixIcon: Icons.description_rounded,
                controller: _descriptionController,
                maxLines: 3,
              ),

              const SizedBox(height: 20),

              // ── Data ──
              _buildDatePicker(),

              const SizedBox(height: 20),

              // ── Horários ──
              _buildTimePickers(),

              const SizedBox(height: 12),

              // ── Duração calculada ──
              _buildDurationDisplay(),

              const SizedBox(height: 20),

              // ── Lembrete ──
              _buildReminderSelector(),

              const SizedBox(height: 32),

              // ── Botão Salvar ──
              CustomButton(
                label: 'Salvar Evento',
                icon: Icons.save_rounded,
                isLoading: _isSaving,
                onPressed: _saveEvent,
              ),

              const SizedBox(height: 12),

              // ── Botão Salvar no Google Calendar ──
              CustomButton(
                label: 'Salvar no Google Calendar',
                icon: Icons.event_rounded,
                isOutlined: true,
                color: AppColors.coral,
                isLoading: _isSaving,
                onPressed: _saveToGoogleCalendar,
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  /// Seletor de matéria (chips horizontais)
  Widget _buildSubjectSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Matéria',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: AppConstants.defaultSubjects.map((subject) {
            final isSelected = _selectedSubject == subject;
            final index = AppConstants.defaultSubjects.indexOf(subject);
            final color = AppColors.getSubjectColor(index);

            return GestureDetector(
              onTap: () => setState(() => _selectedSubject = subject),
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

  /// Picker de data
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

  /// Pickers de hora início e fim
  Widget _buildTimePickers() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _pickTime(isStart: true),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).dividerTheme.color ?? Colors.transparent,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Início',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.play_arrow_rounded,
                          size: 18, color: AppColors.primaryGreen),
                      const SizedBox(width: 6),
                      Text(
                        DateHelpers.formatTime(
                            _startTime.hour, _startTime.minute),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Icon(Icons.arrow_forward_rounded,
              color: Theme.of(context).textTheme.bodySmall?.color ?? AppColors.textHint, size: 20),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () => _pickTime(isStart: false),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).dividerTheme.color ?? Colors.transparent,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fim',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.stop_rounded,
                          size: 18, color: AppColors.coral),
                      const SizedBox(width: 6),
                      Text(
                        DateHelpers.formatTime(
                            _endTime.hour, _endTime.minute),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Exibe a duração calculada automaticamente
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
                : 'Hora de fim deve ser depois do início',
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

  /// Seletor de lembrete
  Widget _buildReminderSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Lembrete',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        Wrap(
          spacing: 8,
          children: AppConstants.reminderOptions.map((minutes) {
            final isSelected = _reminderMinutes == minutes;
            return GestureDetector(
              onTap: () => setState(() => _reminderMinutes = minutes),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
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
                    color:
                        isSelected ? Colors.white : Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Ações ──

  Future<void> _pickDate() async {
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

  void _saveEvent() {
    if (!_formKey.currentState!.validate()) return;

    final timeError = Validators.timeRange(
      _startTime.hour, _startTime.minute,
      _endTime.hour, _endTime.minute,
    );
    if (timeError != null) {
      SnackbarHelper.showError(context, timeError);
      return;
    }

    final event = StudyEvent(
      subject: _selectedSubject,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      date: _selectedDate,
      startTime: _startTime,
      endTime: _endTime,
      reminderMinutes: _reminderMinutes,
    );

    context.read<StudyEventProvider>().addEvent(event);
    SnackbarHelper.showSuccess(context, 'Evento criado com sucesso! 🎉');
    
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      _titleController.clear();
      _descriptionController.clear();
      setState(() {
        _selectedSubject = AppConstants.defaultSubjects.first;
        _selectedDate = DateTime.now();
      });
      _formKey.currentState?.reset();
    }
  }

  Future<void> _saveToGoogleCalendar() async {
    if (!_formKey.currentState!.validate()) return;

    final timeError = Validators.timeRange(
      _startTime.hour, _startTime.minute,
      _endTime.hour, _endTime.minute,
    );
    if (timeError != null) {
      SnackbarHelper.showError(context, timeError);
      return;
    }

    final isConnected = context.read<SettingsProvider>().isGoogleConnected;
    if (!isConnected) {
      SnackbarHelper.showWarning(
          context, 'Você precisa logar no Google (vá em Configurações)');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final event = StudyEvent(
        subject: _selectedSubject,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        date: _selectedDate,
        startTime: _startTime,
        endTime: _endTime,
        reminderMinutes: _reminderMinutes,
      );

      // CRITICAL FIX: Only call the provider.
      // The provider/repository logic now handles the Google Calendar sync.
      await context.read<StudyEventProvider>().addEvent(event);

      if (mounted) {
        SnackbarHelper.showSuccess(context, 'Evento salvo e sincronizado com sucesso! 🗓️');
        
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          _titleController.clear();
          _descriptionController.clear();
          setState(() {
            _selectedSubject = AppConstants.defaultSubjects.first;
            _selectedDate = DateTime.now();
          });
          _formKey.currentState?.reset();
        }
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Erro ao criar evento: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
