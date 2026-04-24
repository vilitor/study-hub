import 'package:flutter/material.dart';
import 'dart:ui';

/// Item data for the FloatingNavBar
class NavItem {
  final IconData icon;
  final String label;

  NavItem({required this.icon, required this.label});
}

/// A premium, floating capsule-style Bottom Navigation Bar.
/// Inspired by high-end product designs (pill-shaped with sliding indicator).
class FloatingNavBar extends StatefulWidget {
  final int currentIndex;
  final List<NavItem> items;
  final Function(int) onTap;

  const FloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.items,
    required this.onTap,
  });

  @override
  State<FloatingNavBar> createState() => _FloatingNavBarState();
}

class _FloatingNavBarState extends State<FloatingNavBar> {
  static const double _navBarHeight = 64.0;
  static const double _horizontalPadding = 8.0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Frosted glass colors: dark "smoke" tint for both modes
    final navBgColor = isDark 
        ? const Color(0xFF1E1E2D).withValues(alpha: 0.75)
        : const Color(0xFF121212).withValues(alpha: 0.7); 
    
    final indicatorColor = Theme.of(context).colorScheme.primary;
    final unselectedColor = Colors.white.withValues(alpha: 0.5);

    return SafeArea(
      bottom: true,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        height: _navBarHeight,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                color: navBgColor,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08), 
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final double totalWidth = constraints.maxWidth;
                  final double itemWidth = (totalWidth - (_horizontalPadding * 2)) / widget.items.length;

                  return Stack(
                    children: [
                      // --- Sliding Pill Background Indicator ---
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.elasticOut,
                        left: _horizontalPadding + (widget.currentIndex * itemWidth),
                        top: 8,
                        bottom: 8,
                        width: itemWidth,
                        child: Container(
                          decoration: BoxDecoration(
                            color: indicatorColor,
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                      ),

                      // --- Icons and Labels ---
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
                        child: Row(
                          children: List.generate(widget.items.length, (index) {
                            final item = widget.items[index];
                            final isSelected = widget.currentIndex == index;

                            return Expanded(
                              child: GestureDetector(
                                onTap: () => widget.onTap(index),
                                behavior: HitTestBehavior.opaque,
                                child: _NavBarItemWidget(
                                  icon: item.icon,
                                  label: item.label,
                                  isSelected: isSelected,
                                  selectedColor: Colors.white,
                                  unselectedColor: unselectedColor,
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavBarItemWidget extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final Color selectedColor;
  final Color unselectedColor;

  const _NavBarItemWidget({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.selectedColor,
    required this.unselectedColor,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 300),
      style: TextStyle(
        color: isSelected ? selectedColor : unselectedColor,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      child: IconTheme(
        data: IconThemeData(
          color: isSelected ? selectedColor : unselectedColor,
          size: 22,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              width: isSelected ? 8 : 0,
            ),
            if (isSelected)
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
