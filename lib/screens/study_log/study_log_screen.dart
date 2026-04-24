import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:study_hub/config/app_theme.dart';
import 'package:study_hub/models/study_log.dart';
import 'package:study_hub/providers/study_log_provider.dart';
import 'package:study_hub/providers/settings_provider.dart';
import 'package:study_hub/services/notion_service.dart';
import 'package:study_hub/widgets/dynamic_form_builder.dart';
import 'package:study_hub/widgets/custom_button.dart';
import 'package:study_hub/widgets/study_timer_widget.dart';
import 'package:study_hub/providers/study_timer_provider.dart';
import 'package:study_hub/utils/snackbar_helper.dart';

class StudyLogScreen extends StatefulWidget {
  const StudyLogScreen({super.key});

  @override
  State<StudyLogScreen> createState() => _StudyLogScreenState();
}

class _StudyLogScreenState extends State<StudyLogScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Mapa dinâmico que armazenará o Nome da Propriedade (Col) e o valor digitado pelo User
  final Map<String, dynamic> _dynamicFormValues = {};
  
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Tenta carregar o schema quando a tela abre, caso já tenha no cache local.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StudyLogProvider>().loadSchemaFromCache();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StudyLogProvider>();
    final timerProvider = context.watch<StudyTimerProvider>();
    final schema = provider.cachedSchema;

    // Auto-fill from last timer session if available
    if (schema != null && timerProvider.lastSessionMinutes > 0) {
      // Use the same logic as _onTimerStopped but without the snackbar to avoid loop
      final minutes = timerProvider.lastSessionMinutes;
      
      // Delay the state update to avoid "setState during build"
      Future.microtask(() {
        if (mounted) {
          _onTimerStopped(minutes, schema);
          timerProvider.clearLastSession();
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Aprendizado'),
        leading: Navigator.canPop(context) 
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: schema == null
          ? _buildNoSchemaState(provider.isLoading)
          : SingleChildScrollView(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 140),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Study Timer ──
                    StudyTimerWidget(
                      onTimerStopped: (minutes) => _onTimerStopped(minutes, schema),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'Preencha os dados do Notion',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 20),

                    // LISTA DINÂMICA
                    // Iteramos sobre o Schema. Para cada coluna, desenhamos o Widget correto.
                    ...schema.properties.entries.map((entry) {
                      final prop = entry.value;
                      return DynamicFormBuilder(
                        property: prop,
                        initialValue: _dynamicFormValues[prop.name], // Passa o cache atual, se tiver
                        onChanged: (newValue) {
                          setState(() {
                            _dynamicFormValues[prop.name] = newValue;
                          });
                        },
                      );
                    }), // .toList() omitido pois usamos spread operator (...)

                    const SizedBox(height: 32),

                    // ── Botão Salvar no Notion ──
                    CustomButton(
                      label: 'Salvar no Notion',
                      icon: Icons.cloud_upload_rounded,
                      color: AppColors.purple,
                      isLoading: _isSaving,
                      onPressed: () => _saveToNotion(schema),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  // Estado de aviso caso o usuário não tenha sincronizado a tabela ainda
  Widget _buildNoSchemaState(bool isLoading) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.purple));
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.table_chart_rounded, size: 64, color: Theme.of(context).textTheme.bodySmall?.color),
            const SizedBox(height: 16),
            Text(
              'A Estrutura do Tabela ainda não foi sincronizada.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Theme.of(context).textTheme.bodyLarge?.color),
            ),
            const SizedBox(height: 24),
            CustomButton(
              label: 'Sincronizar Tabela',
              color: AppColors.primaryGreen,
              onPressed: () async {
                final isConnected = context.read<SettingsProvider>().isNotionConnected;
                if (!isConnected) {
                  SnackbarHelper.showWarning(context, 'Configure o Token e DatabaseID antes.');
                  return;
                }
                
                final success = await context.read<StudyLogProvider>().syncSchemaFromNotion();
                if (mounted && !success) {
                  SnackbarHelper.showError(context, 'Erro ao sincronizar com o banco.');
                }
              },
            )
          ],
        ),
      ),
    );
  }

  /// Called when the timer is stopped — auto-fills the correct number field.
  void _onTimerStopped(int minutes, dynamic schema) {
    if (schema == null || minutes <= 0) return;

    // 1. Try to find a field named "tempo" (case insensitive)
    var targetProp = schema.properties.entries.firstWhere(
      (e) => e.value.type == 'number' && e.value.name.toLowerCase().contains('tempo'),
      orElse: () => MapEntry('', null),
    ).value;

    // 2. If not found, try "time"
    if (targetProp == null) {
      targetProp = schema.properties.entries.firstWhere(
        (e) => e.value.type == 'number' && e.value.name.toLowerCase().contains('time'),
        orElse: () => MapEntry('', null),
      ).value;
    }

    // 3. Fallback to the first number field
    if (targetProp == null) {
      targetProp = schema.properties.entries.firstWhere(
        (e) => e.value.type == 'number',
        orElse: () => MapEntry('', null),
      ).value;
    }

    if (targetProp != null) {
      setState(() {
        _dynamicFormValues[targetProp.name] = minutes;
      });
      SnackbarHelper.showSuccess(
        context,
        'Tempo de estudo preenchido: ${minutes}min ⏱️',
      );
    } else {
      SnackbarHelper.showWarning(
        context,
        'Não encontramos um campo numérico para preencher o tempo.',
      );
    }
  }

  Future<void> _saveToNotion(dynamic schema) async {
    // Validações básicas (os FormBuilders tratam inputs nativos)
    if (!_formKey.currentState!.validate()) return;

    final isConnected = context.read<SettingsProvider>().isNotionConnected;
    if (!isConnected) {
      SnackbarHelper.showWarning(context, 'Você precisa configurar o Notion (vá em Configurações)');
      return;
    }

    // Se o payload não tiver pelo menos o Título ou outro campo preenchido (vazio)
    if (_dynamicFormValues.isEmpty) {
      SnackbarHelper.showWarning(context, 'Preencha algum campo antes de salvar.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Cria o StudyLog usando nosso novo Data Model Dinâmico
      final log = StudyLog(
        rawValues: Map<String, dynamic>.from(_dynamicFormValues),
        schema: schema,
      );

      final notionService = NotionService();
      final pageId = await notionService.createStudyLog(log);

      if (pageId != null) {
        final updatedLog = log.copyWith(
          syncedWithNotion: true,
          notionPageId: pageId,
        );
        if (mounted) {
          context.read<StudyLogProvider>().addLog(updatedLog);
          SnackbarHelper.showSuccess(context, 'Registro salvo no Notion com sucesso! 📓');
          
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          } else {
            // Clear the form if we are inside a BottomNavBar tab
             _dynamicFormValues.clear();
             _formKey.currentState?.reset();
          }
        }
        if (mounted) {
          setState(() => _isSaving = false);
        }
        return;
      } else {
        if (mounted) {
          SnackbarHelper.showError(context, 'Erro ao salvar no Notion. Verifique o console.');
        }
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Erro inesperado: $e');
      }
    }

    if (mounted) {
      setState(() => _isSaving = false);
    }
  }
}
