import 'package:flutter/material.dart';
import 'package:study_hub/config/app_theme.dart';

class StreakBadge extends StatelessWidget {
  final int streakCount;

  const StreakBadge({super.key, required this.streakCount});

  @override
  Widget build(BuildContext context) {
    if (streakCount == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.coral.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.coral.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_fire_department_rounded,
            color: AppColors.coral,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            '$streakCount',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.coral,
            ),
          ),
        ],
      ),
    );
  }
}
