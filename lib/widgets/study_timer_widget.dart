import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:study_hub/config/app_theme.dart';
import 'package:study_hub/providers/study_timer_provider.dart';
import 'package:study_hub/services/app_haptics.dart';

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
        return SizedBox(
          width: double.infinity,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: timer.isActive
                  ? AppColors.purple.withValues(alpha: 0.9)
                  : Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.white.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: timer.isActive
                    ? Colors.white.withValues(alpha: 0.2)
                    : Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.05),
                width: 1.5,
              ),
              boxShadow: timer.isActive
                  ? [
                      BoxShadow(
                        color: AppColors.purple.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : [],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Timer display
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    timer.formattedTime,
                    style: GoogleFonts.outfit(
                      fontSize: 56,
                      fontWeight: FontWeight.w700,
                      color: timer.isActive
                          ? Colors.white
                          : Theme.of(context).textTheme.headlineLarge?.color,
                      letterSpacing: 1,
                    ),
                  ),
                ),

                const SizedBox(height: 6),

                // Status label
                Text(
                  timer.isRunning
                      ? 'Cronômetro ativo'
                      : timer.isPaused
                      ? 'Pausado'
                      : 'Toque em play para iniciar',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: timer.isActive
                        ? Colors.white.withValues(alpha: 0.8)
                        : Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),

                const SizedBox(height: 20),

                // Control buttons
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    if (!timer.isActive) ...[
                      // Start button
                      _TimerButton(
                        icon: Icons.play_arrow_rounded,
                        label: 'Iniciar estudo',
                        color: AppColors.primaryGreen,
                        onTap: () {
                          AppHaptics.selection();
                          timer.start();
                        },
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
                        onTap: () {
                          AppHaptics.selection();
                          timer.isPaused ? timer.resume() : timer.pause();
                        },
                      ),

                      // Record session button
                      _TimerButton(
                        icon: Icons.input_rounded,
                        label: 'Enviar',
                        color: Colors.white.withValues(alpha: 0.2),
                        textColor: Colors.white,
                        onTap: () {
                          AppHaptics.selection();
                          timer.recordSession();
                          onTimerStopped(timer.lastSessionMinutes);
                        },
                      ),

                      // Stop button
                      _TimerButton(
                        icon: Icons.stop_rounded,
                        label: 'Parar',
                        color: AppColors.coral,
                        onTap: () {
                          AppHaptics.warning();
                          final minutes = timer.stop();
                          onTimerStopped(minutes);
                        },
                      ),
                    ],
                  ],
                ),
              ],
            ),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
            Icon(icon, size: 18, color: textColor ?? Colors.white),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
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
