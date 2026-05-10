import 'package:flutter/material.dart';
import 'package:study_hub/config/app_theme.dart';
import 'package:study_hub/widgets/app_surface.dart';

class AppMultiSelectField extends StatefulWidget {
  final String title;
  final List<String> options;
  final List<String> selectedValues;
  final ValueChanged<List<String>> onChanged;
  final bool enableSearch;
  final String? helperText;

  const AppMultiSelectField({
    super.key,
    required this.title,
    required this.options,
    required this.selectedValues,
    required this.onChanged,
    this.enableSearch = false,
    this.helperText,
  });

  @override
  State<AppMultiSelectField> createState() => _AppMultiSelectFieldState();
}

class _AppMultiSelectFieldState extends State<AppMultiSelectField> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final visibleOptions = widget.enableSearch && _query.trim().isNotEmpty
        ? widget.options
              .where(
                (option) =>
                    option.toLowerCase().contains(_query.trim().toLowerCase()),
              )
              .toList()
        : widget.options;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: widget.title,
          subtitle: widget.helperText,
          trailing: Text(
            '${widget.selectedValues.length} selecionado(s)',
            style: context.theme.textTheme.bodySmall,
          ),
        ),
        if (widget.enableSearch) ...[
          SizedBox(height: spacing.md),
          TextField(
            onChanged: (value) => setState(() => _query = value),
            decoration: const InputDecoration(
              hintText: 'Buscar opcoes',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
        ],
        SizedBox(height: spacing.md),
        Wrap(
          spacing: spacing.xs,
          runSpacing: spacing.xs,
          children: visibleOptions.map((option) {
            final isSelected = widget.selectedValues.contains(option);
            return _SelectionChip(
              label: option,
              isSelected: isSelected,
              onTap: () {
                final next = List<String>.from(widget.selectedValues);
                if (isSelected) {
                  next.remove(option);
                } else {
                  next.add(option);
                }
                widget.onChanged(next);
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _SelectionChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SelectionChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(spacing.pillRadius),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOutCubic,
          constraints: const BoxConstraints(minHeight: 40),
          padding: EdgeInsets.symmetric(
            horizontal: spacing.sm,
            vertical: spacing.xs,
          ),
          decoration: BoxDecoration(
            color: isSelected ? colors.chipSelectedBg : colors.chipIdleBg,
            borderRadius: BorderRadius.circular(spacing.pillRadius),
            border: Border.all(
              color: isSelected ? colors.chipSelectedBg : colors.borderSubtle,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelected) ...[
                Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: colors.chipSelectedFg,
                ),
                SizedBox(width: spacing.xs),
              ],
              Text(
                label,
                style: context.theme.textTheme.labelMedium?.copyWith(
                  color: isSelected ? colors.chipSelectedFg : colors.chipIdleFg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
