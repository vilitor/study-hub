import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:study_hub/config/app_theme.dart';
import 'package:study_hub/providers/settings_provider.dart';
import 'package:study_hub/providers/study_log_provider.dart';
import 'package:study_hub/services/app_haptics.dart';
import 'package:study_hub/services/notion_service.dart';
import 'package:study_hub/utils/snackbar_helper.dart';
import 'package:study_hub/utils/validators.dart';
import 'package:study_hub/widgets/app_modal.dart';
import 'package:study_hub/widgets/app_surface.dart';
import 'package:study_hub/widgets/custom_button.dart';
import 'package:study_hub/widgets/custom_text_field.dart';
import 'package:study_hub/widgets/integration_button.dart';

class NotionConnectionSheet extends StatefulWidget {
  const NotionConnectionSheet({super.key});

  static Future<void> show(BuildContext context) {
    AppHaptics.selection();
    return AppModal.showSheet<void>(
      context: context,
      builder: (_) => const NotionConnectionSheet(),
    );
  }

  @override
  State<NotionConnectionSheet> createState() => _NotionConnectionSheetState();
}

class _NotionConnectionSheetState extends State<NotionConnectionSheet> {
  final _tokenController = TextEditingController();
  final _databaseController = TextEditingController();
  String? _loadWarning;
  bool _isWorking = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _databaseController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loadWarning = null;
    });
    try {
      final settings = context.read<SettingsProvider>();
      if (!settings.isNotionAuthenticated &&
          !settings.hasSelectedNotionDatabase) {
        return;
      }
      final credentials = await Future.wait([
        settings.getEditableNotionToken(),
        settings.getEditableNotionDatabaseId(),
      ]);
      if (!mounted) return;
      if (_tokenController.text.trim().isEmpty) {
        _tokenController.text = credentials[0];
      }
      if (_databaseController.text.trim().isEmpty) {
        _databaseController.text = credentials[1];
      }
    } catch (e) {
      debugPrint('[NotionConnectionSheet] Credential load failed: $e');
      if (!mounted) return;
      setState(() {
        _loadWarning =
            'Nao foi possivel carregar credenciais salvas. Voce ainda pode preencher os campos manualmente.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final settings = context.watch<SettingsProvider>();
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
              title: 'Notion',
              subtitle: settings.isNotionConnected
                  ? 'Tabela conectada. O app continua local-first.'
                  : 'Conecte uma tabela para sincronizar registros quando quiser.',
              trailing: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
            SizedBox(height: spacing.lg),
            IntegrationButton(
              mark: const NotionBrandMark(),
              title: settings.isNotionConnected ? 'Conectado' : 'Desconectado',
              subtitle: settings.isNotionConnected
                  ? 'Database pronto para sync por registro.'
                  : 'Preencha token e Database ID para ativar.',
              isConnected: settings.isNotionConnected,
              onTap: null,
            ),
            SizedBox(height: spacing.lg),
            if (_loadWarning != null) ...[
              _CredentialLoadWarning(message: _loadWarning, onRetry: _load),
              SizedBox(height: spacing.md),
            ] else if (!settings.isNotionConnected) ...[
              _CredentialHelper(),
              SizedBox(height: spacing.md),
            ],
            CustomTextField(
              label: 'Token de integracao',
              hint: 'ntn_xxxxxxxxxxxx...',
              prefixIcon: Icons.key_rounded,
              controller: _tokenController,
              obscureText: true,
            ),
            SizedBox(height: spacing.md),
            CustomTextField(
              label: 'Database ID',
              hint: 'ID do database',
              prefixIcon: Icons.storage_rounded,
              controller: _databaseController,
            ),
            SizedBox(height: spacing.lg),
            CustomButton(
              label: 'Salvar e sincronizar tabela',
              icon: Icons.sync_rounded,
              isLoading: _isWorking,
              onPressed: _isWorking ? null : _saveAndSync,
            ),
            SizedBox(height: spacing.sm),
            CustomButton(
              label: 'Testar conexao',
              icon: Icons.wifi_tethering_rounded,
              isOutlined: true,
              color: context.colors.accentSecondary,
              onPressed: _isWorking ? null : _testConnection,
            ),
            if (settings.isNotionConnected) ...[
              SizedBox(height: spacing.sm),
              CustomButton(
                label: 'Desconectar Notion',
                icon: Icons.link_off_rounded,
                isOutlined: true,
                color: context.colors.error,
                onPressed: _isWorking ? null : _disconnect,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _saveAndSync() async {
    final token = _tokenController.text.trim();
    final databaseId = _databaseController.text.trim();
    final tokenError = Validators.notionToken(token);
    final dbError = Validators.notionDatabaseId(databaseId);
    if (tokenError != null) {
      SnackbarHelper.showError(context, tokenError);
      return;
    }
    if (dbError != null) {
      SnackbarHelper.showError(context, dbError);
      return;
    }

    setState(() => _isWorking = true);
    try {
      final settings = context.read<SettingsProvider>();
      final logs = context.read<StudyLogProvider>();
      await settings.saveNotionCredentials(token, databaseId);
      if (!mounted) return;
      await logs.clearCachedSchema();
      if (!mounted) return;
      final synced = await logs.syncSchemaFromNotion();
      if (!mounted) return;

      if (synced) {
        AppHaptics.success();
        SnackbarHelper.showSuccess(
          context,
          'Notion conectado e tabela sincronizada.',
        );
      } else {
        debugPrint('[NotionConnectionSheet] Schema sync failed after save.');
        SnackbarHelper.showWarning(
          context,
          'Credenciais salvas, mas a tabela nao foi sincronizada.',
        );
      }
    } catch (e) {
      debugPrint('[NotionConnectionSheet] Save/sync failed: $e');
      if (mounted) {
        SnackbarHelper.showError(
          context,
          'Nao foi possivel salvar ou sincronizar o Notion.',
        );
      }
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _testConnection() async {
    final token = _tokenController.text.trim();
    final databaseId = _databaseController.text.trim();
    if (token.isEmpty || databaseId.isEmpty) {
      SnackbarHelper.showWarning(
        context,
        'Preencha Token e Database ID primeiro.',
      );
      return;
    }

    setState(() => _isWorking = true);
    try {
      final ok = await NotionService().testConnection(token, databaseId);
      if (!mounted) return;
      if (ok) {
        AppHaptics.success();
        SnackbarHelper.showSuccess(context, 'Conexao com o Notion validada.');
      } else {
        SnackbarHelper.showError(context, 'Falha na conexao com o Notion.');
      }
    } catch (e) {
      debugPrint('[NotionConnectionSheet] Connection test failed: $e');
      if (mounted) {
        SnackbarHelper.showError(
          context,
          'Erro ao testar conexao com o Notion.',
        );
      }
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _disconnect() async {
    if (_isWorking) return;
    final settings = context.read<SettingsProvider>();
    final logs = context.read<StudyLogProvider>();
    setState(() => _isWorking = true);
    try {
      await AppHaptics.warning();
      await settings.disconnectNotion();
      if (!mounted) return;
      await logs.clearCachedSchema();
      _tokenController.clear();
      _databaseController.clear();
      if (!mounted) return;
      SnackbarHelper.showInfo(
        context,
        'Notion desconectado. Dados locais preservados.',
      );
    } catch (e) {
      debugPrint('[NotionConnectionSheet] Disconnect failed: $e');
      if (mounted) {
        SnackbarHelper.showError(
          context,
          'Nao foi possivel desconectar o Notion.',
        );
      }
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }
}

class _CredentialLoadWarning extends StatelessWidget {
  final String? message;
  final VoidCallback onRetry;

  const _CredentialLoadWarning({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return AppSurface.subtle(
      padding: EdgeInsets.all(context.spacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: context.colors.warning),
          SizedBox(width: context.spacing.sm),
          Expanded(
            child: Text(
              message ?? 'Nao foi possivel carregar as credenciais salvas.',
              style: context.theme.textTheme.bodySmall,
            ),
          ),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Recarregar'),
          ),
        ],
      ),
    );
  }
}

class _CredentialHelper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppSurface.subtle(
      padding: EdgeInsets.all(context.spacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: context.colors.accent),
          SizedBox(width: context.spacing.sm),
          Expanded(
            child: Text(
              'Informe o token da integracao e o Database ID para testar ou salvar a conexao.',
              style: context.theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
