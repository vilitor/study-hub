import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:study_hub/config/app_theme.dart';
import 'package:study_hub/providers/update_provider.dart';
import 'package:study_hub/services/app_haptics.dart';
import 'package:study_hub/widgets/app_modal.dart';
import 'package:study_hub/widgets/app_surface.dart';

class UpdateAvailableDialog {
  const UpdateAvailableDialog._();

  static Future<void> show(BuildContext context) {
    return AppModal.showDialogCard<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _UpdateAvailableCard(),
    );
  }
}

class _UpdateAvailableCard extends StatelessWidget {
  const _UpdateAvailableCard();

  @override
  Widget build(BuildContext context) {
    return Consumer<UpdateProvider>(
      builder: (context, updates, _) {
        final release = updates.availableRelease;
        final notes = _releaseNotes(release?.releaseNotes ?? '');
        final isDownloading = updates.status == UpdateStatus.downloading;
        final canRetry =
            updates.status == UpdateStatus.failed ||
            updates.status == UpdateStatus.canceled;

        return AppSurface(
          color: context.colors.modalSurface,
          shadow: context.elevations.high,
          padding: EdgeInsets.all(context.spacing.lg),
          child: Material(
            color: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: context.colors.accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.system_update_alt_rounded,
                        color: context.colors.accent,
                      ),
                    ),
                    SizedBox(width: context.spacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Atualização disponível',
                            style: context.theme.textTheme.titleLarge,
                          ),
                          SizedBox(height: context.spacing.xs),
                          Text(
                            'Versao ${updates.latestVersionLabel}',
                            style: context.theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: context.spacing.lg),
                _VersionRow(
                  current: updates.installedVersionLabel,
                  latest: updates.latestVersionLabel,
                ),
                SizedBox(height: context.spacing.md),
                ...notes.map(
                  (note) => Padding(
                    padding: EdgeInsets.only(bottom: context.spacing.xs),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 7),
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: context.colors.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        SizedBox(width: context.spacing.sm),
                        Expanded(
                          child: Text(
                            note,
                            style: context.theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (updates.errorMessage != null) ...[
                  SizedBox(height: context.spacing.sm),
                  Text(
                    updates.errorMessage!,
                    style: context.theme.textTheme.bodySmall?.copyWith(
                      color: context.colors.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (isDownloading ||
                    updates.status == UpdateStatus.readyToInstall) ...[
                  SizedBox(height: context.spacing.lg),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 8,
                      value: updates.downloadProgress == 0
                          ? null
                          : updates.downloadProgress,
                      color: context.colors.accent,
                      backgroundColor: context.colors.surface2,
                    ),
                  ),
                  SizedBox(height: context.spacing.xs),
                  Text(
                    isDownloading
                        ? '${(updates.downloadProgress * 100).round()}% baixado'
                        : 'Download pronto para instalação',
                    style: context.theme.textTheme.bodySmall,
                    textAlign: TextAlign.right,
                  ),
                ],
                SizedBox(height: context.spacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isDownloading
                            ? () {
                                AppHaptics.selection();
                                updates.cancelDownload();
                              }
                            : () {
                                AppHaptics.selection();
                                updates.dismissAvailableUpdateForSession();
                                Navigator.pop(context);
                              },
                        child: Text(isDownloading ? 'Cancelar' : 'Mais tarde'),
                      ),
                    ),
                    SizedBox(width: context.spacing.sm),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: Icon(
                          canRetry
                              ? Icons.refresh_rounded
                              : Icons.download_rounded,
                        ),
                        label: Text(
                          canRetry ? 'Tentar novamente' : 'Atualizar',
                        ),
                        onPressed: isDownloading
                            ? null
                            : () => _handleUpdate(context, updates),
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

  Future<void> _handleUpdate(
    BuildContext context,
    UpdateProvider updates,
  ) async {
    await AppHaptics.selection();
    final downloaded = updates.status == UpdateStatus.readyToInstall
        ? true
        : await updates.downloadUpdate();
    if (!context.mounted || !downloaded) return;

    final installerOpened = await updates.installDownloadedUpdate();
    if (!context.mounted) return;
    if (installerOpened) {
      Navigator.pop(context);
    }
  }

  List<String> _releaseNotes(String raw) {
    final notes = raw
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map((line) => line.replaceFirst(RegExp(r'^[-*#\s]+'), '').trim())
        .where((line) => line.isNotEmpty)
        .take(6)
        .toList();
    if (notes.isNotEmpty) return notes;
    return const [
      'Melhorias de estabilidade e desempenho.',
      'Ajustes visuais e refinamentos de experiencia.',
    ];
  }
}

class _VersionRow extends StatelessWidget {
  final String current;
  final String latest;

  const _VersionRow({required this.current, required this.latest});

  @override
  Widget build(BuildContext context) {
    return AppSurface.subtle(
      padding: EdgeInsets.all(context.spacing.md),
      child: Row(
        children: [
          Expanded(
            child: _VersionPill(label: 'Instalada', value: current),
          ),
          SizedBox(width: context.spacing.sm),
          Icon(Icons.arrow_forward_rounded, color: context.colors.accent),
          SizedBox(width: context.spacing.sm),
          Expanded(
            child: _VersionPill(label: 'Nova', value: latest),
          ),
        ],
      ),
    );
  }
}

class _VersionPill extends StatelessWidget {
  final String label;
  final String value;

  const _VersionPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.theme.textTheme.labelMedium),
        SizedBox(height: context.spacing.xxs),
        Text(
          value,
          style: context.theme.textTheme.titleMedium,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
