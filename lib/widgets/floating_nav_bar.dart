import 'package:flutter/material.dart';
import 'package:study_hub/config/app_theme.dart';

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
  static const Color _navBgColor = Color(0xFF1E1E2D); // Deep dark navy/black
  static const double _navBarHeight = 64.0;
  static const double _horizontalPadding = 8.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 30), // Floating effect
      height: _navBarHeight,
      decoration: BoxDecoration(
        color: _navBgColor,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
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
                    color: Colors.white,
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
    );
  }
}

class _NavBarItemWidget extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;

  const _NavBarItemWidget({
    required this.icon,
    required this.label,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 300),
      style: TextStyle(
        color: isSelected ? const Color(0xFF1E1E2D) : Colors.white.withValues(alpha: 0.6),
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      child: IconTheme(
        data: IconThemeData(
          color: isSelected ? const Color(0xFF1E1E2D) : Colors.white.withValues(alpha: 0.6),
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
