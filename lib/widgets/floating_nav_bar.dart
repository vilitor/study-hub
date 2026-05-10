import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:study_hub/config/app_theme.dart';

class NavItem {
  final IconData icon;
  final String label;

  const NavItem({required this.icon, required this.label});
}

class FloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final bool isVisible;
  final List<NavItem> items;
  final ValueChanged<int> onTap;

  const FloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.isVisible,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final colors = context.colors;

    final navBackground = Color.alphaBlend(
      colors.navBackground.withValues(alpha: 0.76),
      colors.scaffoldBase.withValues(alpha: 0.18),
    );

    return AnimatedSlide(
      duration: isVisible
          ? const Duration(milliseconds: 220)
          : const Duration(milliseconds: 200),
      curve: isVisible ? Curves.easeOutCubic : Curves.easeInCubic,
      offset: isVisible ? Offset.zero : const Offset(0, 1.4),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        curve: isVisible ? Curves.easeOutCubic : Curves.easeInCubic,
        opacity: isVisible ? 1 : 0.98,
        child: IgnorePointer(
          ignoring: !isVisible,
          child: SafeArea(
            minimum: EdgeInsets.fromLTRB(spacing.md, 0, spacing.md, spacing.sm),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(spacing.pillRadius),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  height: 68,
                  padding: EdgeInsets.symmetric(
                    horizontal: spacing.sm,
                    vertical: spacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: navBackground,
                    borderRadius: BorderRadius.circular(spacing.pillRadius),
                    border: Border.all(
                      color: colors.borderSubtle.withValues(alpha: 0.72),
                    ),
                    boxShadow: context.elevations.medium,
                  ),
                  child: Row(
                    children: List.generate(items.length, (index) {
                      final selected = index == currentIndex;
                      return Expanded(
                        child: _NavBarButton(
                          item: items[index],
                          selected: selected,
                          onTap: () => onTap(index),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavBarButton extends StatelessWidget {
  final NavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _NavBarButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: Center(
        child: SizedBox(
          width: 56,
          height: 56,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(spacing.pillRadius),
              onTap: onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  color: selected
                      ? colors.navActive.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(spacing.pillRadius),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: colors.accent.withValues(alpha: 0.18),
                            blurRadius: 16,
                            spreadRadius: 0,
                          ),
                        ]
                      : null,
                ),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 1, end: selected ? 1.15 : 1),
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  builder: (context, scale, child) {
                    return Transform.scale(scale: scale, child: child);
                  },
                  child: Icon(
                    item.icon,
                    size: 24,
                    color: selected ? colors.accent : colors.navInactive,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
