import 'package:flutter/material.dart';
import 'package:study_hub/config/app_theme.dart';

/// Screen that explains how user data is handled (LGPD Compliance)
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Privacy & Security'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.security_rounded, size: 64, color: AppColors.primaryGreen),
            const SizedBox(height: 24),
            Text(
              'Your Privacy is Our Priority',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            const Text(
              'StudyHub is designed with transparency and security in mind. This screen explains how we handle your information in accordance with Data Protection best practices.',
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 32),
            _buildSection(
              context,
              icon: Icons.storage_rounded,
              title: 'Local Storage',
              content: 'All your study logs and agenda events are stored locally on your device. We do not have a central database that monitors your study habits.',
            ),
            _buildSection(
              context,
              icon: Icons.phonelink_lock_rounded,
              title: 'Secure Credentials',
              content: 'Sensitive data such as your Notion Token is encrypted and stored using hardware-backed secure storage (Flutter Secure Storage).',
            ),
            _buildSection(
              context,
              icon: Icons.sync_rounded,
              title: 'Integration Transparency',
              content: 'Data is only transmitted to third-party services (Notion and Google Calendar) when you explicitly authorize and trigger a synchronization.',
            ),
            _buildSection(
              context,
              icon: Icons.no_accounts_rounded,
              title: 'No Data Selling',
              content: 'We do not collect, sell, or share your data with advertisers or any other third parties. Your data belongs entirely to you.',
            ),
            const SizedBox(height: 40),
            Center(
              child: Text(
                'v1.0.0 • LGPD Compliant Architecture',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textHint),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, {required IconData icon, required String title, required String content}) {
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
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
