import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:study_hub/config/app_theme.dart';
import 'package:study_hub/config/app_constants.dart';
import 'package:study_hub/models/study_goal.dart';
import 'package:study_hub/providers/goal_provider.dart';
import 'package:study_hub/providers/study_log_provider.dart';
import 'package:study_hub/widgets/custom_button.dart';
import 'package:study_hub/widgets/custom_text_field.dart';
import 'package:study_hub/utils/snackbar_helper.dart';

/// Bottom sheet for creating or editing a study goal.
class CreateGoalSheet extends StatefulWidget {
  final StudyGoal? existingGoal;

  const CreateGoalSheet({super.key, this.existingGoal});

  static Future<void> show(BuildContext context, {StudyGoal? goal}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateGoalSheet(existingGoal: goal),
    );
  }

  @override
  State<CreateGoalSheet> createState() => _CreateGoalSheetState();
}

class _CreateGoalSheetState extends State<CreateGoalSheet> {
  late GoalType _type;
  late int _targetMinutes;
  List<String> _selectedLanguages = [];
  List<String> _availableLanguages = [];

  final _minutesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAvailableLanguages();

    if (widget.existingGoal != null) {
      _type = widget.existingGoal!.type;
      _targetMinutes = widget.existingGoal!.targetMinutes;
      _selectedLanguages = List.from(widget.existingGoal!.languages);
      _minutesController.text = _targetMinutes.toString();
    } else {
      _type = GoalType.weekly;
      _targetMinutes = 120; // Default 2 hours
      _minutesController.text = '120';
    }
  }

  @override
  void dispose() {
    _minutesController.dispose();
    super.dispose();
  }

  /// Extracts language options from the Notion schema if available,
  /// otherwise falls back to default hardcoded subjects.
  void _loadAvailableLanguages() {
    final logProvider = context.read<StudyLogProvider>();
    final schema = logProvider.cachedSchema;

    if (schema != null) {
      // Find the 'Linguagem' field (or similar select/multi_select)
      for (final entry in schema.properties.entries) {
        if (entry.value.name.toLowerCase().contains('linguagem') ||
            entry.value.name.toLowerCase().contains('materia') ||
            entry.value.name.toLowerCase().contains('subject')) {
          if (entry.value.options.isNotEmpty) {
            _availableLanguages = entry.value.options;
            return;
          }
        }
      }
      
      // Fallback: any select/multi_select
      for (final entry in schema.properties.entries) {
        if (entry.value.type == 'select' || entry.value.type == 'multi_select') {
          if (entry.value.options.isNotEmpty) {
            _availableLanguages = entry.value.options;
            return;
          }
        }
      }
    }

    // Ultimate fallback
    _availableLanguages = AppConstants.defaultSubjects;
  }

  void _save() async {
    final provider = context.read<GoalProvider>();
    final minutes = int.tryParse(_minutesController.text) ?? 0;

    if (minutes <= 0) {
      SnackbarHelper.showWarning(context, 'Insira um tempo válido (em minutos).');
      return;
    }

    final goal = StudyGoal(
      id: widget.existingGoal?.id,
      type: _type,
      targetMinutes: minutes,
      languages: _selectedLanguages,
      periodStart: _type == GoalType.weekly
          ? StudyGoal.currentWeekStart()
          : StudyGoal.currentMonthStart(),
      createdAt: widget.existingGoal?.createdAt,
    );

    if (widget.existingGoal != null) {
      await provider.updateGoal(goal);
      if (mounted) Navigator.pop(context);
    } else {
      final success = await provider.addGoal(goal);
      if (success) {
        if (mounted) Navigator.pop(context);
      } else {
        if (mounted) {
          SnackbarHelper.showError(
              context, 'Já existe uma meta ativa para este período.');
        }
      }
    }
  }

  void _delete() async {
    if (widget.existingGoal == null) return;

    final provider = context.read<GoalProvider>();
    await provider.deleteGoal(widget.existingGoal!.id);
    if (mounted) {
      Navigator.pop(context);
      SnackbarHelper.showSuccess(context, 'Meta excluída.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.existingGoal != null ? 'Editar Meta' : 'Nova Meta',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Type Selector
          Row(
            children: [
              Expanded(
                child: _TypeButton(
                  label: 'Semanal',
                  isSelected: _type == GoalType.weekly,
                  onTap: () => setState(() => _type = GoalType.weekly),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _TypeButton(
                  label: 'Mensal',
                  isSelected: _type == GoalType.monthly,
                  onTap: () => setState(() => _type = GoalType.monthly),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Target Minutes
          CustomTextField(
            label: 'Tempo Alvo (em minutos)',
            hint: 'Ex: 120 para 2 horas',
            prefixIcon: Icons.timer_rounded,
            controller: _minutesController,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 24),

          // Languages Selector
          Text(
            'Linguagens / Matérias (Opcional)',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Se vazio, contabiliza todo tempo de estudo.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableLanguages.map((lang) {
              final isSelected = _selectedLanguages.contains(lang);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedLanguages.remove(lang);
                    } else {
                      _selectedLanguages.add(lang);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.purple
                        : Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSelected) ...[
                        const Icon(Icons.check_rounded,
                            size: 14, color: Colors.white),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        lang,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : AppColors.purple,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),

          // Actions
          Row(
            children: [
              if (widget.existingGoal != null) ...[
                IconButton(
                  onPressed: _delete,
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: AppColors.error),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.error.withValues(alpha: 0.1),
                    padding: const EdgeInsets.all(16),
                  ),
                ),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: CustomButton(
                  label: 'Salvar Meta',
                  onPressed: _save,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeButton({
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
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryGreen : Theme.of(context).dividerTheme.color ?? AppColors.cardGrey,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
      ),
    );
  }
}
