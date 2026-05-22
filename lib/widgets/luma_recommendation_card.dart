import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:study_hub/config/app_routes.dart';
import 'package:study_hub/config/app_theme.dart';
import 'package:study_hub/models/ai_assistant.dart';
import 'package:study_hub/providers/ai_assistant_provider.dart';
import 'package:study_hub/providers/certificate_provider.dart';
import 'package:study_hub/providers/goal_provider.dart';
import 'package:study_hub/providers/settings_provider.dart';
import 'package:study_hub/providers/study_event_provider.dart';
import 'package:study_hub/providers/study_log_provider.dart';
import 'package:study_hub/services/app_haptics.dart';
import 'package:study_hub/widgets/app_surface.dart';

class LumaRecommendationCard extends StatelessWidget {
  final String title;

  const LumaRecommendationCard({super.key, this.title = 'Proximo passo'});

  @override
  Widget build(BuildContext context) {
    AiAssistantProvider? ai;
    try {
      ai = context.watch<AiAssistantProvider>();
    } on ProviderNotFoundException {
      return const SizedBox.shrink();
    }
    final snapshot = ai.buildSnapshot(
      logs: context.watch<StudyLogProvider>(),
      events: context.watch<StudyEventProvider>(),
      goals: context.watch<GoalProvider>(),
      certificates: context.watch<CertificateProvider>(),
      settings: context.watch<SettingsProvider>(),
    );
    final recommendation = ai.recommendationFor(snapshot);
    final tone = _toneColor(context, recommendation.tone);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(context.spacing.cardRadius),
        onTap: () {
          AppHaptics.selection();
          Navigator.pushNamed(context, AppRoutes.luma);
        },
        child: AppSurface(
          color: Color.alphaBlend(
            tone.withValues(alpha: 0.04),
            context.colors.surfaceElevated,
          ),
          border: Border.all(color: tone.withValues(alpha: 0.18)),
          shadow: context.elevations.low,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.auto_awesome_rounded, color: tone),
              ),
              SizedBox(width: context.spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Luma • $title',
                      style: context.theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      recommendation.title,
                      style: context.theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      recommendation.body,
                      style: context.theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                color: context.colors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _toneColor(BuildContext context, AiInsightTone tone) {
    return switch (tone) {
      AiInsightTone.success => context.colors.success,
      AiInsightTone.warning => context.colors.warning,
      AiInsightTone.focus => context.colors.accentSecondary,
      AiInsightTone.neutral => context.colors.accent,
    };
  }
}
