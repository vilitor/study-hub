import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:study_hub/config/app_routes.dart';
import 'package:study_hub/config/app_theme.dart';
import 'package:study_hub/models/auth_session.dart';
import 'package:study_hub/models/cloud_sync.dart';
import 'package:study_hub/providers/auth_session_provider.dart';
import 'package:study_hub/providers/contextual_guide_provider.dart';
import 'package:study_hub/providers/onboarding_provider.dart';
import 'package:study_hub/providers/settings_provider.dart';
import 'package:study_hub/providers/update_provider.dart';
import 'package:study_hub/screens/settings/privacy_policy_screen.dart';
import 'package:study_hub/services/app_account_deletion_service.dart';
import 'package:study_hub/services/app_haptics.dart';
import 'package:study_hub/services/cloud_sync_service.dart';
import 'package:study_hub/utils/snackbar_helper.dart';
import 'package:study_hub/widgets/app_modal.dart';
import 'package:study_hub/widgets/app_surface.dart';
import 'package:study_hub/widgets/custom_button.dart';
import 'package:study_hub/widgets/integration_button.dart';
import 'package:study_hub/widgets/local_table_schema_sheet.dart';
import 'package:study_hub/widgets/notion_connection_sheet.dart';
import 'package:study_hub/widgets/update_available_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AppAccountDeletionService _accountDeletion =
      AppAccountDeletionService();
  bool _isDeletingAccount = false;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          AuthSessionProvider? auth;
          try {
            auth = context.watch<AuthSessionProvider>();
          } on ProviderNotFoundException {
            auth = null;
          }

          CloudSyncState syncState = const CloudSyncState();
          try {
            syncState = context.watch<CloudSyncService>().state;
          } on ProviderNotFoundException {
            syncState = const CloudSyncState();
          }

          UpdateProvider? updates;
          try {
            updates = context.watch<UpdateProvider>();
          } on ProviderNotFoundException {
            updates = null;
          }

          final googleConnected =
              settings.isGoogleConnected || (auth?.isSignedIn ?? false);
          final googleEmail = auth?.email ?? settings.settings.googleEmail;
          final pendingSync = auth?.pendingSyncCount ?? 0;
          final googleSubtitle = googleConnected
              ? 'Firebase e Calendar: $googleEmail${pendingSync > 0 ? ' | $pendingSync pendente(s)' : ''}'
              : 'Entrar para backup Firebase e sincronizar Calendar.';

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              spacing.screenPadding,
              spacing.lg,
              spacing.screenPadding,
              140,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppSectionHeader(
                  title: 'Integrações',
                  subtitle:
                      'Gerencie Google Calendar e Notion sem poluir o app.',
                ),
                SizedBox(height: spacing.md),
                IntegrationButton(
                  mark: const GoogleBrandMark(),
                  title: 'Google Calendar',
                  subtitle: googleSubtitle,
                  isConnected: googleConnected,
                  isLoading:
                      settings.isLoading ||
                      auth?.status == AuthSessionStatus.signingIn,
                  accentColor: const Color(0xFF4285F4),
                  onTap: () => _handleGoogle(context, settings, auth),
                ),
                if (googleConnected) ...[
                  SizedBox(height: spacing.sm),
                  _CloudSyncStatusTile(syncState: syncState),
                ],
                SizedBox(height: spacing.sm),
                IntegrationButton(
                  mark: const NotionBrandMark(),
                  title: 'Notion',
                  subtitle: settings.isNotionConnected
                      ? 'Tabela conectada. Sync por registro.'
                      : 'Opcional: conecte para sincronizar registros.',
                  isConnected: settings.isNotionConnected,
                  accentColor: context.colors.textPrimary,
                  onTap: () => NotionConnectionSheet.show(context),
                ),
                SizedBox(height: spacing.sm),
                IntegrationButton(
                  mark: Icon(
                    Icons.table_chart_rounded,
                    color: context.colors.accent,
                  ),
                  title: 'Tabela local',
                  subtitle: 'Editar campos usados nos registros locais.',
                  isConnected: true,
                  accentColor: context.colors.accent,
                  onTap: () => LocalTableSchemaSheet.show(context),
                ),
                SizedBox(height: spacing.sectionGap),
                const AppSectionHeader(
                  title: 'Atalhos',
                  subtitle: 'Acesse dados importantes rapidamente.',
                ),
                SizedBox(height: spacing.md),
                AppSurface(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.history_rounded,
                      color: context.colors.accent,
                    ),
                    title: const Text('Histórico de registros'),
                    subtitle: const Text(
                      'Ver, editar notas e excluir registros.',
                    ),
                    trailing: const Icon(Icons.arrow_forward_rounded),
                    onTap: () {
                      AppHaptics.selection();
                      Navigator.pushNamed(context, AppRoutes.history);
                    },
                  ),
                ),
                SizedBox(height: spacing.sm),
                AppSurface(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.tips_and_updates_rounded,
                      color: context.colors.accentSecondary,
                    ),
                    title: const Text('Rever guia rápido'),
                    subtitle: const Text(
                      'Mostra novamente orientações contextuais do app.',
                    ),
                    trailing: const Icon(Icons.replay_rounded),
                    onTap: () async {
                      AppHaptics.selection();
                      await context
                          .read<OnboardingProvider>()
                          .replayContextualGuide();
                      if (!context.mounted) return;
                      context.read<ContextualGuideProvider>().reset();
                      SnackbarHelper.showSuccess(
                        context,
                        'Guia rápido reativado.',
                      );
                    },
                  ),
                ),
                SizedBox(height: spacing.sectionGap),
                const AppSectionHeader(
                  title: 'Tema',
                  subtitle: 'Alterne entre claro e escuro.',
                ),
                SizedBox(height: spacing.md),
                AppSurface(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          settings.themeMode == 'dark'
                              ? 'Modo escuro'
                              : 'Modo claro',
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          AppHaptics.selection();
                          settings.setThemeMode(
                            settings.themeMode == 'dark' ? 'light' : 'dark',
                          );
                        },
                        icon: Icon(
                          settings.themeMode == 'dark'
                              ? Icons.light_mode_rounded
                              : Icons.dark_mode_rounded,
                        ),
                      ),
                    ],
                  ),
                ),
                if (updates != null) ...[
                  SizedBox(height: spacing.sectionGap),
                  const AppSectionHeader(
                    title: 'Atualizações',
                    subtitle: 'Verifique novas versões do StudyHub.',
                  ),
                  SizedBox(height: spacing.md),
                  AppSurface(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.system_update_alt_rounded,
                        color: context.colors.accent,
                      ),
                      title: const Text('Verificar atualizações'),
                      subtitle: Text(
                        'Instalada: ${updates.installedVersionLabel} | ${updates.statusLabel}',
                      ),
                      trailing: updates.isChecking
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: context.colors.accent,
                              ),
                            )
                          : const Icon(Icons.refresh_rounded),
                      onTap: updates.isChecking || updates.isDownloading
                          ? null
                          : () => _handleManualUpdateCheck(context, updates!),
                    ),
                  ),
                ],
                SizedBox(height: spacing.sectionGap),
                AppSurface(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.delete_forever_rounded,
                      color: context.colors.error,
                    ),
                    title: const Text('Excluir conta do app'),
                    subtitle: const Text(
                      'Remove os dados do Study Hub neste dispositivo e, quando houver login, também no backup Firebase.',
                    ),
                    trailing: _isDeletingAccount
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: context.colors.error,
                            ),
                          )
                        : const Icon(Icons.arrow_forward_rounded),
                    onTap: _isDeletingAccount
                        ? null
                        : () => _showDeleteAccountFlow(context, auth),
                  ),
                ),
                SizedBox(height: spacing.sm),
                AppSurface(
                  child: Column(
                    children: [
                      TextButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const PrivacyPolicyScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.privacy_tip_rounded),
                        label: const Text('Privacidade e segurança dos dados'),
                      ),
                      SizedBox(height: spacing.sm),
                      Text(
                        updates == null
                            ? 'StudyHub'
                            : 'StudyHub v${updates.installedVersionLabel}',
                        style: context.theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleManualUpdateCheck(
    BuildContext context,
    UpdateProvider updates,
  ) async {
    AppHaptics.selection();
    final hasUpdate = await updates.checkForUpdate(manual: true);
    if (!context.mounted) return;

    if (hasUpdate) {
      await UpdateAvailableDialog.show(context);
      return;
    }

    if (updates.status == UpdateStatus.upToDate) {
      SnackbarHelper.showSuccess(context, 'StudyHub já está atualizado.');
    } else {
      SnackbarHelper.showError(
        context,
        updates.errorMessage ?? 'Não foi possível verificar atualizações.',
      );
    }
  }

  Future<void> _showDeleteAccountFlow(
    BuildContext context,
    AuthSessionProvider? auth,
  ) async {
    AppHaptics.warning();
    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Excluir conta do app?'),
          content: const Text(
            'Esta ação excluirá os dados da sua conta no Study Hub. Ela não exclui sua Conta Google, sua conta Notion nem eventos externos do Google Calendar.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Continuar'),
            ),
          ],
        );
      },
    );
    if (proceed != true || !context.mounted) return;

    final confirmed = await _showFinalDeleteConfirmation(context);
    if (confirmed != true || !context.mounted) return;

    setState(() => _isDeletingAccount = true);
    try {
      await _accountDeletion.deleteAppAccount(
        isGuest: auth?.isGuest ?? true,
        uid: auth?.uid,
      );
      await auth?.resetAfterAccountDeletion();
      if (!context.mounted) return;
      await context.read<SettingsProvider>().loadSettings();
      if (!context.mounted) return;
      SnackbarHelper.showSuccess(context, 'Conta do app excluída.');
    } catch (e) {
      if (!context.mounted) return;
      SnackbarHelper.showError(
        context,
        'Não foi possível excluir a conta do app. Verifique a conexão e tente novamente.',
      );
    } finally {
      if (mounted) setState(() => _isDeletingAccount = false);
    }
  }

  Future<bool?> _showFinalDeleteConfirmation(BuildContext context) {
    var typed = '';
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final canDelete = typed.trim().toUpperCase() == 'EXCLUIR';
            return AlertDialog(
              title: const Text('Confirmação necessária'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Para confirmar, digite EXCLUIR. Dados sincronizados do Study Hub podem ser removidos do Firebase.',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Digite EXCLUIR',
                    ),
                    onChanged: (value) => setDialogState(() => typed = value),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: canDelete
                      ? () => Navigator.pop(dialogContext, true)
                      : null,
                  child: const Text('Excluir conta do app'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _handleGoogle(
    BuildContext context,
    SettingsProvider settings,
    AuthSessionProvider? auth,
  ) async {
    if (settings.isGoogleConnected || (auth?.isSignedIn ?? false)) {
      await _showGoogleManageSheet(context, settings, auth);
      return;
    }

    try {
      bool success;
      if (auth == null) {
        await settings.connectGoogle();
        success = settings.isGoogleConnected;
      } else {
        success = await auth.signInWithGoogle();
      }
      if (!context.mounted) return;

      if (success) {
        if (auth != null && auth.email != null) {
          await settings.setGoogleConnected(
            auth.email!,
            auth.displayName ?? '',
            auth.photoUrl ?? '',
          );
          if (!context.mounted) return;
        }
        AppHaptics.success();
        SnackbarHelper.showSuccess(context, 'Conectado com sucesso.');
      } else if (auth?.lastDiagnostic != null) {
        SnackbarHelper.showError(context, auth!.lastDiagnostic!.message);
      }
    } catch (_) {
      if (context.mounted) {
        SnackbarHelper.showError(context, 'Erro ao conectar com Google.');
      }
    }
  }

  Future<void> _showGoogleManageSheet(
    BuildContext context,
    SettingsProvider settings,
    AuthSessionProvider? auth,
  ) async {
    AppHaptics.selection();
    await AppModal.showSheet<void>(
      context: context,
      builder: (sheetContext) {
        return AppSurface(
          color: sheetContext.colors.modalSurface,
          shadow: sheetContext.elevations.high,
          padding: EdgeInsets.all(sheetContext.spacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSectionHeader(
                title: 'Google Calendar',
                subtitle:
                    auth?.email ??
                    settings.settings.googleEmail ??
                    'Conta Google conectada.',
                trailing: IconButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
              SizedBox(height: sheetContext.spacing.lg),
              IntegrationButton(
                mark: const GoogleBrandMark(),
                title: 'Eventos sincronizados',
                subtitle:
                    'Backup Firebase ativo. Novos eventos continuam usando Google Calendar.',
                isConnected: true,
                accentColor: const Color(0xFF4285F4),
                onTap: null,
              ),
              SizedBox(height: sheetContext.spacing.lg),
              CustomButton(
                label: 'Desconectar Google',
                icon: Icons.logout_rounded,
                isOutlined: true,
                color: sheetContext.colors.error,
                onPressed: () async {
                  await AppHaptics.warning();
                  if (auth != null) {
                    await auth.signOut(keepGuestMode: false);
                  }
                  await settings.disconnectGoogle();
                  if (!sheetContext.mounted) return;
                  Navigator.pop(sheetContext);
                  if (context.mounted) {
                    SnackbarHelper.showInfo(context, 'Google desconectado.');
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CloudSyncStatusTile extends StatelessWidget {
  final CloudSyncState syncState;

  const _CloudSyncStatusTile({required this.syncState});

  @override
  Widget build(BuildContext context) {
    final subtitle = switch (syncState.phase) {
      CloudSyncPhase.syncing => 'Sincronizando backup Firebase...',
      CloudSyncPhase.offline =>
        'Modo offline ativo. ${syncState.pendingCount} alteração(ões) pendente(s).',
      CloudSyncPhase.timeout =>
        'Sync demorou demais. O app continua funcionando localmente.',
      CloudSyncPhase.error =>
        'Falha no sync. ${syncState.pendingCount} item(ns) pendente(s).',
      CloudSyncPhase.pending =>
        '${syncState.pendingCount} alteração(ões) aguardando envio.',
      _ when syncState.pendingCount > 0 =>
        '${syncState.pendingCount} item(ns) aguardando conexão.',
      _ when syncState.lastSyncedAt != null =>
        'Último backup: ${_formatLastSync(syncState.lastSyncedAt!)}',
      _ => 'Backup Firebase pronto para restaurar seus dados.',
    };

    final icon = switch (syncState.phase) {
      CloudSyncPhase.syncing => Icons.sync_rounded,
      CloudSyncPhase.offline => Icons.wifi_off_rounded,
      CloudSyncPhase.timeout => Icons.schedule_rounded,
      CloudSyncPhase.error => Icons.cloud_off_rounded,
      CloudSyncPhase.pending => Icons.cloud_queue_rounded,
      _ when syncState.pendingCount > 0 => Icons.cloud_queue_rounded,
      _ => Icons.cloud_done_rounded,
    };

    return AppSurface.subtle(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: context.colors.accent),
        title: const Text('Backup na nuvem'),
        subtitle: Text(subtitle),
        trailing: syncState.phase == CloudSyncPhase.syncing
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.colors.accent,
                ),
              )
            : IconButton(
                tooltip: 'Sincronizar agora',
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () => CloudSyncService.instance.synchronize(),
              ),
      ),
    );
  }

  String _formatLastSync(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.day}/${local.month}/${local.year} $hour:$minute';
  }
}
