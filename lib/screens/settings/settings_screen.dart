import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:study_hub/config/app_theme.dart';
import 'package:study_hub/providers/settings_provider.dart';
import 'package:study_hub/providers/study_log_provider.dart';
import 'package:study_hub/widgets/custom_button.dart';
import 'package:study_hub/widgets/custom_text_field.dart';
import 'package:study_hub/utils/validators.dart';
import 'package:study_hub/utils/snackbar_helper.dart';
import 'package:study_hub/services/notion_service.dart';
import 'package:study_hub/screens/settings/privacy_policy_screen.dart';

/// Tela: Configurações
/// Conectar Google, configurar Notion, visualizar status das integrações
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _notionTokenController = TextEditingController();
  final _notionDbIdController = TextEditingController();

  @override
  void dispose() {
    _notionTokenController.dispose();
    _notionDbIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Status das integrações ──
                Text(
                  'Status das Integrações',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                _buildStatusCard(
                  icon: Icons.event_rounded,
                  title: 'Google Calendar',
                  subtitle: settings.isGoogleConnected
                      ? 'Conectado: ${settings.settings.googleEmail}'
                      : 'Não conectado',
                  isConnected: settings.isGoogleConnected,
                ),
                const SizedBox(height: 8),
                _buildStatusCard(
                  icon: Icons.storage_rounded,
                  title: 'Notion',
                  subtitle: settings.isNotionConnected
                      ? 'Conectado ao database'
                      : 'Não conectado',
                  isConnected: settings.isNotionConnected,
                ),

                const SizedBox(height: 32),

                // ── Seção Google ──
                Text(
                  'Google Calendar',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Conecte sua conta Google para sincronizar eventos de estudo com seu calendário.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                CustomButton(
                  label: settings.isGoogleConnected
                      ? 'Desconectar Google'
                      : 'Conectar com Google',
                  icon: settings.isGoogleConnected
                      ? Icons.logout_rounded
                      : Icons.login_rounded,
                  color: settings.isGoogleConnected
                      ? AppColors.error
                      : AppColors.primaryGreen,
                  isLoading: settings.isLoading,
                  onPressed: () async {
                    if (settings.isGoogleConnected) {
                      await settings.disconnectGoogle();
                      if (context.mounted) {
                        SnackbarHelper.showInfo(context, 'Google desconectado');
                      }
                    } else {
                      try {
                        await settings.connectGoogle();
                        if (context.mounted && settings.isGoogleConnected) {
                          SnackbarHelper.showSuccess(context, 'Conectado com sucesso! ✅');
                        }
                      } catch (e) {
                        if (context.mounted) {
                          SnackbarHelper.showError(context, 'Erro ao conectar. Tente novamente.');
                        }
                      }
                    }
                  },
                ),

                const SizedBox(height: 32),

                // ── Seção Notion ──
                Text(
                  'Notion',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Insira o token da sua integração e o ID do database para salvar registros de aprendizado no Notion.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),

                CustomTextField(
                  label: 'Token de Integração',
                  hint: 'ntn_xxxxxxxxxxxx...',
                  prefixIcon: Icons.key_rounded,
                  controller: _notionTokenController,
                  validator: Validators.notionToken,
                  obscureText: true,
                ),

                const SizedBox(height: 16),

                CustomTextField(
                  label: 'Database ID',
                  hint: 'ID do database (32 caracteres)',
                  prefixIcon: Icons.storage_rounded,
                  controller: _notionDbIdController,
                  validator: Validators.notionDatabaseId,
                ),

                const SizedBox(height: 16),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CustomButton(
                      label: 'Salvar',
                      icon: Icons.save_rounded,
                      onPressed: () => _saveNotionConfig(settings),
                    ),
                    if (settings.isNotionConnected) ...[
                      const SizedBox(height: 12),
                      CustomButton(
                        label: 'Desconectar',
                        icon: Icons.link_off_rounded,
                        isOutlined: true,
                        color: AppColors.error,
                        onPressed: () {
                          settings.disconnectNotion();
                          _notionTokenController.clear();
                          _notionDbIdController.clear();
                          SnackbarHelper.showInfo(
                              context, 'Notion desconectado');
                        },
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 16),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CustomButton(
                      label: 'Sincronizar Tabela',
                      icon: Icons.sync_rounded,
                      isOutlined: false,
                      color: AppColors.primaryGreen,
                      onPressed: () async {
                        final provider = context.read<StudyLogProvider>();
                        final success = await provider.syncSchemaFromNotion();
                        if (context.mounted) {
                          if (success) {
                            SnackbarHelper.showSuccess(context, 'Estrutura atualizada e cacheada com sucesso! ✅');
                          } else {
                            SnackbarHelper.showError(context, 'Falha ao sincronizar estrutura.');
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    CustomButton(
                      label: 'Testar Conexão Notion',
                      icon: Icons.wifi_tethering_rounded,
                      isOutlined: true,
                      color: AppColors.purple,
                      onPressed: () async {
                        if (_notionTokenController.text.isEmpty || _notionDbIdController.text.isEmpty) {
                          SnackbarHelper.showWarning(context, 'Preencha o Token e o Database ID primeiro');
                          return;
                        }
                        
                        final notionService = NotionService();
                        final isOk = await notionService.testConnection(
                          _notionTokenController.text.trim(),
                          _notionDbIdController.text.trim(),
                        );
                        
                        if (context.mounted) {
                          if (isOk) {
                            SnackbarHelper.showSuccess(context, 'Conexão perfeita! Database acessível. 🚀');
                          } else {
                            SnackbarHelper.showError(context, 'Falha na conexão. Verifique suas chaves e se a Integração foi adicionada ao Database.');
                          }
                        }
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // ── Sobre o app ──
                Center(
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      TextButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PrivacyPolicyScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.privacy_tip_rounded, size: 20),
                        label: const Text('Data Privacy & Security (LGPD)'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primaryGreen,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'StudyHub v1.0.0',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textHint,
                            ),
                      ),
                      Text(
                        'Feito com 💚 para organizar seus estudos',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textHint,
                            ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Card de status de integração
  Widget _buildStatusCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isConnected,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isConnected
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.cardGrey,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isConnected
                  ? AppColors.success.withValues(alpha: 0.1)
                  : AppColors.cardGrey,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: isConnected ? AppColors.success : AppColors.textHint,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Icon(
            isConnected
                ? Icons.check_circle_rounded
                : Icons.cancel_rounded,
            color: isConnected ? AppColors.success : AppColors.textHint,
            size: 24,
          ),
        ],
      ),
    );
  }

  void _saveNotionConfig(SettingsProvider settings) {
    final tokenError = Validators.notionToken(_notionTokenController.text);
    final dbError = Validators.notionDatabaseId(_notionDbIdController.text);

    if (tokenError != null) {
      SnackbarHelper.showError(context, tokenError);
      return;
    }
    if (dbError != null) {
      SnackbarHelper.showError(context, dbError);
      return;
    }

    settings.saveNotionCredentials(
      _notionTokenController.text.trim(),
      _notionDbIdController.text.trim(),
    );

    SnackbarHelper.showSuccess(context, 'Notion configurado com sucesso! ✅');
  }
}
