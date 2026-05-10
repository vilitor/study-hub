import 'package:flutter/material.dart';
import 'package:study_hub/config/app_theme.dart';
import 'package:study_hub/widgets/app_surface.dart';

class StudyHeatmap extends StatelessWidget {
  final Map<DateTime, int> datasets;
  final Color? color;

  const StudyHeatmap({super.key, required this.datasets, this.color});

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final today = DateTime.now();
    final firstDay = today.subtract(const Duration(days: 83));
    final startDay = firstDay.subtract(Duration(days: firstDay.weekday % 7));
    final tone = color ?? context.colors.accent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionHeader(
          title: 'Consistência',
          subtitle: 'Mapa de intensidade dos últimos 84 dias.',
        ),
        SizedBox(height: spacing.md),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 12,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
          ),
          itemCount: 12 * 7,
          itemBuilder: (context, index) {
            final week = index % 12;
            final dayOfWeek = index ~/ 12;
            final date = startDay.add(Duration(days: week * 7 + dayOfWeek));
            if (date.isAfter(today)) {
              return const SizedBox.shrink();
            }

            final dateKey = DateTime(date.year, date.month, date.day);
            final minutes = datasets[dateKey] ?? 0;
            return Tooltip(
              message: '$dateKey: $minutes min',
              child: Container(
                decoration: BoxDecoration(
                  color: _getColorForMinutes(context, tone, minutes),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Color _getColorForMinutes(BuildContext context, Color tone, int minutes) {
    if (minutes == 0) return context.colors.surface2;
    if (minutes < 30) return tone.withValues(alpha: 0.25);
    if (minutes < 60) return tone.withValues(alpha: 0.45);
    if (minutes < 120) return tone.withValues(alpha: 0.65);
    return tone;
  }
}
