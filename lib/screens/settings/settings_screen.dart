import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:study_hub/config/app_routes.dart';
import 'package:study_hub/config/app_theme.dart';
import 'package:study_hub/models/auth_session.dart';
import 'package:study_hub/providers/auth_session_provider.dart';
import 'package:study_hub/providers/settings_provider.dart';
import 'package:study_hub/screens/settings/privacy_policy_screen.dart';
import 'package:study_hub/services/app_haptics.dart';
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
                    await auth.signOut();
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
