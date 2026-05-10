import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:study_hub/models/auth_session.dart';
import 'package:study_hub/providers/auth_session_provider.dart';
import 'package:study_hub/providers/settings_provider.dart';

class AppSplashScreen extends StatefulWidget {
  final Widget destination;

  const AppSplashScreen({super.key, required this.destination});

  @override
  State<AppSplashScreen> createState() => _AppSplashScreenState();
}

class _AppSplashScreenState extends State<AppSplashScreen> {
  static const _splashAsset = 'assets/splash/book_opening/logo_loading_1.png';

  bool _didPrecache = false;
  bool _isImageReady = false;
  bool _didNavigate = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didPrecache) return;
    _didPrecache = true;
    _precacheImage();
  }

  Future<void> _precacheImage() async {
    await precacheImage(const AssetImage(_splashAsset), context);
    if (!mounted) return;

    setState(() => _isImageReady = true);
    _tryNavigate();
  }

  void _tryNavigate() {
    if (_didNavigate || !_isImageReady) return;
    if (context.read<SettingsProvider>().isLoading) return;
    final auth = context.read<AuthSessionProvider>();
    if (auth.isLoading || !auth.hasEntryChoice) return;
    if (auth.status == AuthSessionStatus.authError) return;

    _didNavigate = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          pageBuilder: (_, _, _) => widget.destination,
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLoadingSettings = context.watch<SettingsProvider>().isLoading;
    final auth = context.watch<AuthSessionProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    if (!isLoadingSettings && !auth.isLoading) {
      _tryNavigate();
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            _splashAsset,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            filterQuality: FilterQuality.high,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colorScheme.surface.withValues(alpha: 0.04),
                  colorScheme.surface.withValues(alpha: 0.18),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _buildBottomContent(
                    context,
                    auth,
                    isLoadingSettings,
                    colorScheme,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomContent(
    BuildContext context,
    AuthSessionProvider auth,
    bool isLoadingSettings,
    ColorScheme colorScheme,
  ) {
    if (!_isImageReady ||
        isLoadingSettings ||
        auth.isLoading ||
        auth.status == AuthSessionStatus.signingIn) {
      return SizedBox(
        key: const ValueKey('splash-loading'),
        width: 28,
        height: 28,
        child: CircularProgressIndicator(
          strokeWidth: 2.6,
          color: colorScheme.primary,
          backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
          strokeCap: StrokeCap.round,
        ),
      );
    }

    if (auth.hasEntryChoice && auth.status != AuthSessionStatus.authError) {
      return const SizedBox(key: ValueKey('splash-ready'), height: 28);
    }

    final diagnostic = auth.lastDiagnostic;
    return ConstrainedBox(
      key: const ValueKey('splash-auth-choice'),
      constraints: const BoxConstraints(maxWidth: 420),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Entrar no StudyHub',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                diagnostic?.message ??
                    'Use Google para backup na nuvem ou continue localmente.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              if (diagnostic?.manualAction != null) ...[
                const SizedBox(height: 8),
                Text(
                  diagnostic!.manualAction!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () =>
                    context.read<AuthSessionProvider>().signInWithGoogle(),
                icon: const Icon(Icons.login_rounded),
                label: const Text('Entrar com Google'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () =>
                    context.read<AuthSessionProvider>().continueAsGuest(),
                icon: const Icon(Icons.person_outline_rounded),
                label: const Text('Continuar como visitante'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
