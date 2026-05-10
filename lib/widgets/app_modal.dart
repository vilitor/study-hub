import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:study_hub/config/app_theme.dart';

class AppModal {
  static Future<T?> showSheet<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool isScrollControlled = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: Colors.transparent,
      barrierColor: context.colors.modalBarrier,
      builder: (sheetContext) {
        return _SheetWrapper(child: builder(sheetContext));
      },
    );
  }

  static Future<T?> showDialogCard<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool barrierDismissible = true,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: context.colors.modalBarrier,
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (dialogContext, _, _) =>
          _DialogWrapper(child: builder(dialogContext)),
      transitionBuilder: (_, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        final scale = TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.03), weight: 65),
          TweenSequenceItem(tween: Tween(begin: 1.03, end: 1.0), weight: 35),
        ]).animate(curved);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(scale: scale, child: child),
        );
      },
    );
  }
}

class _SheetWrapper extends StatelessWidget {
  final Widget child;

  const _SheetWrapper({required this.child});

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOutCubic,
      tween: Tween(begin: 0, end: 1),
      builder: (context, value, _) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8 * value, sigmaY: 8 * value),
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 28),
            child: Opacity(
              opacity: value,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.only(
                    left: spacing.md,
                    right: spacing.md,
                    bottom: spacing.md,
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DialogWrapper extends StatelessWidget {
  final Widget child;

  const _DialogWrapper({required this.child});

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(spacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: child,
          ),
        ),
      ),
    );
  }
}
