import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:study_hub/config/app_theme.dart';
import 'package:study_hub/models/auth_session.dart';
import 'package:study_hub/providers/auth_session_provider.dart';

class LoginStartScreen extends StatelessWidget {
  const LoginStartScreen({super.key});

  static const _splashAsset = 'assets/splash/book_opening/logo_loading_1.png';

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthSessionProvider>();
    final colors = context.colors;
    final spacing = context.spacing;
    final diagnostic = auth.lastDiagnostic;

    return Scaffold(
      backgroundColor: colors.scaffoldBase,
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
                  colors.scaffoldBase.withValues(alpha: 0.08),
                  colors.scaffoldBase.withValues(alpha: 0.78),
                  colors.scaffoldBase.withValues(alpha: 0.96),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  spacing.screenPadding,
                  spacing.xl,
                  spacing.screenPadding,
                  spacing.xxl,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'StudyHub',
                        textAlign: TextAlign.center,
                        style: context.theme.textTheme.headlineLarge,
                      ),
                      SizedBox(height: spacing.sm),
                      Text(
                        diagnostic?.message ??
                            'Entre com Google para restaurar seu backup ou continue localmente.',
                        textAlign: TextAlign.center,
                        style: context.theme.textTheme.bodyMedium?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      if (diagnostic?.manualAction != null) ...[
                        SizedBox(height: spacing.sm),
                        Text(
                          diagnostic!.manualAction!,
                          textAlign: TextAlign.center,
                          style: context.theme.textTheme.bodySmall?.copyWith(
                            color: colors.error,
                          ),
                        ),
                      ],
                      SizedBox(height: spacing.xl),
                      FilledButton.icon(
                        key: const ValueKey('login-google-button'),
                        onPressed: auth.status == AuthSessionStatus.signingIn
                            ? null
                            : () => context
                                  .read<AuthSessionProvider>()
                                  .signInWithGoogle(),
                        icon: auth.status == AuthSessionStatus.signingIn
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colors.textOnAccent,
                                ),
                              )
                            : const Icon(Icons.login_rounded),
                        label: const Text('Entrar com Google'),
                      ),
                      SizedBox(height: spacing.sm),
                      OutlinedButton.icon(
                        key: const ValueKey('login-guest-button'),
                        onPressed: auth.status == AuthSessionStatus.signingIn
                            ? null
                            : () => context
                                  .read<AuthSessionProvider>()
                                  .continueAsGuest(),
                        icon: const Icon(Icons.person_outline_rounded),
                        label: const Text('Continuar como visitante'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
