import 'package:flutter/material.dart';
import 'package:study_hub/config/app_routes.dart';
import 'package:study_hub/config/app_theme.dart';
import 'package:study_hub/services/app_haptics.dart';

class LumaDockButton extends StatelessWidget {
  const LumaDockButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Abrir Luma',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            AppHaptics.selection();
            Navigator.pushNamed(context, AppRoutes.luma);
          },
          onLongPress: () {
            AppHaptics.selection();
            Navigator.pushNamed(context, AppRoutes.luma);
          },
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color.alphaBlend(
                context.colors.accent.withValues(alpha: 0.12),
                context.colors.surfaceElevated,
              ),
              border: Border.all(
                color: context.colors.accent.withValues(alpha: 0.35),
              ),
              boxShadow: context.elevations.medium,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.colors.accent.withValues(alpha: 0.12),
                  ),
                ),
                Icon(
                  Icons.auto_awesome_rounded,
                  color: context.colors.accent,
                  size: 26,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
