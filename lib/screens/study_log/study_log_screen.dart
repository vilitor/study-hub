import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:study_hub/config/app_routes.dart';
import 'package:study_hub/config/app_theme.dart';
import 'package:study_hub/models/app_settings.dart';
import 'package:study_hub/models/local_study_field.dart';
import 'package:study_hub/models/notion_schema.dart';
import 'package:study_hub/models/study_log.dart';
import 'package:study_hub/providers/local_study_schema_provider.dart';
import 'package:study_hub/providers/settings_provider.dart';
import 'package:study_hub/providers/study_log_provider.dart';
import 'package:study_hub/providers/study_timer_provider.dart';
import 'package:study_hub/services/app_haptics.dart';
import 'package:study_hub/services/local_study_schema_service.dart';
import 'package:study_hub/utils/snackbar_helper.dart';
import 'package:study_hub/widgets/app_surface.dart';
import 'package:study_hub/widgets/custom_button.dart';
import 'package:study_hub/widgets/custom_text_field.dart';
import 'package:study_hub/widgets/dynamic_form_builder.dart';
import 'package:study_hub/widgets/full_screen_success_overlay.dart';
import 'package:study_hub/widgets/notion_connection_sheet.dart';
import 'package:study_hub/widgets/study_timer_widget.dart';

class StudyLogScreen extends StatefulWidget {
  const StudyLogScreen({super.key});

  @override
  State<StudyLogScreen> createState() => _StudyLogScreenState();
}

class _StudyLogScreenState extends State<StudyLogScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _localControllers = {};
  final Map<String, dynamic> _localDraftValues = {};
  final Map<String, dynamic> _notionDraftValues = {};
  final TextEditingController _notesDraftController = TextEditingController();

  bool _isSaving = false;
  bool _isSyncingNotionSchema = false;
  String? _notionSchemaError;
  String? _notionSchemaWarning;
  RegisterFieldSource? _lastEffectiveSource;
  String? _lastNotionDatabaseId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StudyLogProvider>().loadSchemaFromCache();
    });
  }

  @override
  void dispose() {
    for (final controller in _localControllers.values) {
      controller.dispose();
    }
    _notesDraftController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logProvider = context.watch<StudyLogProvider>();
    final localSchema = context.watch<LocalStudySchemaProvider>();
    final timerProvider = context.watch<StudyTimerProvider>();
    final settingsProvider = context.watch<SettingsProvider>();
    final localFields = localSchema.activeFields;
    final effectiveSource = _effectiveSource(settingsProvider);
    final notionProperties = _supportedNotionProperties(
      logProvider.cachedSchema,
    );
    final hasActiveTimeField = _hasActiveTimeField(
      settingsProvider,
      effectiveSource,
      localFields: localFields,
      notionProperties: notionProperties,
    );

    _syncLocalFieldControllers(localFields);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _handleSourceState(settingsProvider, logProvider);
    });

    if (timerProvider.lastSessionMinutes > 0) {
      final minutes = timerProvider.lastSessionMinutes;
      Future.microtask(() {
        if (!mounted) return;
        _onTimerStopped(minutes);
        timerProvider.clearLastSession();
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Aprendizado'),
        backgroundColor: Colors.transparent,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        actions: [
          IconButton(
            tooltip: 'Historico',
            onPressed: _openHistory,
            icon: const Icon(Icons.history_rounded),
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Positioned(
            top: -50,
            left: -50,
            child: _BlurGlow(color: AppColors.purple.withValues(alpha: 0.1)),
          ),
          Positioned(
            bottom: 100,
            right: -50,
            child: _BlurGlow(
              color: AppColors.primaryGreen.withValues(alpha: 0.1),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                context.spacing.screenPadding,
                context.spacing.lg,
                context.spacing.screenPadding,
                140,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StudyTimerWidget(onTimerStopped: _onTimerStopped),
                    SizedBox(height: context.spacing.sectionGap),
                    _RegisterHeader(
                      selectedSource: effectiveSource,
                      isNotionConnected: settingsProvider.isNotionConnected,
                      isSchemaReady: logProvider.cachedSchema != null,
                      isSyncingSchema: _isSyncingNotionSchema,
                      schemaWarning: _notionSchemaWarning,
                      onSelectSource: (source) => _setRegisterSource(
                        source,
                        settingsProvider,
                        logProvider,
                      ),
                      onManageNotion: () => NotionConnectionSheet.show(context),
                    ),
                    SizedBox(height: context.spacing.sectionGap),
                    ..._buildActiveFieldContent(
                      effectiveSource: effectiveSource,
                      settingsProvider: settingsProvider,
                      logProvider: logProvider,
                      localSchema: localSchema,
                      localFields: localFields,
                      notionProperties: notionProperties,
                    ),
                    if (!hasActiveTimeField) ...[
                      SizedBox(height: context.spacing.md),
                      _RegisterBlockingState(
                        message: effectiveSource == RegisterFieldSource.local
                            ? 'A tabela local precisa de um campo numerico para registrar tempo.'
                            : 'A tabela do Notion precisa de um campo numerico para receber o tempo de estudo.',
                      ),
                    ],
                    SizedBox(height: context.spacing.xl),
                    CustomButton(
                      label: _isSaving ? 'Salvando...' : 'Salvar registro',
                      icon: Icons.check_circle_rounded,
                      isLoading: _isSaving,
                      onPressed: hasActiveTimeField
                          ? () => _saveRecord(
                              source: effectiveSource,
                              notionSchema: logProvider.cachedSchema,
                              settings: settingsProvider,
                              localFields: localFields,
                              notionProperties: notionProperties,
                            )
                          : null,
                    ),
                    SizedBox(height: context.spacing.sm),
                    OutlinedButton.icon(
                      onPressed: _openHistory,
                      icon: const Icon(Icons.history_rounded),
                      label: const Text('Ver historico de registros'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            right: _notesRightOffset(context),
            bottom: _notesBottomOffset(
              context,
              isTimerActive: timerProvider.isActive,
            ),
            child: _NotesFloatingButton(
              hasDraft: _hasNotesDraft,
              onPressed: _showNotesModal,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveRecord({
    required RegisterFieldSource source,
    required NotionDatabaseSchema? notionSchema,
    required SettingsProvider settings,
    required List<LocalStudyField> localFields,
    required List<NotionProperty> notionProperties,
  }) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final provider = context.read<StudyLogProvider>();
    late final StudyLog log;

    if (source == RegisterFieldSource.local) {
      final schema = LocalStudySchemaService.schemaFromFields(localFields);
      final localTimeField = _resolvedLocalTimeField(settings, localFields);
      final rawValues = _collectLocalRawValues(localFields);
      log = StudyLog(
        rawValues: rawValues,
        schema: schema,
        localNote: _buildLocalNote(source),
        source: StudyLogSource.local,
        studyTimeField: localTimeField,
      );
    } else {
      if (notionSchema == null) {
        setState(() => _isSaving = false);
        SnackbarHelper.showError(
          context,
          'Nao foi possivel carregar os campos do Notion.',
        );
        return;
      }
      final notionTimeField = _resolvedNotionTimeField(
        settings,
        notionProperties,
      );
      if (notionTimeField == null) {
        setState(() => _isSaving = false);
        SnackbarHelper.showError(
          context,
          'A tabela do Notion precisa de um campo numerico para o tempo.',
        );
        return;
      }
      log = StudyLog(
        rawValues: _collectNotionRawValues(notionProperties),
        schema: notionSchema,
        localNote: _buildLocalNote(source),
        source: StudyLogSource.notion,
        studyTimeField: notionTimeField,
      );
    }

    final saved = await provider.saveLocalLog(log);
    if (!mounted) return;

    var syncAttempted = false;
    var syncSucceeded = false;
    if (saved &&
        source == RegisterFieldSource.notion &&
        settings.isNotionConnected) {
      var schemaForSync = notionSchema;
      if (schemaForSync == null) {
        await provider.syncSchemaFromNotion();
        schemaForSync = provider.cachedSchema;
      }
      if (schemaForSync != null) {
        syncAttempted = true;
        final pageId = await provider.syncLocalLogToNotion(
          localLog: log,
          notionSchema: schemaForSync,
          notionTimeField: settings.settings.notionTimeField,
        );
        syncSucceeded = pageId != null;
      }
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (!saved) {
      SnackbarHelper.showError(context, 'Nao foi possivel salvar localmente.');
      return;
    }

    await FullScreenSuccessOverlay.show(context, message: 'Registro concluido');
    if (!mounted) return;

    if (source == RegisterFieldSource.notion && settings.isNotionConnected) {
      if (syncSucceeded) {
        SnackbarHelper.showSuccess(context, 'Registro salvo e sincronizado.');
      } else if (syncAttempted) {
        SnackbarHelper.showWarning(
          context,
          'Registro salvo localmente. Sync com Notion falhou.',
        );
      } else {
        SnackbarHelper.showWarning(
          context,
          'Registro salvo localmente. Sincronize a tabela do Notion para enviar.',
        );
      }
    }

    _clearForm(source);
  }

  List<Widget> _buildActiveFieldContent({
    required RegisterFieldSource effectiveSource,
    required SettingsProvider settingsProvider,
    required StudyLogProvider logProvider,
    required LocalStudySchemaProvider localSchema,
    required List<LocalStudyField> localFields,
    required List<NotionProperty> notionProperties,
  }) {
    if (effectiveSource == RegisterFieldSource.local) {
      if (localSchema.isLoading) {
        return const [Center(child: CircularProgressIndicator())];
      }
      if (localFields.isEmpty) {
        return const [
          _RegisterEmptyState(
            message: 'Nenhum campo local disponivel para registro.',
          ),
        ];
      }
      return localFields
          .map(
            (field) => Padding(
              padding: EdgeInsets.only(bottom: context.spacing.md),
              child: _buildLocalField(field),
            ),
          )
          .toList();
    }

    if (_isSyncingNotionSchema && logProvider.cachedSchema == null) {
      return const [Center(child: CircularProgressIndicator())];
    }
    if (_notionSchemaError != null && logProvider.cachedSchema == null) {
      return [
        _RegisterErrorState(
          message: _notionSchemaError!,
          onRetry: () => _refreshNotionSchema(
            settingsProvider: settingsProvider,
            logProvider: logProvider,
            forceRefresh: true,
          ),
          onManageNotion: () => NotionConnectionSheet.show(context),
        ),
      ];
    }
    if (notionProperties.isEmpty) {
      return const [
        _RegisterEmptyState(
          message:
              'Nenhum campo compativel foi encontrado na tabela do Notion.',
        ),
      ];
    }
    return notionProperties
        .map(
          (property) => DynamicFormBuilder(
            key: ValueKey('notion-${_notionDraftKey(property)}'),
            property: property,
            initialValue:
                _notionDraftValues[_notionDraftKey(property)] ??
                (property.type == 'date' ? DateTime.now() : null),
            onChanged: (value) => setState(
              () => _notionDraftValues[_notionDraftKey(property)] = value,
            ),
          ),
        )
        .toList();
  }

  Widget _buildLocalField(LocalStudyField field) {
    switch (field.type) {
      case LocalStudyFieldType.text:
      case LocalStudyFieldType.longText:
        return CustomTextField(
          label: field.label,
          prefixIcon: field.type == LocalStudyFieldType.longText
              ? Icons.notes_rounded
              : Icons.short_text_rounded,
          controller: _controllerFor(field),
          maxLines: field.type == LocalStudyFieldType.longText ? 5 : 1,
          validator: field.isRequired
              ? (value) => value == null || value.trim().isEmpty
                    ? 'Informe ${field.label}.'
                    : null
              : null,
          onChanged: (value) => _localDraftValues[field.id] = value,
        );
      case LocalStudyFieldType.number:
        return CustomTextField(
          label: field.label,
          hint: '0',
          prefixIcon: Icons.numbers_rounded,
          keyboardType: TextInputType.number,
          controller: _controllerFor(field),
          onChanged: (value) =>
              _localDraftValues[field.id] = int.tryParse(value) ?? 0,
        );
      case LocalStudyFieldType.select:
        final selected = field.options.contains(_localDraftValues[field.id])
            ? _localDraftValues[field.id] as String
            : null;
        return DropdownButtonFormField<String>(
          key: ValueKey('local-select-${field.id}'),
          initialValue: selected,
          decoration: InputDecoration(
            labelText: field.label,
            prefixIcon: const Icon(Icons.arrow_drop_down_circle_rounded),
          ),
          items: field.options
              .map(
                (option) => DropdownMenuItem(
                  value: option,
                  child: Text(option, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: (value) {
            AppHaptics.selection();
            setState(() => _localDraftValues[field.id] = value ?? '');
          },
        );
      case LocalStudyFieldType.multiSelect:
        final selected = Set<String>.from(
          _localDraftValues[field.id] as List? ?? const [],
        );
        return _MultiSelectLocalField(
          key: ValueKey('local-multi-${field.id}'),
          field: field,
          selected: selected,
          onChanged: (values) => setState(
            () => _localDraftValues[field.id] = values.toList()..sort(),
          ),
        );
      case LocalStudyFieldType.date:
        final value = _localDraftValues[field.id] is DateTime
            ? _localDraftValues[field.id] as DateTime
            : DateTime.now();
        _localDraftValues[field.id] = value;
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.calendar_today_rounded),
          title: Text(field.label),
          subtitle: Text(
            '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}',
          ),
          onTap: () async {
            AppHaptics.selection();
            final picked = await showDatePicker(
              context: context,
              initialDate: value,
              firstDate: DateTime(value.year - 10),
              lastDate: DateTime(value.year + 2),
            );
            if (picked != null && mounted) {
              setState(() => _localDraftValues[field.id] = picked);
            }
          },
        );
    }
  }

  TextEditingController _controllerFor(LocalStudyField field) {
    return _localControllers.putIfAbsent(field.id, () {
      final initial = _localDraftValues[field.id]?.toString() ?? '';
      final controller = TextEditingController(text: initial);
      controller.addListener(() {
        if (field.type == LocalStudyFieldType.number) {
          _localDraftValues[field.id] = int.tryParse(controller.text) ?? 0;
        } else {
          _localDraftValues[field.id] = controller.text;
        }
      });
      return controller;
    });
  }

  void _syncLocalFieldControllers(List<LocalStudyField> fields) {
    final activeIds = fields.map((field) => field.id).toSet();
    final removedIds = _localControllers.keys
        .where((id) => !activeIds.contains(id))
        .toList();
    for (final id in removedIds) {
      _localControllers.remove(id)?.dispose();
    }
  }

  Map<String, dynamic> _collectLocalRawValues(List<LocalStudyField> fields) {
    final values = <String, dynamic>{};
    for (final field in fields) {
      final value = _localDraftValues[field.id];
      if (value == null) continue;
      if (value is String && value.trim().isEmpty) continue;
      if (value is Iterable && value.isEmpty) continue;
      values[field.label] = value;
    }
    return values;
  }

  Map<String, dynamic> _collectNotionRawValues(
    List<NotionProperty> properties,
  ) {
    final values = <String, dynamic>{};
    for (final property in properties) {
      final value = _notionDraftValues[_notionDraftKey(property)];
      if (property.type == 'date') {
        values[property.name] = value ?? DateTime.now();
        continue;
      }
      if (value == null) continue;
      if (value is String && value.trim().isEmpty) continue;
      if (value is Iterable && value.isEmpty) continue;
      values[property.name] = value;
    }
    return values;
  }

  String _notionDraftKey(NotionProperty property) {
    return property.id.isNotEmpty ? property.id : property.name;
  }

  String _resolvedLocalTimeField(
    SettingsProvider settings,
    List<LocalStudyField> fields,
  ) {
    final configured = settings.settings.localTimeField;
    if (configured != null &&
        fields.any(
          (field) =>
              field.label == configured &&
              field.type == LocalStudyFieldType.number,
        )) {
      return configured;
    }
    final firstNumber = fields
        .where((field) => field.type == LocalStudyFieldType.number)
        .firstOrNull;
    return firstNumber?.label ?? LocalStudyFields.studyTime;
  }

  String? _resolvedNotionTimeField(
    SettingsProvider settings,
    List<NotionProperty> properties,
  ) {
    final configured = settings.settings.notionTimeField;
    if (configured != null &&
        properties.any(
          (property) =>
              property.name == configured && property.type == 'number',
        )) {
      return configured;
    }
    final firstNumber = properties
        .where((property) => property.type == 'number')
        .firstOrNull;
    if (firstNumber != null &&
        settings.settings.notionTimeField != firstNumber.name) {
      unawaited(settings.setNotionTimeField(firstNumber.name));
    }
    return firstNumber?.name;
  }

  String _preferredString(List<String> labels) {
    final fields = context.read<LocalStudySchemaProvider>().activeFields;
    for (final label in labels) {
      final field = fields.where((field) => field.label == label).firstOrNull;
      if (field == null) continue;
      final value = _localDraftValues[field.id]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return '';
  }

  bool get _hasNotesDraft => _notesDraftController.text.trim().isNotEmpty;

  StudyLogNote? _buildLocalNote(RegisterFieldSource source) {
    final summary = _notesDraftController.text.trim().isNotEmpty
        ? _notesDraftController.text.trim()
        : source == RegisterFieldSource.local
        ? _preferredString([LocalStudyFields.notes])
        : '';
    final note = StudyLogNote(
      subject: source == RegisterFieldSource.local
          ? _preferredString([
              LocalStudyFields.subject,
              LocalStudyFields.category,
            ])
          : '',
      contentName: source == RegisterFieldSource.local
          ? _preferredString([LocalStudyFields.title])
          : '',
      summary: summary,
    );
    return note.isNotEmpty ? note : null;
  }

  void _clearForm(RegisterFieldSource source) {
    if (source == RegisterFieldSource.local) {
      for (final controller in _localControllers.values) {
        controller.clear();
      }
      _localDraftValues.clear();
    } else {
      _notionDraftValues.clear();
    }
    _notesDraftController.clear();
    setState(() {});
  }

  void _onTimerStopped(int minutes) {
    if (minutes <= 0) return;
    final settings = context.read<SettingsProvider>();
    final effectiveSource = _effectiveSource(settings);
    if (effectiveSource == RegisterFieldSource.local) {
      final fields = context.read<LocalStudySchemaProvider>().activeFields;
      final target = _resolvedLocalTimeField(settings, fields);
      for (final field in fields) {
        if (field.label == target) {
          _localDraftValues[field.id] = minutes;
          if (_localControllers.containsKey(field.id)) {
            _localControllers[field.id]!.text = minutes.toString();
          }
        }
      }
    } else {
      final notionFields = _supportedNotionProperties(
        context.read<StudyLogProvider>().cachedSchema,
      );
      final target = _resolvedNotionTimeField(settings, notionFields);
      if (target == null) {
        SnackbarHelper.showWarning(
          context,
          'A tabela do Notion precisa de um campo numerico para receber o tempo.',
        );
        return;
      }
      final targetProperty = notionFields.firstWhere(
        (property) => property.name == target,
      );
      _notionDraftValues[_notionDraftKey(targetProperty)] = minutes;
    }
    setState(() {});
    SnackbarHelper.showSuccess(
      context,
      'Tempo de estudo preenchido: ${minutes}min',
    );
  }

  Future<void> _showNotesModal() async {
    AppHaptics.selection();
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
          child: AppSurface(
            color: modalContext.colors.modalSurface,
            shadow: modalContext.elevations.high,
            padding: EdgeInsets.all(spacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppSectionHeader(
                  title: 'Notas de estudo',
                  subtitle: 'Salvas localmente junto ao registro.',
                  trailing: IconButton(
                    onPressed: () => Navigator.pop(modalContext),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  ),
                ),
                SizedBox(height: spacing.lg),
                CustomTextField(
                  label: 'Notas',
                  prefixIcon: Icons.notes_rounded,
                  controller: _notesDraftController,
                  maxLines: 8,
                ),
                SizedBox(height: spacing.lg),
                CustomButton(
                  label: 'Concluir',
                  icon: Icons.check_rounded,
                  onPressed: () {
                    AppHaptics.selection();
                    setState(() {});
                    Navigator.pop(modalContext);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
    if (mounted) setState(() {});
  }

  void _openHistory() {
    AppHaptics.selection();
    Navigator.pushNamed(context, AppRoutes.history);
  }

  double _notesRightOffset(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width < 360 ? context.spacing.md : context.spacing.lg;
  }

  double _notesBottomOffset(
    BuildContext context, {
    required bool isTimerActive,
  }) {
    final media = MediaQuery.of(context);
    final safeBottom = media.padding.bottom;
    final keyboardInset = media.viewInsets.bottom;
    final spacing = context.spacing;
    final navReserve = 68 + spacing.sm + safeBottom + spacing.lg;
    final timerReserve = isTimerActive ? 76.0 : 0.0;
    final chromeReserve = navReserve + timerReserve;
    final keyboardReserve = keyboardInset > 0 ? keyboardInset + spacing.md : 0;
    return (keyboardReserve > chromeReserve ? keyboardReserve : chromeReserve)
        .toDouble();
  }

  RegisterFieldSource _effectiveSource(SettingsProvider settingsProvider) {
    if (!settingsProvider.isNotionConnected) {
      return RegisterFieldSource.local;
    }
    return settingsProvider.settings.registerFieldSource;
  }

  bool _hasActiveTimeField(
    SettingsProvider settingsProvider,
    RegisterFieldSource source, {
    required List<LocalStudyField> localFields,
    required List<NotionProperty> notionProperties,
  }) {
    if (source == RegisterFieldSource.local) {
      return localFields.any(
        (field) => field.type == LocalStudyFieldType.number,
      );
    }
    return _resolvedNotionTimeField(settingsProvider, notionProperties) != null;
  }

  List<NotionProperty> _supportedNotionProperties(
    NotionDatabaseSchema? schema,
  ) {
    if (schema == null) return const [];
    const supportedTypes = {
      'title',
      'rich_text',
      'number',
      'select',
      'multi_select',
      'date',
    };
    return schema.properties.values
        .where((property) => supportedTypes.contains(property.type))
        .toList();
  }

  Future<void> _setRegisterSource(
    RegisterFieldSource source,
    SettingsProvider settingsProvider,
    StudyLogProvider logProvider,
  ) async {
    AppHaptics.selection();
    if (source == RegisterFieldSource.notion &&
        !settingsProvider.isNotionConnected) {
      await NotionConnectionSheet.show(context);
      return;
    }
    await settingsProvider.setRegisterFieldSource(source);
    if (!mounted) return;
    if (source == RegisterFieldSource.notion) {
      await _refreshNotionSchema(
        settingsProvider: settingsProvider,
        logProvider: logProvider,
        forceRefresh: true,
      );
    } else {
      setState(() {
        _notionSchemaError = null;
        _notionSchemaWarning = null;
      });
    }
  }

  void _handleSourceState(
    SettingsProvider settingsProvider,
    StudyLogProvider logProvider,
  ) {
    final effectiveSource = _effectiveSource(settingsProvider);
    final notionDatabaseId = settingsProvider.settings.notionDatabaseId;
    final sourceChanged = _lastEffectiveSource != effectiveSource;
    final databaseChanged = _lastNotionDatabaseId != notionDatabaseId;
    if (!sourceChanged && !databaseChanged) return;

    if (databaseChanged) {
      _notionDraftValues.clear();
    }
    _lastEffectiveSource = effectiveSource;
    _lastNotionDatabaseId = notionDatabaseId;

    if (effectiveSource == RegisterFieldSource.notion) {
      unawaited(
        _refreshNotionSchema(
          settingsProvider: settingsProvider,
          logProvider: logProvider,
          forceRefresh: true,
        ),
      );
      return;
    }

    if (_notionSchemaError != null || _notionSchemaWarning != null) {
      setState(() {
        _notionSchemaError = null;
        _notionSchemaWarning = null;
      });
    }
  }

  Future<void> _refreshNotionSchema({
    required SettingsProvider settingsProvider,
    required StudyLogProvider logProvider,
    bool forceRefresh = false,
  }) async {
    if (!settingsProvider.isNotionConnected || _isSyncingNotionSchema) return;
    if (!forceRefresh && logProvider.cachedSchema != null) return;

    final hadCachedSchema = logProvider.cachedSchema != null;
    setState(() {
      _isSyncingNotionSchema = true;
      _notionSchemaError = null;
      _notionSchemaWarning = null;
    });

    final synced = await logProvider.syncSchemaFromNotion();
    if (!mounted) return;

    final hasSchema = logProvider.cachedSchema != null;
    setState(() {
      _isSyncingNotionSchema = false;
      if (synced) {
        _notionSchemaError = null;
        _notionSchemaWarning = null;
      } else if (hadCachedSchema || hasSchema) {
        _notionSchemaWarning =
            'Nao foi possivel atualizar a tabela agora. Campos em cache continuam visiveis.';
      } else {
        _notionSchemaError =
            'Nao foi possivel sincronizar os campos da tabela do Notion.';
      }
    });
  }
}

class _RegisterHeader extends StatelessWidget {
  final RegisterFieldSource selectedSource;
  final bool isNotionConnected;
  final bool isSchemaReady;
  final bool isSyncingSchema;
  final String? schemaWarning;
  final ValueChanged<RegisterFieldSource> onSelectSource;
  final VoidCallback onManageNotion;

  const _RegisterHeader({
    required this.selectedSource,
    required this.isNotionConnected,
    required this.isSchemaReady,
    required this.isSyncingSchema,
    required this.schemaWarning,
    required this.onSelectSource,
    required this.onManageNotion,
  });

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSurface(
          color: Color.alphaBlend(
            context.colors.accent.withValues(alpha: 0.035),
            context.colors.surfaceElevated,
          ),
          shadow: context.elevations.medium,
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: context.colors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  selectedSource == RegisterFieldSource.local
                      ? Icons.table_chart_rounded
                      : Icons.sync_rounded,
                  color: context.colors.accent,
                ),
              ),
              SizedBox(width: spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedSource == RegisterFieldSource.local
                          ? 'Tabela local'
                          : 'Campos do Notion',
                      style: context.theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      selectedSource == RegisterFieldSource.local
                          ? 'Registre estudos mesmo sem Notion. Seus dados locais ficam preservados.'
                          : 'Os campos do formulario seguem a tabela conectada no Notion.',
                      style: context.theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: spacing.md),
        _RegisterSourceSwitch(
          selectedSource: selectedSource,
          isNotionConnected: isNotionConnected,
          onSelectSource: onSelectSource,
          onManageNotion: onManageNotion,
        ),
        SizedBox(height: spacing.sm),
        Text(
          isSyncingSchema
              ? 'Sincronizando campos do Notion...'
              : schemaWarning ??
                    (selectedSource == RegisterFieldSource.notion &&
                            !isSchemaReady
                        ? 'Ative o Notion Sync para carregar a estrutura da tabela.'
                        : selectedSource == RegisterFieldSource.local
                        ? 'O modo selecionado controla quais campos aparecem no registro.'
                        : 'Campos em cache serao atualizados automaticamente quando possivel.'),
          style: context.theme.textTheme.bodySmall?.copyWith(
            color: schemaWarning != null
                ? context.colors.warning
                : context.colors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _RegisterSourceSwitch extends StatelessWidget {
  final RegisterFieldSource selectedSource;
  final bool isNotionConnected;
  final ValueChanged<RegisterFieldSource> onSelectSource;
  final VoidCallback onManageNotion;

  const _RegisterSourceSwitch({
    required this.selectedSource,
    required this.isNotionConnected,
    required this.onSelectSource,
    required this.onManageNotion,
  });

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Row(
      children: [
        Expanded(
          child: _SourceSegment(
            label: 'Local Table',
            isSelected: selectedSource == RegisterFieldSource.local,
            onTap: () => onSelectSource(RegisterFieldSource.local),
          ),
        ),
        SizedBox(width: spacing.sm),
        Expanded(
          child: _SourceSegment(
            label: 'Notion Sync',
            isSelected: selectedSource == RegisterFieldSource.notion,
            isEnabled: isNotionConnected,
            onTap: isNotionConnected
                ? () => onSelectSource(RegisterFieldSource.notion)
                : onManageNotion,
          ),
        ),
      ],
    );
  }
}

class _SourceSegment extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isEnabled;
  final VoidCallback onTap;

  const _SourceSegment({
    required this.label,
    required this.isSelected,
    this.isEnabled = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(context.spacing.pillRadius),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: context.spacing.md,
            vertical: context.spacing.sm,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? colors.accent
                : colors.surface2.withValues(alpha: isEnabled ? 1 : 0.6),
            borderRadius: BorderRadius.circular(context.spacing.pillRadius),
            border: Border.all(
              color: isSelected ? colors.accent : colors.borderSubtle,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: context.theme.textTheme.labelLarge?.copyWith(
                color: isSelected
                    ? colors.textOnAccent
                    : isEnabled
                    ? colors.textPrimary
                    : colors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RegisterErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onManageNotion;

  const _RegisterErrorState({
    required this.message,
    required this.onRetry,
    required this.onManageNotion,
  });

  @override
  Widget build(BuildContext context) {
    return AppSurface.subtle(
      padding: EdgeInsets.all(context.spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: context.theme.textTheme.bodyMedium),
          SizedBox(height: context.spacing.md),
          Wrap(
            spacing: context.spacing.sm,
            runSpacing: context.spacing.sm,
            children: [
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tentar novamente'),
              ),
              TextButton(
                onPressed: onManageNotion,
                child: const Text('Configurar Notion'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RegisterEmptyState extends StatelessWidget {
  final String message;

  const _RegisterEmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return AppSurface.subtle(
      padding: EdgeInsets.all(context.spacing.md),
      child: Text(message, style: context.theme.textTheme.bodyMedium),
    );
  }
}

class _RegisterBlockingState extends StatelessWidget {
  final String message;

  const _RegisterBlockingState({required this.message});

  @override
  Widget build(BuildContext context) {
    return AppSurface.subtle(
      padding: EdgeInsets.all(context.spacing.md),
      child: Text(
        message,
        style: context.theme.textTheme.bodyMedium?.copyWith(
          color: context.colors.warning,
        ),
      ),
    );
  }
}

class _MultiSelectLocalField extends StatelessWidget {
  final LocalStudyField field;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  const _MultiSelectLocalField({
    super.key,
    required this.field,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: context.spacing.xxs,
            bottom: context.spacing.xs,
          ),
          child: Text(field.label, style: context.theme.textTheme.titleSmall),
        ),
        Wrap(
          spacing: context.spacing.xs,
          runSpacing: context.spacing.xs,
          children: field.options.map((option) {
            final isSelected = selected.contains(option);
            return FilterChip(
              label: Text(option),
              selected: isSelected,
              onSelected: (value) {
                AppHaptics.selection();
                final next = Set<String>.from(selected);
                if (value) {
                  next.add(option);
                } else {
                  next.remove(option);
                }
                onChanged(next);
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _NotesFloatingButton extends StatefulWidget {
  final bool hasDraft;
  final VoidCallback onPressed;

  const _NotesFloatingButton({required this.hasDraft, required this.onPressed});

  @override
  State<_NotesFloatingButton> createState() => _NotesFloatingButtonState();
}

class _NotesFloatingButtonState extends State<_NotesFloatingButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.42),
      end: Offset.zero,
    ).animate(curved);
    _scaleAnimation = Tween<double>(begin: 0.92, end: 1).animate(curved);
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(curved);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              FloatingActionButton(
                heroTag: 'study-notes-fab',
                tooltip: 'Notas de estudo',
                elevation: 8,
                backgroundColor: colors.accent,
                foregroundColor: colors.textOnAccent,
                onPressed: widget.onPressed,
                child: const Icon(Icons.edit_note_rounded),
              ),
              if (widget.hasDraft)
                Positioned(
                  right: -1,
                  top: -1,
                  child: Container(
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                      color: colors.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.modalSurface, width: 2),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlurGlow extends StatelessWidget {
  final Color color;

  const _BlurGlow({required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: 220,
        height: 220,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}
