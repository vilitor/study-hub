import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:study_hub/config/app_theme.dart';
import 'package:study_hub/models/study_goal.dart';
import 'package:study_hub/providers/goal_provider.dart';
import 'package:study_hub/providers/settings_provider.dart';
import 'package:study_hub/providers/study_log_provider.dart';
import 'package:study_hub/repositories/subject_repository.dart';
import 'package:study_hub/services/app_haptics.dart';
import 'package:study_hub/services/storage_service.dart';
import 'package:study_hub/utils/snackbar_helper.dart';
import 'package:study_hub/widgets/app_modal.dart';
import 'package:study_hub/widgets/app_multi_select_field.dart';
import 'package:study_hub/widgets/app_surface.dart';
import 'package:study_hub/widgets/custom_button.dart';
import 'package:study_hub/widgets/custom_text_field.dart';

class CreateGoalSheet extends StatefulWidget {
  final StudyGoal? existingGoal;

  const CreateGoalSheet({super.key, this.existingGoal});

  static Future<void> show(BuildContext context, {StudyGoal? goal}) {
    return AppModal.showSheet(
      context: context,
      builder: (context) => CreateGoalSheet(existingGoal: goal),
    );
  }

  @override
  State<CreateGoalSheet> createState() => _CreateGoalSheetState();
}

class _CreateGoalSheetState extends State<CreateGoalSheet> {
  static const SubjectRepository _subjectRepository = SubjectRepository();
  late GoalType _type;
  late int _targetMinutes;
  List<String> _selectedLanguages = [];
  List<String> _availableLanguages = [];
  final _minutesController = TextEditingController();
  bool _showGoalTutorial = false;

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
      _targetMinutes = 120;
      _minutesController.text = '120';
      _loadGoalTutorialState();
    }
  }

  @override
  void dispose() {
    _minutesController.dispose();
    super.dispose();
  }

  void _loadAvailableLanguages() {
    final schema = context.read<StudyLogProvider>().cachedSchema;
    final settings = context.read<SettingsProvider>().settings;
    _availableLanguages = _subjectRepository.getSubjects(
      settings: settings,
      schema: schema,
    );
  }

  Future<void> _loadGoalTutorialState() async {
    final seen = await StorageService().hasSeenGoalTutorial();
    if (!mounted || seen) return;
    setState(() => _showGoalTutorial = true);
  }

  Future<void> _completeGoalTutorial() async {
    await StorageService().setGoalTutorialSeen();
    if (!mounted) return;
    AppHaptics.selection();
    setState(() => _showGoalTutorial = false);
  }

  Future<void> _save() async {
    final provider = context.read<GoalProvider>();
    final minutes = int.tryParse(_minutesController.text) ?? 0;

    if (minutes <= 0) {
      SnackbarHelper.showWarning(context, 'Insira um tempo válido em minutos.');
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
      await AppHaptics.success();
      if (mounted) Navigator.pop(context);
      return;
    }

    final success = await provider.addGoal(goal);
    if (success) {
      await AppHaptics.success();
      if (mounted) Navigator.pop(context);
    } else if (mounted) {
      SnackbarHelper.showError(
        context,
        'Já existe uma meta ativa para este período.',
      );
    }
  }

  Future<void> _delete() async {
    if (widget.existingGoal == null) return;
    AppHaptics.warning();
    await context.read<GoalProvider>().deleteGoal(widget.existingGoal!.id);
    if (!mounted) return;
    AppHaptics.success();
    Navigator.pop(context);
    SnackbarHelper.showSuccess(context, 'Meta excluída.');
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final colors = context.colors;
    return AppSurface(
      color: colors.modalSurface,
      shadow: context.elevations.high,
      radius: spacing.cardRadius,
      padding: EdgeInsets.fromLTRB(
        spacing.xl,
        spacing.xl,
        spacing.xl,
        MediaQuery.of(context).viewInsets.bottom + spacing.xl,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSectionHeader(
              title: widget.existingGoal != null ? 'Editar meta' : 'Nova meta',
              subtitle:
                  'Defina uma meta semanal ou mensal com matérias opcionais.',
              trailing: IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            SizedBox(height: spacing.xl),
            if (_showGoalTutorial) ...[
              _GoalTutorialCard(onComplete: _completeGoalTutorial),
              SizedBox(height: spacing.xl),
            ],
            Row(
              children: [
                Expanded(
                  child: _TypeButton(
                    label: 'Semanal',
                    isSelected: _type == GoalType.weekly,
                    onTap: () {
                      AppHaptics.selection();
                      setState(() => _type = GoalType.weekly);
                    },
                  ),
                ),
                SizedBox(width: spacing.md),
                Expanded(
                  child: _TypeButton(
                    label: 'Mensal',
                    isSelected: _type == GoalType.monthly,
                    onTap: () {
                      AppHaptics.selection();
                      setState(() => _type = GoalType.monthly);
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing.xl),
            CustomTextField(
              label: 'Tempo alvo (em minutos)',
              hint: 'Ex: 120 para 2 horas',
              prefixIcon: Icons.timer_rounded,
              controller: _minutesController,
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: spacing.xl),
            AppMultiSelectField(
              title: 'Linguagens / Matérias',
              helperText: 'Se vazio, contabiliza todo o tempo de estudo.',
              options: _availableLanguages,
              selectedValues: _selectedLanguages,
              enableSearch: _availableLanguages.length >= 8,
              onChanged: (values) =>
                  setState(() => _selectedLanguages = values),
            ),
            SizedBox(height: spacing.xxl),
            Row(
              children: [
                if (widget.existingGoal != null) ...[
                  IconButton(
                    onPressed: _delete,
                    icon: const Icon(Icons.delete_outline_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: colors.error.withValues(alpha: 0.12),
                      foregroundColor: colors.error,
                      minimumSize: const Size(52, 52),
                    ),
                  ),
                  SizedBox(width: spacing.md),
                ],
                Expanded(
                  child: CustomButton(label: 'Salvar meta', onPressed: _save),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalTutorialCard extends StatelessWidget {
  final Future<void> Function() onComplete;

  const _GoalTutorialCard({required this.onComplete});

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final colors = context.colors;
    return AppSurface.subtle(
      padding: EdgeInsets.all(spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.tips_and_updates_rounded,
                  color: colors.accent,
                ),
              ),
              SizedBox(width: spacing.md),
              Expanded(
                child: Text(
                  'Como as materias da meta funcionam',
                  style: context.theme.textTheme.titleSmall,
                ),
              ),
            ],
          ),
          SizedBox(height: spacing.md),
          Text(
            'As materias usadas nas metas vêm das categorias da tela de Eventos. Para editar essa lista, abra Criar evento e use o icone de engrenagem no campo Matérias.',
            style: context.theme.textTheme.bodySmall,
          ),
          SizedBox(height: spacing.md),
          Row(
            children: [
              TextButton(onPressed: onComplete, child: const Text('Pular')),
              const Spacer(),
              FilledButton.icon(
                onPressed: onComplete,
                icon: const Icon(Icons.check_rounded),
                label: const Text('Entendi'),
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
    final colors = context.colors;
    final spacing = context.spacing;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(spacing.fieldRadius),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOutCubic,
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(vertical: spacing.md),
          decoration: BoxDecoration(
            color: isSelected ? colors.accent : colors.surface2,
            borderRadius: BorderRadius.circular(spacing.fieldRadius),
            border: Border.all(
              color: isSelected ? colors.accent : colors.borderSubtle,
            ),
          ),
          child: Text(
            label,
            style: context.theme.textTheme.labelLarge?.copyWith(
              color: isSelected ? colors.textOnAccent : colors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
