import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:study_hub/config/app_routes.dart';
import 'package:study_hub/config/app_theme.dart';
import 'package:study_hub/models/auth_session.dart';
import 'package:study_hub/models/cloud_sync.dart';
import 'package:study_hub/providers/auth_session_provider.dart';
import 'package:study_hub/providers/settings_provider.dart';
import 'package:study_hub/screens/settings/privacy_policy_screen.dart';
import 'package:study_hub/services/app_haptics.dart';
import 'package:study_hub/services/cloud_sync_service.dart';
import 'package:study_hub/utils/snackbar_helper.dart';
import 'package:study_hub/widgets/app_modal.dart';
import 'package:study_hub/widgets/app_surface.dart';
import 'package:study_hub/widgets/custom_button.dart';
import 'package:study_hub/widgets/integration_button.dart';
import 'package:study_hub/widgets/local_table_schema_sheet.dart';
import 'package:study_hub/widgets/notion_connection_sheet.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuracoes'),
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
                  title: 'Integracoes',
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
                    title: const Text('Historico de registros'),
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
                SizedBox(height: spacing.sectionGap),
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
                        label: const Text('Privacidade e seguranca dos dados'),
                      ),
                      SizedBox(height: spacing.sm),
                      Text(
                        'StudyHub v1.1.0',
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
        'Modo offline ativo. ${syncState.pendingCount} alteracao(oes) pendente(s).',
      CloudSyncPhase.timeout =>
        'Sync demorou demais. O app continua funcionando localmente.',
      CloudSyncPhase.error =>
        'Falha no sync. ${syncState.pendingCount} item(ns) pendente(s).',
      CloudSyncPhase.pending =>
        '${syncState.pendingCount} alteracao(oes) aguardando envio.',
      _ when syncState.pendingCount > 0 =>
        '${syncState.pendingCount} item(ns) aguardando conexao.',
      _ when syncState.lastSyncedAt != null =>
        'Ultimo backup: ${_formatLastSync(syncState.lastSyncedAt!)}',
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
