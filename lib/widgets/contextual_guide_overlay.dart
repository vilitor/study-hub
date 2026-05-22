import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:study_hub/config/app_theme.dart';
import 'package:study_hub/providers/auth_session_provider.dart';
import 'package:study_hub/providers/contextual_guide_provider.dart';
import 'package:study_hub/providers/goal_provider.dart';
import 'package:study_hub/providers/navigation_provider.dart';
import 'package:study_hub/providers/onboarding_provider.dart';
import 'package:study_hub/providers/settings_provider.dart';
import 'package:study_hub/providers/study_event_provider.dart';
import 'package:study_hub/providers/study_log_provider.dart';
import 'package:study_hub/services/app_haptics.dart';
import 'package:study_hub/widgets/app_surface.dart';

class ContextualGuideOverlay extends StatelessWidget {
  const ContextualGuideOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final onboarding = context.watch<OnboardingProvider>();
    final guide = context.watch<ContextualGuideProvider>();
    final settings = context.watch<SettingsProvider>();
    final logs = context.watch<StudyLogProvider>();
    final steps = guide.steps(
      onboarding: onboarding.state,
      settings: settings.settings,
      authStatus: context.watch<AuthSessionProvider>().status,
      events: context.watch<StudyEventProvider>(),
      logs: logs,
      goals: context.watch<GoalProvider>().goals,
      schema: logs.cachedSchema,
    );

    if (!guide.shouldShow(onboarding: onboarding.state, steps: steps)) {
      return const SizedBox.shrink();
    }

    final index = guide.index.clamp(0, steps.length - 1);
    final step = steps[index];
    final isLast = index == steps.length - 1;

    return Positioned.fill(
      child: IgnorePointer(
        ignoring: false,
        child: ColoredBox(
          color: context.colors.modalBarrier,
          child: SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  context.spacing.md,
                  context.spacing.md,
                  context.spacing.md,
                  92 + MediaQuery.of(context).padding.bottom,
                ),
                child: AppSurface(
                  color: context.colors.modalSurface,
                  shadow: context.elevations.high,
                  padding: EdgeInsets.all(context.spacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            color: context.colors.accent,
                          ),
                          SizedBox(width: context.spacing.sm),
                          Expanded(
                            child: Text(
                              'Guia rápido',
                              style: context.theme.textTheme.titleSmall,
                            ),
                          ),
                          Text(
                            '${index + 1}/${steps.length}',
                            style: context.theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                      SizedBox(height: context.spacing.md),
                      Text(
                        step.title,
                        style: context.theme.textTheme.titleLarge,
                      ),
                      SizedBox(height: context.spacing.xs),
                      Text(
                        step.body,
                        style: context.theme.textTheme.bodyMedium,
                      ),
                      SizedBox(height: context.spacing.lg),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () async {
                              AppHaptics.selection();
                              guide.dismissForSession();
                              await onboarding.setContextualGuideCompleted(
                                true,
                              );
                            },
                            child: const Text('Pular'),
                          ),
                          const Spacer(),
                          if (step.navigationIndex != null)
                            TextButton(
                              onPressed: () {
                                AppHaptics.selection();
                                context.read<NavigationProvider>().setIndex(
                                  step.navigationIndex!,
                                );
                              },
                              child: Text(step.actionLabel),
                            ),
                          SizedBox(width: context.spacing.sm),
                          FilledButton(
                            onPressed: () async {
                              AppHaptics.selection();
                              if (isLast) {
                                await onboarding.setContextualGuideCompleted(
                                  true,
                                );
                                guide.dismissForSession();
                                return;
                              }
                              guide.next(steps.length);
                            },
                            child: Text(isLast ? 'Concluir' : 'Continuar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
