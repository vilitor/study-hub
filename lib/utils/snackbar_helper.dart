import 'package:flutter/material.dart';
import 'package:study_hub/config/app_theme.dart';

/// Helper para mostrar mensagens de feedback ao usuário (snackbars)
class SnackbarHelper {
  /// Mostra uma mensagem de sucesso (verde)
  static void showSuccess(BuildContext context, String message) {
    _show(context, message, AppColors.success, Icons.check_circle_rounded);
  }

  /// Mostra uma mensagem de erro (vermelho)
  static void showError(BuildContext context, String message) {
    _show(context, message, AppColors.error, Icons.error_rounded);
  }

  /// Mostra uma mensagem de aviso (amarelo)
  static void showWarning(BuildContext context, String message) {
    _show(context, message, AppColors.warning, Icons.warning_rounded);
  }

  /// Mostra uma mensagem informativa (azul)
  static void showInfo(BuildContext context, String message) {
    _show(context, message, AppColors.info, Icons.info_rounded);
  }

  /// Mostra snackbar genérico com cor e ícone personalizados
  static void _show(
    BuildContext context,
    String message,
    Color color,
    IconData icon,
  ) {
    final spacing = context.spacing;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    const navBarReservedHeight = 88.0;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: _AnimatedAppSnackBar(
          message: message,
          icon: icon,
          tone: color,
        ),
        padding: EdgeInsets.zero,
        elevation: 0,
        backgroundColor: Colors.transparent,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(
          spacing.md,
          0,
          spacing.md,
          navBarReservedHeight + bottomInset + spacing.md,
        ),
        duration: const Duration(seconds: 3),
        dismissDirection: DismissDirection.down,
      ),
    );
  }
}

class _AnimatedAppSnackBar extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color tone;

  const _AnimatedAppSnackBar({
    required this.message,
    required this.icon,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 18),
            child: Transform.scale(scale: 0.96 + (value * 0.04), child: child),
          ),
        );
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: BorderRadius.circular(context.spacing.fieldRadius),
          border: Border.all(color: colors.borderSubtle),
          boxShadow: context.elevations.high,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.spacing.md,
            vertical: context.spacing.sm,
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: tone, size: 20),
              ),
              SizedBox(width: context.spacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: context.theme.textTheme.bodyMedium?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
