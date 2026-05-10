import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:study_hub/config/app_theme.dart';
import 'package:study_hub/widgets/app_surface.dart';

class IntegrationButton extends StatelessWidget {
  final Widget mark;
  final String title;
  final String subtitle;
  final bool isConnected;
  final bool isLoading;
  final VoidCallback? onTap;
  final Color? accentColor;

  const IntegrationButton({
    super.key,
    required this.mark,
    required this.title,
    required this.subtitle,
    required this.isConnected,
    this.isLoading = false,
    this.onTap,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tone = accentColor ?? colors.accent;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(18),
        child: AppSurface(
          radius: 18,
          padding: EdgeInsets.all(context.spacing.md),
          color: Color.alphaBlend(
            tone.withValues(alpha: isConnected ? 0.045 : 0.018),
            colors.surfaceElevated,
          ),
          border: Border.all(
            color: isConnected
                ? tone.withValues(alpha: 0.24)
                : colors.borderSubtle,
          ),
          shadow: context.elevations.low,
          child: Row(
            children: [
              _MarkTile(child: mark),
              SizedBox(width: context.spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: context.theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: context.theme.textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(width: context.spacing.sm),
              if (isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                _StatusPill(isConnected: isConnected, tone: tone),
            ],
          ),
        ),
      ),
    );
  }
}

class GoogleBrandMark extends StatelessWidget {
  const GoogleBrandMark({super.key});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/integrations/google_logo.svg',
      width: 24,
      height: 24,
      fit: BoxFit.contain,
    );
  }
}

class NotionBrandMark extends StatelessWidget {
  const NotionBrandMark({super.key});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/integrations/notion_logo.svg',
      width: 24,
      height: 24,
      fit: BoxFit.contain,
    );
  }
}

class _MarkTile extends StatelessWidget {
  final Widget child;

  const _MarkTile({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.colors.surface1,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: context.colors.borderSubtle),
      ),
      child: child,
    );
  }
}

class _StatusPill extends StatelessWidget {
  final bool isConnected;
  final Color tone;

  const _StatusPill({required this.isConnected, required this.tone});

  @override
  Widget build(BuildContext context) {
    final color = isConnected
        ? context.colors.success
        : context.colors.textDisabled;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Icon(
        isConnected ? Icons.check_rounded : Icons.arrow_forward_rounded,
        color: isConnected ? context.colors.success : tone,
        size: 16,
      ),
    );
  }
}
