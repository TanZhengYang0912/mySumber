import 'package:flutter/material.dart';

import '../modules/leakage/models/alert.dart';
import 'tokens.dart';

/// Tallies how many items in [source] fall under each value [keyOf] returns.
/// Feeds [FilterDropdown.counts] / [SegmentedChip.count] so filter options
/// can show "Pending (5)" instead of a bare label.
Map<String, int> countBy<T>(Iterable<T> source, String Function(T) keyOf) {
  final counts = <String, int>{};
  for (final item in source) {
    final key = keyOf(item);
    counts[key] = (counts[key] ?? 0) + 1;
  }
  return counts;
}

/// The search box every filterable list uses. One look across admin, worker,
/// and inventory instead of the four near-identical TextFields we had.
class FilterSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;

  /// Focus border colour. Defaults to the admin teal.
  final Color? accent;

  /// When given, a clear button appears once the field has text.
  final VoidCallback? onClear;

  const FilterSearchField({
    super.key,
    required this.controller,
    required this.hint,
    this.onChanged,
    this.accent,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final focus = accent ?? AppColors.adminPrimary;
    final showClear = onClear != null && controller.text.isNotEmpty;

    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textTertiary),
        prefixIcon:
            const Icon(Icons.search, size: 20, color: AppColors.textTertiary),
        suffixIcon: showClear
            ? IconButton(
                icon: const Icon(Icons.close,
                    size: 18, color: AppColors.textTertiary),
                onPressed: onClear,
              )
            : null,
        isDense: true,
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: focus),
        ),
      ),
    );
  }
}

/// A filter dropdown where null means "everything". [labelFor] lets a caller
/// decorate option text — counts, humanised status names — without needing a
/// second dropdown widget.
class FilterDropdown extends StatelessWidget {
  final String? value;
  final String allLabel;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  final String Function(String)? labelFor;

  /// Optional caption rendered above the control rather than as a floating
  /// label, so it never collides with the border.
  final String? caption;

  /// Per-option counts, keyed by option value. When given, every option (and
  /// "All") shows how many rows it matches — e.g. "Pending (5)". Counts
  /// should already reflect every other active filter, so the numbers stay
  /// truthful as the user narrows down.
  final Map<String, int>? counts;

  const FilterDropdown({
    super.key,
    required this.value,
    required this.allLabel,
    required this.options,
    required this.onChanged,
    this.labelFor,
    this.caption,
    this.counts,
  });

  @override
  Widget build(BuildContext context) {
    final decorate = labelFor ?? ((String option) => option);
    String withCount(String label, String? option) {
      if (counts == null) return label;
      final n = option == null
          ? counts!.values.fold(0, (sum, v) => sum + v)
          : counts![option] ?? 0;
      return '$label ($n)';
    }

    final field = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: DropdownButtonHideUnderline(
        // No `hint:` here on purpose. DropdownButton keeps its hint in the
        // widget tree as an extra IndexedStack child, so a hint plus a null
        // item with the same text puts `allLabel` in the tree twice and breaks
        // `findsOneWidget` assertions. The null item alone covers the "all"
        // case. (Oversight's old `_dropdown` had exactly this double-render.)
        child: DropdownButton<String?>(
          value: value,
          isExpanded: true,
          isDense: true,
          items: [
            DropdownMenuItem<String?>(
                value: null, child: Text(withCount(allLabel, null))),
            ...options.map((option) => DropdownMenuItem<String?>(
                  value: option,
                  child: Text(withCount(decorate(option), option),
                      overflow: TextOverflow.ellipsis),
                )),
          ],
          onChanged: onChanged,
          style: const TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600),
        ),
      ),
    );

    if (caption == null) return field;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          caption!,
          style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        field,
      ],
    );
  }
}

/// The standard Utility filter. Null remains the unfiltered All state, while
/// the page continues to own the data matching and optional count calculation.
class UtilityFilterDropdown extends StatelessWidget {
  const UtilityFilterDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    this.counts,
  });

  final Utility? value;
  final ValueChanged<Utility?> onChanged;
  final Map<String, int>? counts;

  @override
  Widget build(BuildContext context) {
    return FilterDropdown(
      caption: 'Utility',
      value: value?.name,
      allLabel: 'All',
      options: const ['water', 'electricity'],
      labelFor: (option) => option == 'water' ? 'Water' : 'Electricity',
      counts: counts,
      onChanged: (option) => onChanged(
        option == 'water'
            ? Utility.water
            : option == 'electricity'
                ? Utility.electricity
                : null,
      ),
    );
  }
}

/// A row of [StatCell]s. Landscape pins them to a fixed width and centres the
/// row; portrait shares the width evenly.
class SummaryRow extends StatelessWidget {
  final List<Widget> cells;
  final bool compact;

  const SummaryRow({super.key, required this.cells, this.compact = false});

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var index = 0; index < cells.length; index++) ...[
            if (index > 0) const SizedBox(width: 10),
            SizedBox(width: 164, child: cells[index]),
          ],
        ],
      );
    }

    return Row(
      children: [
        for (var index = 0; index < cells.length; index++) ...[
          if (index > 0) const SizedBox(width: 10),
          Expanded(child: cells[index]),
        ],
      ],
    );
  }
}

/// The small red count that rides next to a tab label.
class CountBadge extends StatelessWidget {
  final int count;

  const CountBadge(this.count, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.criticalSurface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
            color: AppColors.critical,
            fontSize: 11,
            fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// What a filtered list shows when nothing matches. One wording style across
/// every screen, so a narrowed queue never looks like a broken one.
class FilterEmptyState extends StatelessWidget {
  final String message;

  const FilterEmptyState(this.message, {super.key});

  @override
  Widget build(BuildContext context) => Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      );
}
