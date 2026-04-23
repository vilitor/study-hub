import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:study_hub/config/app_theme.dart';
import 'package:study_hub/providers/study_timer_provider.dart';

/// A floating bar that appears above the bottom navigation when the timer is active.
/// Animates smoothly with a slide-up transition.
class FloatingTimerBar extends StatelessWidget {
  const FloatingTimerBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<StudyTimerProvider>(
      builder: (context, timer, _) {
        return AnimatedSlide(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          offset: timer.isActive ? Offset.zero : const Offset(0, 2),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: timer.isActive ? 1.0 : 0.0,
            child: IgnorePointer(
              ignoring: !timer.isActive,
              child: Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.purple,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.purple.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Pulsing dot indicator
                    _PulsingDot(isRunning: timer.isRunning),
                    const SizedBox(width: 10),

                    // Elapsed time
                    Text(
                      timer.formattedTime,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),

                    const Spacer(),

                    // Pause / Resume button
                    _BarIconButton(
                      icon: timer.isPaused
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                      onTap: () =>
                          timer.isPaused ? timer.resume() : timer.pause(),
                    ),
                    const SizedBox(width: 8),

                    // Stop button
                    _BarIconButton(
                      icon: Icons.stop_rounded,
                      color: AppColors.coral,
                      onTap: () => timer.stop(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Small circular icon button for the floating bar.
class _BarIconButton extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final VoidCallback onTap;

  const _BarIconButton({
    required this.icon,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: (color ?? Colors.white).withValues(alpha: 0.2),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: color ?? Colors.white),
      ),
    );
  }
}

/// Animated pulsing dot to indicate the timer is actively running.
class _PulsingDot extends StatefulWidget {
  final bool isRunning;
  const _PulsingDot({required this.isRunning});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.isRunning) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_PulsingDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRunning && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isRunning && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.coral.withValues(alpha: _animation.value),
          ),
        );
      },
    );
  }
}
