import 'package:flutter/material.dart';

import 'tokens.dart';

/// One option in an equal-width segmented control (status filters, utility
/// toggles). Selected renders as a filled pill in [color]; unselected is an
/// outlined pill. Label, optional count, and optional icon scale down
/// together via [FittedBox] so a long label never truncates mid-word — it
/// shrinks as one unit instead.
class SegmentedChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;
  final int? count;
  final IconData? icon;

  const SegmentedChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.color,
    this.count,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final text = count == null ? label : '$label ($count)';
    final foreground = selected ? Colors.white : AppColors.textSecondary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? color : AppColors.divider),
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: foreground),
                const SizedBox(width: 4),
              ],
              Text(
                text,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lays out [children] — typically [SegmentedChip]s — at equal width,
/// filling the row edge-to-edge instead of leaving trailing space.
class SegmentedChipRow extends StatelessWidget {
  final List<Widget> children;
  final double spacing;

  const SegmentedChipRow({super.key, required this.children, this.spacing = 6});

  @override
  Widget build(BuildContext context) {
    final spaced = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) spaced.add(SizedBox(width: spacing));
      spaced.add(Expanded(child: children[i]));
    }
    return Row(children: spaced);
  }
}
