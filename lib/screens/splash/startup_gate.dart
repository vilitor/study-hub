import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:study_hub/models/auth_session.dart';
import 'package:study_hub/providers/auth_session_provider.dart';
import 'package:study_hub/providers/local_study_schema_provider.dart';
import 'package:study_hub/providers/onboarding_provider.dart';
import 'package:study_hub/providers/settings_provider.dart';
import 'package:study_hub/screens/auth/login_start_screen.dart';
import 'package:study_hub/screens/onboarding/onboarding_screen.dart';
import 'package:study_hub/screens/splash/app_splash_screen.dart';
import 'package:study_hub/services/study_profile_catalog.dart';

class StartupGate extends StatelessWidget {
  final Widget destination;

  const StartupGate({super.key, required this.destination});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final auth = context.watch<AuthSessionProvider>();
    OnboardingProvider? onboarding;
    try {
      onboarding = context.watch<OnboardingProvider>();
    } on ProviderNotFoundException {
      onboarding = null;
    }

    if (settings.isLoading ||
        auth.isLoading ||
        (onboarding?.isLoading ?? false) ||
        ((auth.status == AuthSessionStatus.signedIn ||
                auth.status == AuthSessionStatus.guest) &&
            onboarding != null &&
            !onboarding.isLoadedForActiveNamespace)) {
      debugPrint('[ROUTE] waiting for local startup state');
      return const AppSplashScreen();
    }

    if (auth.status == AuthSessionStatus.signedIn ||
        auth.status == AuthSessionStatus.guest) {
      if (onboarding?.shouldShowOnboarding ?? false) {
        debugPrint('[ROUTE] target selected onboarding');
        if (auth.status == AuthSessionStatus.guest) {
          debugPrint('[GUEST] onboarding decision show');
          debugPrint('[GUEST] route selected onboarding');
        }
        return const OnboardingScreen();
      }
      debugPrint('[ROUTE] target selected main');
      if (auth.status == AuthSessionStatus.guest) {
        debugPrint('[GUEST] onboarding decision skip');
        debugPrint('[GUEST] route selected main');
      }
      return _PostOnboardingDataGate(destination: destination);
    }

    debugPrint('[ROUTE] target selected login');
    return const LoginStartScreen();
  }
}

class _PostOnboardingDataGate extends StatefulWidget {
  final Widget destination;

  const _PostOnboardingDataGate({required this.destination});

  @override
  State<_PostOnboardingDataGate> createState() =>
      _PostOnboardingDataGateState();
}

class _PostOnboardingDataGateState extends State<_PostOnboardingDataGate> {
  bool _requested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requested) return;
    _requested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final settings = context.read<SettingsProvider>().settings;
        final personalized =
            settings.profilePersonalizationCompleted &&
            !settings.legacyMigrationCompleted;
        final profileSubjects = settings.starterSubjectsSeeded
            ? settings.customCategories
            : const StudyProfileCatalog().starterSubjects(
                profileId: settings.selectedStudyProfileId,
                focusId: settings.selectedStudyFocusId,
              );
        context.read<LocalStudySchemaProvider>().loadFields(
          defaultCategories: personalized ? profileSubjects : const [],
          useFallbackCategories: !personalized,
          refreshDefaultCategoryOptions: personalized,
        );
      } on ProviderNotFoundException {
        // StartupGate is also used in focused widget tests.
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.destination;
}
