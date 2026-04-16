import 'package:flutter/material.dart';
import 'package:study_hub/config/app_theme.dart';

/// Badge de status colorido (Concluído, Em andamento, Pendente)
class StatusBadge extends StatelessWidget {
  final String label;
  final Color? color;

  const StatusBadge({
    super.key,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final badgeColor = color ?? _getColorForStatus(label);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: badgeColor,
        ),
      ),
    );
  }

  /// Retorna a cor adequada com base no status
  Color _getColorForStatus(String status) {
    switch (status.toLowerCase()) {
      case 'concluído':
        return AppColors.success;
      case 'em andamento':
        return AppColors.warning;
      case 'pendente':
        return AppColors.error;
      case 'alta':
        return AppColors.error;
      case 'média':
        return AppColors.warning;
      case 'baixa':
        return AppColors.info;
      default:
        return AppColors.textSecondary;
    }
  }
}
