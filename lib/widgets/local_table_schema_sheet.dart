import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:study_hub/config/app_theme.dart';
import 'package:study_hub/models/local_study_field.dart';
import 'package:study_hub/providers/local_study_schema_provider.dart';
import 'package:study_hub/providers/settings_provider.dart';
import 'package:study_hub/services/app_haptics.dart';
import 'package:study_hub/utils/snackbar_helper.dart';
import 'package:study_hub/widgets/app_modal.dart';
import 'package:study_hub/widgets/app_surface.dart';
import 'package:study_hub/widgets/custom_button.dart';
import 'package:study_hub/widgets/custom_text_field.dart';

class LocalTableSchemaSheet extends StatelessWidget {
  const LocalTableSchemaSheet({super.key});

  static Future<void> show(BuildContext context) {
    AppHaptics.selection();
    return AppModal.showSheet<void>(
      context: context,
      builder: (_) => const LocalTableSchemaSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final schema = context.watch<LocalStudySchemaProvider>();
    final settings = context.watch<SettingsProvider>();
    final numberFields = schema.activeFields
        .where((field) => field.type == LocalStudyFieldType.number)
        .toList();
    final selectedTimeField =
        numberFields.any(
          (field) => field.label == settings.settings.localTimeField,
        )
        ? settings.settings.localTimeField
        : (numberFields.isNotEmpty ? numberFields.first.label : null);

    return AppSurface(
      color: context.colors.modalSurface,
      shadow: context.elevations.high,
      padding: EdgeInsets.fromLTRB(
        spacing.lg,
        spacing.lg,
        spacing.lg,
        spacing.lg + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSectionHeader(
              title: 'Tabela local',
              subtitle: 'Campos usados nos registros sem depender do Notion.',
              trailing: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
            SizedBox(height: spacing.lg),
            if (schema.isLoading)
              const Center(child: CircularProgressIndicator())
            else ...[
              if (schema.lastError != null) ...[
                _ErrorBanner(message: schema.lastError!),
                SizedBox(height: spacing.md),
              ],
              _TimeFieldPicker(
                fields: numberFields,
                selected: selectedTimeField,
                onChanged: (value) async {
                  if (value == null) return;
                  await context.read<SettingsProvider>().setLocalTimeField(
                    value,
                  );
                  AppHaptics.success();
                },
              ),
              SizedBox(height: spacing.lg),
              ...schema.activeFields.map(
                (field) => Padding(
                  padding: EdgeInsets.only(bottom: spacing.sm),
                  child: _FieldTile(
                    field: field,
                    onEdit: () => _showFieldForm(context, field: field),
                    onArchive: () => _archiveField(
                      context,
                      field,
                      protectedTimeField: selectedTimeField,
                    ),
                  ),
                ),
              ),
              SizedBox(height: spacing.md),
              CustomButton(
                label: 'Adicionar campo',
                icon: Icons.add_rounded,
                onPressed: () => _showFieldForm(context),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _archiveField(
    BuildContext context,
    LocalStudyField field, {
    required String? protectedTimeField,
  }) async {
    final ok = await context.read<LocalStudySchemaProvider>().archiveField(
      id: field.id,
      protectedTimeField: protectedTimeField,
    );
    if (!context.mounted) return;
    if (ok) {
      AppHaptics.success();
      SnackbarHelper.showSuccess(context, 'Campo arquivado.');
    } else {
      final error = context.read<LocalStudySchemaProvider>().lastError;
      SnackbarHelper.showError(context, error ?? 'Não foi possível arquivar.');
    }
  }

  Future<void> _showFieldForm(
    BuildContext context, {
    LocalStudyField? field,
  }) async {
    await AppModal.showSheet<void>(
      context: context,
      builder: (_) => _LocalFieldForm(field: field),
    );
  }
}

class _LocalFieldForm extends StatefulWidget {
  final LocalStudyField? field;

  const _LocalFieldForm({this.field});

  @override
  State<_LocalFieldForm> createState() => _LocalFieldFormState();
}

class _LocalFieldFormState extends State<_LocalFieldForm> {
  final _labelController = TextEditingController();
  final _optionsController = TextEditingController();
  late LocalStudyFieldType _type;
  bool _isRequired = false;

  @override
  void initState() {
    super.initState();
    final field = widget.field;
    _labelController.text = field?.label ?? '';
    _optionsController.text = field?.options.join(', ') ?? '';
    _type = field?.type ?? LocalStudyFieldType.text;
    _isRequired = field?.isRequired ?? false;
  }

  @override
  void dispose() {
    _labelController.dispose();
    _optionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final usesOptions =
        _type == LocalStudyFieldType.select ||
        _type == LocalStudyFieldType.multiSelect;
    return AppSurface(
      color: context.colors.modalSurface,
      shadow: context.elevations.high,
      padding: EdgeInsets.fromLTRB(
        spacing.lg,
        spacing.lg,
        spacing.lg,
        spacing.lg + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSectionHeader(
              title: widget.field == null ? 'Novo campo' : 'Editar campo',
              subtitle: 'Configure como o campo aparece no registro local.',
              trailing: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
            SizedBox(height: spacing.lg),
            CustomTextField(
              label: 'Nome do campo',
              prefixIcon: Icons.label_rounded,
              controller: _labelController,
            ),
            SizedBox(height: spacing.md),
            DropdownButtonFormField<LocalStudyFieldType>(
              initialValue: _type,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.tune_rounded),
                labelText: 'Tipo',
              ),
              items: LocalStudyFieldType.values
                  .map(
                    (type) =>
                        DropdownMenuItem(value: type, child: Text(type.label)),
                  )
                  .toList(),
              onChanged: widget.field?.isDefault == true
                  ? null
                  : (value) => setState(() => _type = value ?? _type),
            ),
            if (usesOptions) ...[
              SizedBox(height: spacing.md),
              CustomTextField(
                label: 'Opcoes',
                hint: 'Separadas por virgula',
                prefixIcon: Icons.list_rounded,
                controller: _optionsController,
              ),
            ],
            SizedBox(height: spacing.md),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Obrigatorio'),
              value: _isRequired,
              onChanged: (value) => setState(() => _isRequired = value),
            ),
            SizedBox(height: spacing.lg),
            CustomButton(
              label: 'Salvar campo',
              icon: Icons.check_rounded,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final label = _labelController.text.trim();
    if (label.isEmpty) {
      SnackbarHelper.showWarning(context, 'Informe o nome do campo.');
      return;
    }
    final options = _optionsController.text
        .split(',')
        .map((option) => option.trim())
        .where((option) => option.isNotEmpty)
        .toSet()
        .toList();
    final existing = widget.field;
    final next = LocalStudyField(
      id: existing?.id,
      label: label,
      type: _type,
      options: options,
      isRequired: _isRequired,
      isDefault: existing?.isDefault ?? false,
      createdAt: existing?.createdAt,
    );
    final provider = context.read<LocalStudySchemaProvider>();
    final settings = context.read<SettingsProvider>();
    final ok = existing == null
        ? await provider.addField(next)
        : await provider.updateField(next);
    if (!mounted) return;
    if (ok) {
      if (existing != null &&
          settings.settings.localTimeField == existing.label) {
        await settings.setLocalTimeField(next.label);
      }
      if (!mounted) return;
      AppHaptics.success();
      Navigator.pop(context);
      SnackbarHelper.showSuccess(context, 'Campo salvo.');
    } else {
      SnackbarHelper.showError(
        context,
        provider.lastError ?? 'Não foi possível salvar o campo.',
      );
    }
  }
}

class _TimeFieldPicker extends StatelessWidget {
  final List<LocalStudyField> fields;
  final String? selected;
  final ValueChanged<String?> onChanged;

  const _TimeFieldPicker({
    required this.fields,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AppSurface.subtle(
      padding: EdgeInsets.all(context.spacing.md),
      child: DropdownButtonFormField<String>(
        initialValue: selected,
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.timer_rounded),
          labelText: 'Campo do timer',
        ),
        items: fields
            .map(
              (field) => DropdownMenuItem(
                value: field.label,
                child: Text(field.label),
              ),
            )
            .toList(),
        onChanged: fields.isEmpty ? null : onChanged,
      ),
    );
  }
}

class _FieldTile extends StatelessWidget {
  final LocalStudyField field;
  final VoidCallback onEdit;
  final VoidCallback onArchive;

  const _FieldTile({
    required this.field,
    required this.onEdit,
    required this.onArchive,
  });

  @override
  Widget build(BuildContext context) {
    return AppSurface.subtle(
      padding: EdgeInsets.all(context.spacing.md),
      child: Row(
        children: [
          Icon(Icons.view_column_rounded, color: context.colors.accent),
          SizedBox(width: context.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(field.label, style: context.theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  field.type.label,
                  style: context.theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Editar',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_rounded),
          ),
          IconButton(
            tooltip: 'Arquivar',
            onPressed: field.isRequired ? null : onArchive,
            icon: Icon(
              Icons.delete_outline_rounded,
              color: field.isRequired
                  ? context.colors.textDisabled
                  : context.colors.error,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return AppSurface.subtle(
      padding: EdgeInsets.all(context.spacing.md),
      child: Text(message, style: context.theme.textTheme.bodySmall),
    );
  }
}
