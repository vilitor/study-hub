import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import 'package:study_hub/config/app_theme.dart';
import 'package:study_hub/models/achievement_progress.dart';
import 'package:study_hub/models/certificate.dart';
import 'package:study_hub/providers/certificate_provider.dart';
import 'package:study_hub/services/app_haptics.dart';
import 'package:study_hub/utils/date_helpers.dart';
import 'package:study_hub/utils/snackbar_helper.dart';
import 'package:study_hub/widgets/app_surface.dart';
import 'package:study_hub/widgets/custom_button.dart';
import 'package:study_hub/widgets/custom_text_field.dart';

class AchievementRankBadge extends StatelessWidget {
  final AchievementRank rank;
  final double size;

  const AchievementRankBadge({super.key, required this.rank, this.size = 48});

  @override
  Widget build(BuildContext context) {
    final color = rank.accentColor;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.30),
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.36)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.16),
            blurRadius: size * 0.36,
            offset: Offset(0, size * 0.10),
          ),
        ],
      ),
      child: Icon(rank.icon, color: color, size: size * 0.52),
    );
  }
}

class AchievementProgressCard extends StatelessWidget {
  final AchievementProgress progress;
  final int certificateCount;
  final int trustedCount;
  final int totalStudyMinutes;

  const AchievementProgressCard({
    super.key,
    required this.progress,
    required this.certificateCount,
    required this.trustedCount,
    required this.totalStudyMinutes,
  });

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return AppSurface(
      color: Color.alphaBlend(
        progress.currentRank.accentColor.withValues(alpha: 0.035),
        context.colors.surfaceElevated,
      ),
      shadow: context.elevations.medium,
      border: Border.all(
        color: progress.currentRank.accentColor.withValues(alpha: 0.18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AchievementRankBadge(rank: progress.currentRank, size: 58),
              SizedBox(width: spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      progress.currentRank.label,
                      style: context.theme.textTheme.headlineMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      progress.nextMilestoneLabel,
                      style: context.theme.textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: spacing.lg),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.progressToNext,
              minHeight: 9,
              backgroundColor: context.colors.surface2,
              valueColor: AlwaysStoppedAnimation<Color>(context.colors.accent),
            ),
          ),
          SizedBox(height: spacing.md),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Certificados',
                  value: '$certificateCount',
                ),
              ),
              Expanded(
                child: _MiniStat(label: 'Confiáveis', value: '$trustedCount'),
              ),
              Expanded(
                child: _MiniStat(
                  label: 'Estudo',
                  value: DateHelpers.formatDuration(totalStudyMinutes),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CertificateCard extends StatelessWidget {
  final Certificate certificate;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const CertificateCard({
    super.key,
    required this.certificate,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(spacing.cardRadius),
        child: AppSurface(
          padding: EdgeInsets.all(spacing.md),
          color: Color.alphaBlend(
            context.colors.accent.withValues(alpha: 0.025),
            context.colors.surfaceElevated,
          ),
          border: Border.all(color: context.colors.borderSubtle),
          shadow: context.elevations.low,
          radius: 18,
          child: Row(
            children: [
              _AttachmentIcon(certificate: certificate),
              SizedBox(width: spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      certificate.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      certificate.provider,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.theme.textTheme.bodySmall,
                    ),
                    if (certificate.issueDate != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        DateHelpers.formatShortDate(certificate.issueDate!),
                        style: context.theme.textTheme.labelMedium,
                      ),
                    ],
                    if (certificate.tags.isNotEmpty) ...[
                      SizedBox(height: spacing.xs),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: certificate.tags.take(3).map((tag) {
                          return _SmallChip(label: tag);
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: spacing.sm),
              CertificateValidationBadge(validation: certificate.validation),
            ],
          ),
        ),
      ),
    );
  }
}

class CertificateValidationBadge extends StatelessWidget {
  final CertificateValidation validation;
  final bool expanded;

  const CertificateValidationBadge({
    super.key,
    required this.validation,
    this.expanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (validation.status) {
      CertificateValidationStatus.trustedProviderLink ||
      CertificateValidationStatus.manuallyVerified ||
      CertificateValidationStatus.apiVerified => context.colors.success,
      CertificateValidationStatus.formatWarning => context.colors.warning,
      CertificateValidationStatus.metadataProvided => context.colors.info,
      CertificateValidationStatus.unverified => context.colors.textDisabled,
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: expanded ? context.spacing.sm : context.spacing.xs,
        vertical: context.spacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(validation.status.icon, color: color, size: 16),
          if (expanded) ...[
            SizedBox(width: context.spacing.xs),
            Text(
              validation.providerName ?? validation.status.label,
              style: context.theme.textTheme.labelMedium?.copyWith(
                color: color,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class CertificateAttachmentPreview extends StatelessWidget {
  final CertificateAttachment attachment;

  const CertificateAttachmentPreview({super.key, required this.attachment});

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          AppHaptics.selection();
          OpenFilex.open(attachment.localPath);
        },
        borderRadius: BorderRadius.circular(spacing.fieldRadius),
        child: Container(
          padding: EdgeInsets.all(spacing.sm),
          decoration: BoxDecoration(
            color: context.colors.surface2,
            borderRadius: BorderRadius.circular(spacing.fieldRadius),
            border: Border.all(color: context.colors.borderSubtle),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 54,
                  height: 54,
                  child: attachment.fileType == CertificateFileType.image
                      ? Image.file(
                          File(attachment.localPath),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const Icon(Icons.image_not_supported_rounded),
                        )
                      : Icon(
                          attachment.fileType == CertificateFileType.pdf
                              ? Icons.picture_as_pdf_rounded
                              : Icons.insert_drive_file_rounded,
                          color: context.colors.accent,
                        ),
                ),
              ),
              SizedBox(width: spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      attachment.originalName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.theme.textTheme.labelLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatBytes(attachment.fileSizeBytes),
                      style: context.theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.open_in_new_rounded,
                size: 18,
                color: context.colors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CertificateFormSheet extends StatefulWidget {
  final Certificate? certificate;

  const CertificateFormSheet({super.key, this.certificate});

  @override
  State<CertificateFormSheet> createState() => _CertificateFormSheetState();
}

class _CertificateFormSheetState extends State<CertificateFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _providerController;
  late final TextEditingController _credentialController;
  late final TextEditingController _urlController;
  late final TextEditingController _tagsController;
  late final TextEditingController _notesController;
  late List<CertificateAttachment> _attachments;
  DateTime? _issueDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final certificate = widget.certificate;
    _titleController = TextEditingController(text: certificate?.title ?? '');
    _providerController = TextEditingController(
      text: certificate?.provider ?? '',
    );
    _credentialController = TextEditingController(
      text: certificate?.credentialId ?? '',
    );
    _urlController = TextEditingController(
      text: certificate?.validationUrl ?? '',
    );
    _tagsController = TextEditingController(
      text: certificate?.tags.join(', ') ?? '',
    );
    _notesController = TextEditingController(text: certificate?.notes ?? '');
    _attachments = List<CertificateAttachment>.from(
      certificate?.attachments ?? const [],
    );
    _issueDate = certificate?.issueDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _providerController.dispose();
    _credentialController.dispose();
    _urlController.dispose();
    _tagsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final isPickingAttachment = context.select<CertificateProvider, bool>(
      (provider) => provider.isPickingAttachment,
    );
    final validation = context.read<CertificateProvider>().previewValidation(
      provider: _providerController.text,
      validationUrl: _urlController.text,
      credentialId: _credentialController.text,
    );

    return AppSurface(
      color: context.colors.modalSurface,
      shadow: context.elevations.high,
      padding: EdgeInsets.fromLTRB(
        spacing.lg,
        spacing.lg,
        spacing.lg,
        MediaQuery.of(context).viewInsets.bottom + spacing.lg,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSectionHeader(
                title: widget.certificate == null
                    ? 'Novo certificado'
                    : 'Editar certificado',
                subtitle: 'Guarde certificados, diplomas e conclusões.',
                trailing: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
              SizedBox(height: spacing.lg),
              CustomTextField(
                label: 'Título',
                hint: 'Ex: Flutter Avançado',
                prefixIcon: Icons.workspace_premium_rounded,
                controller: _titleController,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Informe o título.'
                    : null,
              ),
              SizedBox(height: spacing.md),
              CustomTextField(
                label: 'Plataforma / provedor',
                hint: 'Ex: Alura, Coursera, Udemy',
                prefixIcon: Icons.school_rounded,
                controller: _providerController,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Informe o provedor.'
                    : null,
                onChanged: (_) => setState(() {}),
              ),
              SizedBox(height: spacing.md),
              _IssueDatePicker(
                issueDate: _issueDate,
                onPick: _pickIssueDate,
                onClear: () => setState(() => _issueDate = null),
              ),
              SizedBox(height: spacing.md),
              CustomTextField(
                label: 'Código da credencial',
                prefixIcon: Icons.key_rounded,
                controller: _credentialController,
                onChanged: (_) => setState(() {}),
              ),
              SizedBox(height: spacing.md),
              CustomTextField(
                label: 'Link de validação',
                prefixIcon: Icons.verified_rounded,
                keyboardType: TextInputType.url,
                controller: _urlController,
                onChanged: (_) => setState(() {}),
              ),
              SizedBox(height: spacing.sm),
              CertificateValidationBadge(
                validation: validation,
                expanded: true,
              ),
              SizedBox(height: spacing.md),
              CustomTextField(
                label: 'Tags / categorias',
                hint: 'Separadas por vírgula',
                prefixIcon: Icons.sell_rounded,
                controller: _tagsController,
              ),
              SizedBox(height: spacing.md),
              CustomTextField(
                label: 'Notas',
                prefixIcon: Icons.notes_rounded,
                controller: _notesController,
                maxLines: 4,
              ),
              SizedBox(height: spacing.lg),
              _AttachmentEditor(
                attachments: _attachments,
                isLoading: isPickingAttachment,
                onAdd: _pickAttachment,
                onRemove: (attachment) {
                  AppHaptics.selection();
                  setState(() => _attachments.remove(attachment));
                },
              ),
              SizedBox(height: spacing.xl),
              CustomButton(
                label: _isSaving ? 'Salvando...' : 'Salvar certificado',
                icon: Icons.check_circle_rounded,
                isLoading: _isSaving,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickIssueDate() async {
    AppHaptics.selection();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _issueDate ?? now,
      firstDate: DateTime(now.year - 40),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null && mounted) {
      setState(() => _issueDate = picked);
    }
  }

  Future<void> _pickAttachment() async {
    AppHaptics.selection();
    final provider = context.read<CertificateProvider>();
    final attachment = await provider.pickAttachment();
    if (!mounted) return;
    if (attachment == null) {
      if (provider.lastError != null) {
        SnackbarHelper.showError(context, provider.lastError!);
        provider.clearError();
      }
      return;
    }
    if (provider.lastError != null) {
      SnackbarHelper.showError(context, provider.lastError!);
      provider.clearError();
      return;
    }
    setState(() => _attachments.add(attachment));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final existing = widget.certificate;
    final certificate = Certificate(
      id: widget.certificate?.id,
      title: _titleController.text.trim(),
      provider: _providerController.text.trim(),
      issueDate: _issueDate,
      credentialId: _credentialController.text.trim(),
      validationUrl: _urlController.text.trim(),
      tags: _parseTags(_tagsController.text),
      notes: _notesController.text.trim(),
      attachments: _attachments,
      createdAt: existing?.createdAt,
      syncStatus: existing?.syncStatus ?? CertificateSyncStatus.localOnly,
      remoteId: existing?.remoteId,
      lastSyncedAt: existing?.lastSyncedAt,
      source: existing?.source ?? CertificateSource.manual,
    );

    final saved = await context.read<CertificateProvider>().saveCertificate(
      certificate,
    );
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (saved) {
      AppHaptics.success();
      Navigator.pop(context);
      SnackbarHelper.showSuccess(context, 'Certificado salvo.');
    } else {
      SnackbarHelper.showError(context, 'Não foi possível salvar.');
    }
  }

  List<String> _parseTags(String value) {
    return value
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList();
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: context.theme.textTheme.titleMedium),
        const SizedBox(height: 2),
        Text(label, style: context.theme.textTheme.bodySmall),
      ],
    );
  }
}

class _SmallChip extends StatelessWidget {
  final String label;

  const _SmallChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: context.colors.surface2,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: context.colors.borderSubtle),
      ),
      child: Text(label, style: context.theme.textTheme.labelMedium),
    );
  }
}

class _AttachmentIcon extends StatelessWidget {
  final Certificate certificate;

  const _AttachmentIcon({required this.certificate});

  @override
  Widget build(BuildContext context) {
    final first = certificate.attachments.firstOrNull;
    final icon = first == null
        ? Icons.workspace_premium_rounded
        : switch (first.fileType) {
            CertificateFileType.image => Icons.image_rounded,
            CertificateFileType.pdf => Icons.picture_as_pdf_rounded,
            CertificateFileType.other => Icons.insert_drive_file_rounded,
          };
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: context.colors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: context.colors.accent),
    );
  }
}

class _IssueDatePicker extends StatelessWidget {
  final DateTime? issueDate;
  final VoidCallback onPick;
  final VoidCallback onClear;

  const _IssueDatePicker({
    required this.issueDate,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPick,
        borderRadius: BorderRadius.circular(context.spacing.fieldRadius),
        child: Container(
          padding: EdgeInsets.all(context.spacing.md),
          decoration: BoxDecoration(
            color: context.colors.inputFill,
            borderRadius: BorderRadius.circular(context.spacing.fieldRadius),
            border: Border.all(color: context.colors.inputBorder),
          ),
          child: Row(
            children: [
              Icon(
                Icons.calendar_today_rounded,
                color: context.colors.textSecondary,
              ),
              SizedBox(width: context.spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Data de emissão',
                      style: context.theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      issueDate == null
                          ? 'Selecionar data'
                          : DateHelpers.formatShortDate(issueDate!),
                      style: context.theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              if (issueDate != null)
                IconButton(
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttachmentEditor extends StatelessWidget {
  final List<CertificateAttachment> attachments;
  final bool isLoading;
  final VoidCallback onAdd;
  final ValueChanged<CertificateAttachment> onRemove;

  const _AttachmentEditor({
    required this.attachments,
    required this.isLoading,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Arquivos',
                style: context.theme.textTheme.titleSmall,
              ),
            ),
            TextButton.icon(
              onPressed: isLoading ? null : onAdd,
              icon: isLoading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: context.colors.accent,
                      ),
                    )
                  : const Icon(Icons.attach_file_rounded),
              label: Text(isLoading ? 'Importando' : 'Adicionar'),
            ),
          ],
        ),
        if (attachments.isEmpty)
          AppSurface.subtle(
            padding: EdgeInsets.all(spacing.md),
            child: Text(
              'Adicione uma imagem, screenshot ou PDF.',
              style: context.theme.textTheme.bodySmall,
            ),
          )
        else
          ...attachments.map(
            (attachment) => Padding(
              padding: EdgeInsets.only(bottom: spacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: CertificateAttachmentPreview(attachment: attachment),
                  ),
                  IconButton(
                    onPressed: () => onRemove(attachment),
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: context.colors.error,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes <= 0) return '0 KB';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
  return '${(kb / 1024).toStringAsFixed(1)} MB';
}
