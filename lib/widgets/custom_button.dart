import 'dart:async';

import 'package:flutter/material.dart';
import 'package:study_hub/config/app_theme.dart';

class CustomButton extends StatelessWidget {
  final String label;
  final FutureOr<void> Function()? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isOutlined;
  final Color? color;
  final double? width;

  const CustomButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isOutlined = false,
    this.color,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final resolvedColor = color ?? colors.accent;

    final iconWidget = isLoading
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: isOutlined ? resolvedColor : colors.textOnAccent,
            ),
          )
        : icon != null
        ? Icon(icon, size: 18)
        : const SizedBox.shrink();

    final labelWidget = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null || isLoading) ...[
          iconWidget,
          SizedBox(width: spacing.xs),
        ],
        Flexible(child: labelWidget),
      ],
    );

    if (isOutlined) {
      return SizedBox(
        width: width ?? double.infinity,
        child: OutlinedButton(
          onPressed: isLoading || onPressed == null
              ? null
              : () {
                  onPressed!.call();
                },
          style: OutlinedButton.styleFrom(
            foregroundColor: resolvedColor,
            side: BorderSide(color: resolvedColor),
            backgroundColor: colors.surface1,
          ),
          child: child,
        ),
      );
    }

    return SizedBox(
      width: width ?? double.infinity,
      child: ElevatedButton(
        onPressed: isLoading || onPressed == null
            ? null
            : () {
                onPressed!.call();
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: resolvedColor,
          foregroundColor: colors.textOnAccent,
        ),
        child: child,
      ),
    );
  }
}
