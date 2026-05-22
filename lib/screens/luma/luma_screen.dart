import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:study_hub/config/app_theme.dart';
import 'package:study_hub/models/ai_assistant.dart';
import 'package:study_hub/models/study_goal.dart';
import 'package:study_hub/providers/ai_assistant_provider.dart';
import 'package:study_hub/providers/certificate_provider.dart';
import 'package:study_hub/providers/goal_provider.dart';
import 'package:study_hub/providers/settings_provider.dart';
import 'package:study_hub/providers/study_event_provider.dart';
import 'package:study_hub/providers/study_log_provider.dart';
import 'package:study_hub/services/app_haptics.dart';
import 'package:study_hub/utils/date_helpers.dart';
import 'package:study_hub/utils/snackbar_helper.dart';
import 'package:study_hub/widgets/app_surface.dart';

class LumaScreen extends StatefulWidget {
  const LumaScreen({super.key});

  @override
  State<LumaScreen> createState() => _LumaScreenState();
}

class _LumaScreenState extends State<LumaScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final ai = context.watch<AiAssistantProvider>();
    final logs = context.watch<StudyLogProvider>();
    final events = context.watch<StudyEventProvider>();
    final goals = context.watch<GoalProvider>();
    final certificates = context.watch<CertificateProvider>();
    final settings = context.watch<SettingsProvider>();
    final snapshot = ai.buildSnapshot(
      logs: logs,
      events: events,
      goals: goals,
      certificates: certificates,
      settings: settings,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Luma'),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: spacing.md),
            child: Chip(
              avatar: const Icon(Icons.lock_outline_rounded, size: 16),
              label: const Text('Local'),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  spacing.screenPadding,
                  spacing.lg,
                  spacing.screenPadding,
                  spacing.lg,
                ),
                children: [
                  _LumaHeader(snapshot: snapshot),
                  SizedBox(height: spacing.sectionGap),
                  _QuickActions(onRun: _submitQuick),
                  SizedBox(height: spacing.sectionGap),
                  ...ai.messages.map(
                    (message) => _MessageCard(message: message),
                  ),
                  if (ai.pendingAction != null)
                    _PendingActionCard(
                      draft: ai.pendingAction!,
                      isProcessing: ai.isProcessing,
                      onConfirm: () => _confirm(ai.pendingAction!),
                      onCancel: () {
                        AppHaptics.selection();
                        context
                            .read<AiAssistantProvider>()
                            .clearPendingAction();
                      },
                    ),
                ],
              ),
            ),
            _InputBar(
              controller: _controller,
              enabled: !ai.isProcessing,
              onSubmit: _submit,
            ),
          ],
        ),
      ),
    );
  }

  void _submitQuick(String command) {
    _controller.text = command;
    _submit();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    AppHaptics.selection();
    context.read<AiAssistantProvider>().submit(
      input: value,
      logs: context.read<StudyLogProvider>(),
      events: context.read<StudyEventProvider>(),
      goals: context.read<GoalProvider>(),
      certificates: context.read<CertificateProvider>(),
      settings: context.read<SettingsProvider>(),
    );
    _controller.clear();
  }

  Future<void> _confirm(AiActionDraft draft) async {
    AppHaptics.selection();
    if (draft.type == AiActionType.openRoute && draft.routeName != null) {
      context.read<AiAssistantProvider>().clearPendingAction();
      Navigator.pushNamed(context, draft.routeName!);
      return;
    }
    final success = await context
        .read<AiAssistantProvider>()
        .confirmPendingAction(
          events: context.read<StudyEventProvider>(),
          goals: context.read<GoalProvider>(),
        );
    if (!mounted) return;
    if (success) {
      AppHaptics.success();
      SnackbarHelper.showSuccess(context, 'Luma salvou a ação.');
    } else {
      SnackbarHelper.showError(context, 'Luma nao conseguiu salvar.');
    }
  }
}

class _LumaHeader extends StatelessWidget {
  final dynamic snapshot;

  const _LumaHeader({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      color: Color.alphaBlend(
        context.colors.accent.withValues(alpha: 0.04),
        context.colors.surfaceElevated,
      ),
      shadow: context.elevations.medium,
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: context.colors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              color: context.colors.accent,
              size: 28,
            ),
          ),
          SizedBox(width: context.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Luma está local-first',
                  style: context.theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Semana: ${DateHelpers.formatDuration(snapshot.weeklyStudyMinutes)} • Streak: ${snapshot.currentStreak} dia(s)',
                  style: context.theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final ValueChanged<String> onRun;

  const _QuickActions({required this.onRun});

  @override
  Widget build(BuildContext context) {
    const actions = [
      'Como funcionam as conquistas?',
      'Como está minha produtividade?',
      'O que estudei ontem?',
      'Criar evento amanha as 9 para Biologia',
      'Criar meta semanal de 2 horas para SQL',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionHeader(
          title: 'Atalhos inteligentes',
          subtitle: 'Tudo roda localmente nesta versão.',
        ),
        SizedBox(height: context.spacing.md),
        Wrap(
          spacing: context.spacing.xs,
          runSpacing: context.spacing.xs,
          children: actions.map((action) {
            return ActionChip(
              label: Text(action),
              onPressed: () => onRun(action),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _MessageCard extends StatelessWidget {
  final AiMessage message;

  const _MessageCard({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.author == AiMessageAuthor.user;
    final tone = isUser
        ? context.colors.accentSecondary
        : context.colors.accent;
    return Padding(
      padding: EdgeInsets.only(bottom: context.spacing.sm),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.88,
          ),
          child: AppSurface(
            color: isUser
                ? tone.withValues(alpha: 0.12)
                : context.colors.surfaceElevated,
            shadow: const [],
            padding: EdgeInsets.all(context.spacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.title.isNotEmpty) ...[
                  Text(
                    message.title,
                    style: context.theme.textTheme.titleMedium,
                  ),
                  SizedBox(height: context.spacing.xs),
                ],
                Text(message.body, style: context.theme.textTheme.bodyMedium),
                if (message.results.isNotEmpty) ...[
                  SizedBox(height: context.spacing.md),
                  ...message.results.map((item) => _ResultTile(item: item)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  final AiResultItem item;

  const _ResultTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: context.spacing.xs),
      padding: EdgeInsets.all(context.spacing.sm),
      decoration: BoxDecoration(
        color: context.colors.surface2,
        borderRadius: BorderRadius.circular(context.spacing.fieldRadius),
        border: Border.all(color: context.colors.borderSubtle),
      ),
      child: Row(
        children: [
          Icon(Icons.article_outlined, color: context.colors.accent, size: 18),
          SizedBox(width: context.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: context.theme.textTheme.labelLarge),
                Text(item.subtitle, style: context.theme.textTheme.bodySmall),
                if (item.detail.isNotEmpty)
                  Text(
                    item.detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingActionCard extends StatelessWidget {
  final AiActionDraft draft;
  final bool isProcessing;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _PendingActionCard({
    required this.draft,
    required this.isProcessing,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      color: Color.alphaBlend(
        context.colors.accent.withValues(alpha: 0.05),
        context.colors.surfaceElevated,
      ),
      border: Border.all(color: context.colors.accent.withValues(alpha: 0.22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(
            title: 'Revisar antes de salvar',
            subtitle: _draftDescription(),
          ),
          SizedBox(height: context.spacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isProcessing ? null : onCancel,
                  child: const Text('Cancelar'),
                ),
              ),
              SizedBox(width: context.spacing.md),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isProcessing ? null : onConfirm,
                  icon: isProcessing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded),
                  label: const Text('Confirmar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _draftDescription() {
    return switch (draft.type) {
      AiActionType.createEvent =>
        '${draft.title} • ${draft.subject ?? 'Geral'} • ${draft.date == null ? 'hoje' : DateHelpers.formatShortDate(draft.date!)}',
      AiActionType.createGoal =>
        '${draft.title} • ${DateHelpers.formatDuration(draft.targetMinutes ?? 120)} • ${(draft.goalType ?? GoalType.weekly) == GoalType.weekly ? 'semanal' : 'mensal'}',
      AiActionType.openRoute => draft.title,
    };
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSubmit;

  const _InputBar({
    required this.controller,
    required this.enabled,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: EdgeInsets.fromLTRB(
        context.spacing.md,
        context.spacing.sm,
        context.spacing.md,
        context.spacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              textInputAction: TextInputAction.send,
              minLines: 1,
              maxLines: 4,
              onSubmitted: (_) => onSubmit(),
              decoration: const InputDecoration(
                hintText: 'Pergunte ou peça uma ação local...',
                prefixIcon: Icon(Icons.auto_awesome_rounded),
              ),
            ),
          ),
          SizedBox(width: context.spacing.sm),
          IconButton.filled(
            onPressed: enabled ? onSubmit : null,
            icon: const Icon(Icons.arrow_upward_rounded),
          ),
        ],
      ),
    );
  }
}
