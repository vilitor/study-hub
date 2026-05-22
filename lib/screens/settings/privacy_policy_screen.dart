import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:study_hub/config/app_theme.dart';
import 'package:study_hub/models/cloud_sync.dart';
import 'package:study_hub/providers/ai_assistant_provider.dart';
import 'package:study_hub/providers/settings_provider.dart';
import 'package:study_hub/services/cloud_sync_service.dart';
import 'package:study_hub/services/data_export_service.dart';
import 'package:study_hub/utils/snackbar_helper.dart';
import 'package:study_hub/widgets/app_surface.dart';

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  final DataExportService _exportService = DataExportService();
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final settings = context.watch<SettingsProvider>();
    final syncState = context.watch<CloudSyncService>().state;

    return Scaffold(
      appBar: AppBar(title: const Text('Privacidade e dados')),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          spacing.screenPadding,
          spacing.lg,
          spacing.screenPadding,
          spacing.sectionGap,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppSectionHeader(
              title: 'Controle dos seus dados',
              subtitle:
                  'O Study Hub é local-first: você controla o que fica no dispositivo, o que vai para o Firebase e quais integrações externas são usadas.',
            ),
            SizedBox(height: spacing.lg),
            _InfoTile(
              icon: Icons.phone_android_rounded,
              title: 'Armazenamento local',
              body:
                  'Registros, eventos, metas, certificados, configuração da plataforma e preferências da conta ficam salvos primeiro neste dispositivo.',
            ),
            _InfoTile(
              icon: Icons.cloud_done_rounded,
              title: 'Backup Firebase',
              body:
                  'Quando você entra com Google, o backup grava apenas dados do app em users/{uid}. A conta visitante permanece local.',
              trailing: Text(_syncLabel(syncState)),
            ),
            _InfoTile(
              icon: Icons.event_available_rounded,
              title: 'Google Calendar',
              body:
                  'O app solicita acesso somente a eventos do calendário para criar, atualizar ou excluir eventos que você sincronizar.',
            ),
            _InfoTile(
              icon: Icons.table_chart_rounded,
              title: 'Notion',
              body:
                  'O token do Notion fica no armazenamento seguro do dispositivo. O app usa esse token apenas quando você conecta e sincroniza uma tabela.',
            ),
            _InfoTile(
              icon: Icons.auto_awesome_rounded,
              title: 'Luma local-first',
              body:
                  'A Luma V1 não usa API externa de IA. As respostas são geradas localmente a partir dos dados do app, quando a personalização está ativa.',
            ),
            SizedBox(height: spacing.sectionGap),
            AppSurface(
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: settings.settings.lumaPersonalizationEnabled,
                title: const Text('Personalização da Luma'),
                subtitle: const Text(
                  'Permitir que a Luma use dados locais da conta para sugestões e buscas dentro do app.',
                ),
                onChanged: (value) async {
                  await settings.setLumaPersonalizationEnabled(value);
                  if (!context.mounted) return;
                  if (!value) {
                    context.read<AiAssistantProvider>().resetForAccount();
                  }
                  SnackbarHelper.showInfo(
                    context,
                    value
                        ? 'Personalização da Luma ativada.'
                        : 'Personalização da Luma desativada.',
                  );
                },
              ),
            ),
            SizedBox(height: spacing.sm),
            AppSurface(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.cleaning_services_rounded,
                  color: context.colors.accent,
                ),
                title: const Text('Limpar memória da Luma'),
                subtitle: const Text(
                  'Apaga a conversa local atual da Luma. Seus registros, metas e eventos não são removidos.',
                ),
                trailing: const Icon(Icons.refresh_rounded),
                onTap: () {
                  context.read<AiAssistantProvider>().resetForAccount();
                  SnackbarHelper.showSuccess(
                    context,
                    'Memória local da Luma limpa.',
                  );
                },
              ),
            ),
            SizedBox(height: spacing.sm),
            AppSurface(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.download_rounded,
                  color: context.colors.accentSecondary,
                ),
                title: const Text('Exportar meus dados'),
                subtitle: const Text(
                  'Gera um arquivo JSON local com registros, metas, eventos, certificados e configurações da conta ativa.',
                ),
                trailing: _isExporting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.arrow_forward_rounded),
                onTap: _isExporting ? null : _exportData,
              ),
            ),
            SizedBox(height: spacing.sectionGap),
            const AppSectionHeader(
              title: 'Direitos e transparência',
              subtitle:
                  'Você pode exportar dados, excluir a conta do app e desconectar integrações. A exclusão não remove sua Conta Google, conta Notion nem eventos externos do Calendar.',
            ),
            SizedBox(height: spacing.md),
            _PolicyText(),
          ],
        ),
      ),
    );
  }

  Future<void> _exportData() async {
    setState(() => _isExporting = true);
    try {
      final result = await _exportService.exportActiveAccountData();
      if (!mounted) return;
      SnackbarHelper.showSuccess(
        context,
        'Exportação concluída: ${result.filePath}',
      );
    } catch (_) {
      if (!mounted) return;
      SnackbarHelper.showError(
        context,
        'Não foi possível exportar os dados agora.',
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  String _syncLabel(CloudSyncState syncState) {
    if (syncState.lastSyncedAt != null) {
      return 'Backup ativo';
    }
    if (syncState.pendingCount > 0) {
      return '${syncState.pendingCount} pendente(s)';
    }
    return 'Local-first';
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Widget? trailing;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.body,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.spacing.sm),
      child: AppSurface.subtle(
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon, color: context.colors.accent),
          title: Text(title),
          subtitle: Text(body),
          trailing: trailing,
        ),
      ),
    );
  }
}

class _PolicyText extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text(
      'Política resumida: o Study Hub coleta apenas os dados necessários para organizar sua rotina de estudos e operar integrações escolhidas por você. Dados autenticados são gravados em uma área própria do usuário no Firebase. Dados de visitante ficam no dispositivo. Tokens e credenciais não são exibidos em logs. Para a versão pública, publique a Política de Privacidade e os Termos de Uso em um domínio do app e use esses links na tela de consentimento OAuth.',
      style: context.theme.textTheme.bodyMedium,
    );
  }
}
