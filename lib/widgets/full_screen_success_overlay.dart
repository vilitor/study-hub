import 'dart:async';

import 'package:flutter/material.dart';
import 'package:study_hub/config/app_theme.dart';
import 'package:study_hub/services/app_haptics.dart';

class FullScreenSuccessOverlay extends StatefulWidget {
  final String message;
  final IconData icon;
  final Duration holdDuration;

  const FullScreenSuccessOverlay({
    super.key,
    required this.message,
    this.icon = Icons.check_rounded,
    this.holdDuration = const Duration(milliseconds: 850),
  });

  static Future<void> show(
    BuildContext context, {
    required String message,
    IconData icon = Icons.check_rounded,
    Duration holdDuration = const Duration(milliseconds: 850),
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Sucesso',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (_, _, _) {
        return FullScreenSuccessOverlay(
          message: message,
          icon: icon,
          holdDuration: holdDuration,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<FullScreenSuccessOverlay> createState() =>
      _FullScreenSuccessOverlayState();
}

class _FullScreenSuccessOverlayState extends State<FullScreenSuccessOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _iconScale;
  late final Animation<double> _contentOpacity;
  late final Animation<Offset> _textSlide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _iconScale = Tween<double>(begin: 0.72, end: 1).animate(curved);
    _contentOpacity = Tween<double>(begin: 0, end: 1).animate(curved);
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.16),
      end: Offset.zero,
    ).animate(curved);

    _run();
  }

  Future<void> _run() async {
    unawaited(AppHaptics.success());
    await _controller.forward();
    await Future<void>.delayed(widget.holdDuration);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.success,
      child: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: _contentOpacity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: _iconScale,
                  child: Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.white.withValues(alpha: 0.28),
                        width: 1.4,
                      ),
                    ),
                    child: Icon(widget.icon, size: 72, color: AppColors.white),
                  ),
                ),
                const SizedBox(height: 24),
                SlideTransition(
                  position: _textSlide,
                  child: Text(
                    widget.message,
                    textAlign: TextAlign.center,
                    style: context.theme.textTheme.headlineMedium?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
