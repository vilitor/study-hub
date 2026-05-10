import 'package:flutter/material.dart';
import 'package:study_hub/config/app_theme.dart';

/// Screen that explains how user data is handled (LGPD Compliance)
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacidade e segurança')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.security_rounded,
              size: 64,
              color: AppColors.primaryGreen,
            ),
            const SizedBox(height: 24),
            Text(
              'Sua privacidade é prioridade',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            Text(
              'O StudyHub foi projetado com transparência e segurança. Esta tela explica como suas informações são tratadas de acordo com boas práticas de proteção de dados.',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
            const SizedBox(height: 32),
            _buildSection(
              context,
              icon: Icons.storage_rounded,
              title: 'Armazenamento local',
              content:
                  'Seus registros de estudo e eventos da agenda ficam armazenados localmente no dispositivo. O app não mantém um banco central para monitorar seus hábitos de estudo.',
            ),
            _buildSection(
              context,
              icon: Icons.phonelink_lock_rounded,
              title: 'Credenciais seguras',
              content:
                  'Dados sensíveis, como o token do Notion, são criptografados e armazenados com armazenamento seguro do dispositivo.',
            ),
            _buildSection(
              context,
              icon: Icons.sync_rounded,
              title: 'Integrações transparentes',
              content:
                  'Os dados só são enviados ao Notion ou Google Calendar quando você autoriza e inicia uma sincronização.',
            ),
            _buildSection(
              context,
              icon: Icons.no_accounts_rounded,
              title: 'Sem venda de dados',
              content:
                  'O app não coleta, vende ou compartilha seus dados com anunciantes. Seus dados pertencem a você.',
            ),
            const SizedBox(height: 40),
            Center(
              child: Text(
                'v1.0.0 • Arquitetura compatível com a LGPD',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textHint),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primaryGreen, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
