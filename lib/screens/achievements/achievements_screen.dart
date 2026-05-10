import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:study_hub/config/app_theme.dart';
import 'package:study_hub/models/certificate.dart';
import 'package:study_hub/providers/certificate_provider.dart';
import 'package:study_hub/providers/goal_provider.dart';
import 'package:study_hub/providers/study_log_provider.dart';
import 'package:study_hub/services/app_haptics.dart';
import 'package:study_hub/utils/date_helpers.dart';
import 'package:study_hub/utils/snackbar_helper.dart';
import 'package:study_hub/widgets/app_modal.dart';
import 'package:study_hub/widgets/app_surface.dart';
import 'package:study_hub/widgets/certificate_widgets.dart';
import 'package:study_hub/widgets/custom_button.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conquistas'),
        leading: Navigator.canPop(context)
            ? IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded),
              )
            : null,
        actions: [
          IconButton(
            tooltip: 'Novo certificado',
            onPressed: () => _showCertificateForm(context),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: Consumer3<CertificateProvider, StudyLogProvider, GoalProvider>(
        builder: (context, certificates, logs, goals, _) {
          final totalStudyMinutes = logs.logs.fold<int>(
            0,
            (sum, log) => sum + log.studyTimeMinutes,
          );
          final completedGoals = _completedGoals(goals, logs);
          final progress = certificates.progressFor(
            totalStudyMinutes: totalStudyMinutes,
            currentStreak: logs.currentStreak,
            completedGoals: completedGoals,
          );

          return SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                spacing.screenPadding,
                spacing.lg,
                spacing.screenPadding,
                140 + MediaQuery.of(context).padding.bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AchievementProgressCard(
                    progress: progress,
                    certificateCount: certificates.totalCertificates,
                    trustedCount: certificates.trustedCertificates,
                    totalStudyMinutes: totalStudyMinutes,
                  ),
                  SizedBox(height: spacing.sectionGap),
                  _AchievementStatsRow(
                    certificateCount: certificates.totalCertificates,
                    trustedCount: certificates.trustedCertificates,
                    completedGoals: completedGoals,
                    streak: logs.currentStreak,
                  ),
                  SizedBox(height: spacing.sectionGap),
                  _CertificateToolbar(provider: certificates),
                  SizedBox(height: spacing.md),
                  if (certificates.lastError != null) ...[
                    _ErrorBanner(
                      message: certificates.lastError!,
                      onDismiss: certificates.clearError,
                    ),
                    SizedBox(height: spacing.md),
                  ],
                  if (certificates.isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (certificates.visibleCertificates.isEmpty)
                    _EmptyCertificates(
                      onAdd: () => _showCertificateForm(context),
                    )
                  else
                    ...certificates.visibleCertificates.map(
                      (certificate) => Padding(
                        padding: EdgeInsets.only(bottom: spacing.sm),
                        child: CertificateCard(
                          certificate: certificate,
                          onTap: () => _showDetails(context, certificate),
                          onLongPress: () =>
                              _showCertificateActions(context, certificate),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCertificateForm(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Certificado'),
      ),
    );
  }

  static int _completedGoals(GoalProvider goals, StudyLogProvider logs) {
    return goals.goals.where((goal) {
      return goals.calculateProgress(goal, logs.logs) >= 1;
    }).length;
  }

  static Future<void> _showCertificateForm(
    BuildContext context, {
    Certificate? certificate,
  }) async {
    AppHaptics.selection();
    await AppModal.showSheet<void>(
      context: context,
      builder: (_) => CertificateFormSheet(certificate: certificate),
    );
  }

  static Future<void> _showCertificateActions(
    BuildContext context,
    Certificate certificate,
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
            children: [
              _ActionTile(
                icon: Icons.visibility_rounded,
                title: 'Ver detalhes',
                subtitle: 'Abrir certificado e arquivos.',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showDetails(context, certificate);
                },
              ),
              _ActionTile(
                icon: Icons.edit_rounded,
                title: 'Editar',
                subtitle: 'Atualizar dados e anexos.',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showCertificateForm(context, certificate: certificate);
                },
              ),
              _ActionTile(
                icon: Icons.delete_outline_rounded,
                title: 'Excluir',
                subtitle: 'Remove o certificado e seus arquivos locais.',
                tone: sheetContext.colors.error,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _confirmDelete(context, certificate);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  static Future<void> _showDetails(
    BuildContext context,
    Certificate certificate,
  ) async {
    AppHaptics.selection();
    await AppModal.showSheet<void>(
      context: context,
      builder: (sheetContext) {
        final spacing = sheetContext.spacing;
        return AppSurface(
          color: sheetContext.colors.modalSurface,
          shadow: sheetContext.elevations.high,
          padding: EdgeInsets.all(spacing.lg),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        certificate.title,
                        style: sheetContext.theme.textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                SizedBox(height: spacing.sm),
                CertificateValidationBadge(
                  validation: certificate.validation,
                  expanded: true,
                ),
                SizedBox(height: spacing.lg),
                _DetailLine(label: 'Provedor', value: certificate.provider),
                if (certificate.issueDate != null)
                  _DetailLine(
                    label: 'Emissão',
                    value: DateHelpers.formatFullDate(certificate.issueDate!),
                  ),
                if (certificate.credentialId.isNotEmpty)
                  _DetailLine(
                    label: 'Credencial',
                    value: certificate.credentialId,
                    copyable: true,
                  ),
                if (certificate.validation.normalizedUrl != null)
                  _DetailLine(
                    label: 'Validação',
                    value: certificate.validation.normalizedUrl!,
                    copyable: true,
                  ),
                if (certificate.tags.isNotEmpty) ...[
                  SizedBox(height: spacing.sm),
                  Wrap(
                    spacing: spacing.xs,
                    runSpacing: spacing.xs,
                    children: certificate.tags
                        .map((tag) => Chip(label: Text(tag)))
                        .toList(),
                  ),
                ],
                if (certificate.notes.isNotEmpty) ...[
                  SizedBox(height: spacing.lg),
                  Text(
                    'Notas',
                    style: sheetContext.theme.textTheme.titleMedium,
                  ),
                  SizedBox(height: spacing.xs),
                  SelectableText(
                    certificate.notes,
                    style: sheetContext.theme.textTheme.bodyMedium,
                  ),
                ],
                if (certificate.validation.messages.isNotEmpty) ...[
                  SizedBox(height: spacing.lg),
                  Text(
                    'Verificação',
                    style: sheetContext.theme.textTheme.titleMedium,
                  ),
                  SizedBox(height: spacing.xs),
                  ...certificate.validation.messages.map(
                    (message) => Padding(
                      padding: EdgeInsets.only(bottom: spacing.xs),
                      child: Text(
                        '• $message',
                        style: sheetContext.theme.textTheme.bodySmall,
                      ),
                    ),
                  ),
                ],
                if (certificate.attachments.isNotEmpty) ...[
                  SizedBox(height: spacing.lg),
                  Text(
                    'Arquivos',
                    style: sheetContext.theme.textTheme.titleMedium,
                  ),
                  SizedBox(height: spacing.sm),
                  ...certificate.attachments.map(
                    (attachment) => Padding(
                      padding: EdgeInsets.only(bottom: spacing.sm),
                      child: CertificateAttachmentPreview(
                        attachment: attachment,
                      ),
                    ),
                  ),
                ],
                SizedBox(height: spacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          _showCertificateForm(
                            context,
                            certificate: certificate,
                          );
                        },
                        icon: const Icon(Icons.edit_rounded),
                        label: const Text('Editar'),
                      ),
                    ),
                    SizedBox(width: spacing.md),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          _confirmDelete(context, certificate);
                        },
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('Excluir'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Future<void> _confirmDelete(
    BuildContext context,
    Certificate certificate,
  ) async {
    final confirmed = await AppModal.showDialogCard<bool>(
      context: context,
      builder: (dialogContext) {
        return AppSurface(
          color: dialogContext.colors.modalSurface,
          shadow: dialogContext.elevations.high,
          padding: EdgeInsets.all(dialogContext.spacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Excluir certificado?',
                style: dialogContext.theme.textTheme.titleLarge,
              ),
              SizedBox(height: dialogContext.spacing.sm),
              Text(
                'Esta ação remove o certificado e os arquivos locais anexados.',
                style: dialogContext.theme.textTheme.bodySmall,
              ),
              SizedBox(height: dialogContext.spacing.xl),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  SizedBox(width: dialogContext.spacing.md),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('Excluir'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (confirmed == true && context.mounted) {
      AppHaptics.warning();
      final deleted = await context
          .read<CertificateProvider>()
          .deleteCertificate(certificate);
      if (!context.mounted) return;
      if (deleted) {
        AppHaptics.success();
        SnackbarHelper.showSuccess(context, 'Certificado excluído.');
      } else {
        SnackbarHelper.showError(context, 'Não foi possível excluir.');
      }
    }
  }
}

class _AchievementStatsRow extends StatelessWidget {
  final int certificateCount;
  final int trustedCount;
  final int completedGoals;
  final int streak;

  const _AchievementStatsRow({
    required this.certificateCount,
    required this.trustedCount,
    required this.completedGoals,
    required this.streak,
  });

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            icon: Icons.workspace_premium_rounded,
            label: 'Certificados',
            value: '$certificateCount',
            tone: context.colors.accent,
          ),
        ),
        SizedBox(width: spacing.sm),
        Expanded(
          child: _StatTile(
            icon: Icons.verified_rounded,
            label: 'Validados',
            value: '$trustedCount',
            tone: context.colors.success,
          ),
        ),
        SizedBox(width: spacing.sm),
        Expanded(
          child: _StatTile(
            icon: Icons.flag_circle_rounded,
            label: 'Metas',
            value: '$completedGoals',
            tone: context.colors.accentSecondary,
          ),
        ),
        SizedBox(width: spacing.sm),
        Expanded(
          child: _StatTile(
            icon: Icons.local_fire_department_rounded,
            label: 'Streak',
            value: '$streak',
            tone: context.colors.accentTertiary,
          ),
        ),
      ],
    );
  }
}

class _CertificateToolbar extends StatelessWidget {
  final CertificateProvider provider;

  const _CertificateToolbar({required this.provider});

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: 'Biblioteca',
          subtitle: 'Organize certificados, diplomas e conclusões.',
          trailing: PopupMenuButton<CertificateSortOption>(
            initialValue: provider.sortOption,
            onSelected: (option) {
              AppHaptics.selection();
              provider.setSortOption(option);
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: CertificateSortOption.newest,
                child: Text('Mais recentes'),
              ),
              PopupMenuItem(
                value: CertificateSortOption.oldest,
                child: Text('Mais antigos'),
              ),
              PopupMenuItem(
                value: CertificateSortOption.provider,
                child: Text('Provedor'),
              ),
              PopupMenuItem(
                value: CertificateSortOption.title,
                child: Text('Título'),
              ),
              PopupMenuItem(
                value: CertificateSortOption.category,
                child: Text('Categoria'),
              ),
              PopupMenuItem(
                value: CertificateSortOption.rank,
                child: Text('Relevancia'),
              ),
            ],
            icon: const Icon(Icons.sort_rounded),
          ),
        ),
        SizedBox(height: spacing.md),
        TextField(
          onChanged: provider.setQuery,
          decoration: const InputDecoration(
            hintText: 'Buscar por título, provedor ou tag',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        SizedBox(height: spacing.md),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterChip(
                label: 'Todos',
                selected:
                    provider.statusFilter == null && provider.tagFilter == null,
                onTap: () {
                  AppHaptics.selection();
                  provider.setStatusFilter(null);
                  provider.setTagFilter(null);
                },
              ),
              _FilterChip(
                label: 'Confiáveis',
                selected:
                    provider.statusFilter ==
                    CertificateValidationStatus.trustedProviderLink,
                onTap: () {
                  AppHaptics.selection();
                  provider.setStatusFilter(
                    CertificateValidationStatus.trustedProviderLink,
                  );
                },
              ),
              _FilterChip(
                label: 'Com dados',
                selected:
                    provider.statusFilter ==
                    CertificateValidationStatus.metadataProvided,
                onTap: () {
                  AppHaptics.selection();
                  provider.setStatusFilter(
                    CertificateValidationStatus.metadataProvided,
                  );
                },
              ),
              _FilterChip(
                label: 'Revisar',
                selected:
                    provider.statusFilter ==
                    CertificateValidationStatus.formatWarning,
                onTap: () {
                  AppHaptics.selection();
                  provider.setStatusFilter(
                    CertificateValidationStatus.formatWarning,
                  );
                },
              ),
              for (final tag in provider.allTags.take(8))
                _FilterChip(
                  label: tag,
                  selected: provider.tagFilter == tag,
                  onTap: () {
                    AppHaptics.selection();
                    provider.setTagFilter(tag);
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyCertificates extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyCertificates({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      child: Column(
        children: [
          Icon(
            Icons.workspace_premium_rounded,
            size: 48,
            color: context.colors.textDisabled,
          ),
          const SizedBox(height: 12),
          Text(
            'Nenhum certificado salvo',
            style: context.theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Adicione seu primeiro certificado para começar a evoluir seu nível.',
            textAlign: TextAlign.center,
            style: context.theme.textTheme.bodySmall,
          ),
          SizedBox(height: context.spacing.lg),
          CustomButton(
            label: 'Adicionar certificado',
            icon: Icons.add_rounded,
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const _ErrorBanner({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      color: context.colors.error.withValues(alpha: 0.08),
      border: Border.all(color: context.colors.error.withValues(alpha: 0.20)),
      shadow: const [],
      padding: EdgeInsets.all(context.spacing.md),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: context.colors.error),
          SizedBox(width: context.spacing.sm),
          Expanded(
            child: Text(message, style: context.theme.textTheme.bodySmall),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color tone;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      padding: EdgeInsets.all(context.spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tone, size: 18),
          const SizedBox(height: 8),
          Text(value, style: context.theme.textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(right: context.spacing.xs),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? tone;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.tone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = tone ?? context.colors.accent;
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(icon, color: color),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
    );
  }
}

class _DetailLine extends StatelessWidget {
  final String label;
  final String value;
  final bool copyable;

  const _DetailLine({
    required this.label,
    required this.value,
    this.copyable = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.spacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(label, style: context.theme.textTheme.labelMedium),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: context.theme.textTheme.bodyMedium,
            ),
          ),
          if (copyable)
            IconButton(
              tooltip: 'Copiar',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value));
                AppHaptics.selection();
                SnackbarHelper.showInfo(context, 'Copiado.');
              },
              icon: const Icon(Icons.copy_rounded, size: 18),
            ),
        ],
      ),
    );
  }
}
