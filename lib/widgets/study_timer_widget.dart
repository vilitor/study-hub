import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:study_hub/config/app_theme.dart';
import 'package:study_hub/providers/study_timer_provider.dart';

/// Inline timer component displayed at the top of the StudyLogScreen.
/// Shows a digital clock with play/pause/stop controls.
class StudyTimerWidget extends StatelessWidget {
  /// Called when the timer is stopped, with the elapsed minutes.
  final ValueChanged<int> onTimerStopped;

  const StudyTimerWidget({super.key, required this.onTimerStopped});

  @override
  Widget build(BuildContext context) {
    return Consumer<StudyTimerProvider>(
      builder: (context, timer, _) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: timer.isActive
                  ? [AppColors.purple, AppColors.purple.withValues(alpha: 0.85)]
                  : [AppColors.cardGrey, AppColors.cardGrey],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: timer.isActive
                ? [
                    BoxShadow(
                      color: AppColors.purple.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Column(
            children: [
              // Timer display
              Text(
                timer.formattedTime,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 40,
                  fontWeight: FontWeight.w600,
                  color: timer.isActive ? Colors.white : AppColors.textPrimary,
                  letterSpacing: 2,
                ),
              ),

              const SizedBox(height: 4),

              // Status label
              Text(
                timer.isRunning
                    ? 'Cronômetro ativo'
                    : timer.isPaused
                        ? 'Pausado'
                        : 'Toque em play para iniciar',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: timer.isActive
                      ? Colors.white.withValues(alpha: 0.8)
                      : AppColors.textHint,
                ),
              ),

              const SizedBox(height: 16),

              // Control buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!timer.isActive) ...[
                    // Start button
                    _TimerButton(
                      icon: Icons.play_arrow_rounded,
                      label: 'Iniciar',
                      color: AppColors.primaryGreen,
                      onTap: () => timer.start(),
                    ),
                  ] else ...[
                    // Pause / Resume button
                    _TimerButton(
                      icon: timer.isPaused
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                      label: timer.isPaused ? 'Retomar' : 'Pausar',
                      color: Colors.white,
                      textColor: AppColors.purple,
                      onTap: () =>
                          timer.isPaused ? timer.resume() : timer.pause(),
                    ),

                    const SizedBox(width: 16),

                    // Stop button
                    _TimerButton(
                      icon: Icons.stop_rounded,
                      label: 'Parar',
                      color: AppColors.coral,
                      onTap: () {
                        final minutes = timer.stop();
                        onTimerStopped(minutes);
                      },
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Small pill-shaped button for timer controls.
class _TimerButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color? textColor;
  final VoidCallback onTap;

  const _TimerButton({
    required this.icon,
    required this.label,
    required this.color,
    this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: textColor ?? Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textColor ?? Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
