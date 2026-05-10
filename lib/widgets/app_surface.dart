import 'package:flutter/material.dart';
import 'package:study_hub/config/app_theme.dart';

class AppSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final List<BoxShadow>? shadow;
  final double? radius;
  final Border? border;

  const AppSurface({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.color,
    this.shadow,
    this.radius,
    this.border,
  });

  const AppSurface.subtle({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.radius,
  }) : color = null,
       shadow = null,
       border = null;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final colors = context.colors;
    return Container(
      margin: margin,
      padding: padding ?? EdgeInsets.all(spacing.lg),
      decoration: BoxDecoration(
        color: color ?? colors.surface1,
        borderRadius: BorderRadius.circular(radius ?? spacing.cardRadius),
        border: border ?? Border.all(color: colors.borderSubtle),
        boxShadow: shadow ?? context.elevations.low,
      ),
      child: child,
    );
  }
}

class AppSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const AppSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.theme.textTheme.titleLarge),
              if (subtitle != null) ...[
                SizedBox(height: spacing.xs),
                Text(subtitle!, style: context.theme.textTheme.bodySmall),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[SizedBox(width: spacing.md), trailing!],
      ],
    );
  }
}
