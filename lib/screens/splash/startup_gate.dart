import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:study_hub/models/auth_session.dart';
import 'package:study_hub/providers/auth_session_provider.dart';
import 'package:study_hub/providers/settings_provider.dart';
import 'package:study_hub/screens/auth/login_start_screen.dart';
import 'package:study_hub/screens/splash/app_splash_screen.dart';

class StartupGate extends StatelessWidget {
  final Widget destination;

  const StartupGate({super.key, required this.destination});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final auth = context.watch<AuthSessionProvider>();

    if (settings.isLoading || auth.isLoading) {
      return const AppSplashScreen();
    }

    if (auth.status == AuthSessionStatus.signedIn ||
        auth.status == AuthSessionStatus.guest) {
      return destination;
    }

    return const LoginStartScreen();
  }
}
