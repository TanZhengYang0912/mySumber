import 'package:flutter/material.dart';

import '../modules/leakage/models/alert.dart';
import '../modules/leakage/models/report.dart';
import 'segmented_chips.dart';
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

/// Search + State/Severity/[Status] in one row. Used by both the Worker's
/// Alert Queue and the Admin's Oversight Alert Queue — one filter bar for
/// both, so they can't drift out of sync again. Pass null [statusOptions]
/// to hide the Status dropdown (Worker's Resolved tab has no per-item
/// status to filter by).
class AlertFilterBar extends StatelessWidget {
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback? onSearchClear;
  final Color accent;

  final String? selectedState;
  final List<String> states;
  final Map<String, int> stateCounts;
  final ValueChanged<String?> onStateChanged;

  final String? selectedSeverity;
  final Map<String, int> severityCounts;
  final ValueChanged<String?> onSeverityChanged;

  final String? selectedStatus;
  final List<String>? statusOptions;
  final Map<String, int>? statusCounts;
  final ValueChanged<String?>? onStatusChanged;

  const AlertFilterBar({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    required this.selectedState,
    required this.states,
    required this.stateCounts,
    required this.onStateChanged,
    required this.selectedSeverity,
    required this.severityCounts,
    required this.onSeverityChanged,
    this.onSearchClear,
    this.accent = AppColors.adminPrimary,
    this.selectedStatus,
    this.statusOptions,
    this.statusCounts,
    this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final showStatus = statusOptions != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilterSearchField(
          controller: searchController,
          hint: 'Type anything to search',
          accent: accent,
          onChanged: onSearchChanged,
          onClear: onSearchClear,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: FilterDropdown(
                caption: 'State',
                value: selectedState,
                allLabel: 'All',
                options: states,
                counts: stateCounts,
                onChanged: onStateChanged,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilterDropdown(
                caption: 'Severity',
                value: selectedSeverity,
                allLabel: 'All',
                options: const [Severity.high, Severity.medium, Severity.low],
                labelFor: Severity.label,
                counts: severityCounts,
                onChanged: onSeverityChanged,
              ),
            ),
            if (showStatus) ...[
              const SizedBox(width: 8),
              Expanded(
                child: FilterDropdown(
                  caption: 'Status',
                  value: selectedStatus,
                  allLabel: 'All',
                  options: statusOptions!,
                  labelFor: AlertStatus.label,
                  counts: statusCounts,
                  onChanged: onStatusChanged!,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Search + State/Outcome in one row. Used by both the Worker's Report
/// History and the Admin's Oversight Reports tab.
class ReportFilterBar extends StatelessWidget {
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback? onSearchClear;
  final Color accent;

  final String? selectedState;
  final List<String> states;
  final Map<String, int> stateCounts;
  final ValueChanged<String?> onStateChanged;

  final String? selectedOutcome;
  final Map<String, int> outcomeCounts;
  final ValueChanged<String?> onOutcomeChanged;

  const ReportFilterBar({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    required this.selectedState,
    required this.states,
    required this.stateCounts,
    required this.onStateChanged,
    required this.selectedOutcome,
    required this.outcomeCounts,
    required this.onOutcomeChanged,
    this.onSearchClear,
    this.accent = AppColors.adminPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilterSearchField(
          controller: searchController,
          hint: 'Type anything to search',
          accent: accent,
          onChanged: onSearchChanged,
          onClear: onSearchClear,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: FilterDropdown(
                caption: 'State',
                value: selectedState,
                allLabel: 'All',
                options: states,
                counts: stateCounts,
                onChanged: onStateChanged,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilterDropdown(
                caption: 'Outcome',
                value: selectedOutcome,
                allLabel: 'All',
                options: const [ReportOutcome.fixed, ReportOutcome.notFixed],
                labelFor: ReportOutcome.label,
                counts: outcomeCounts,
                onChanged: onOutcomeChanged,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The All / Water / Electricity toggle. Centred, because it is a short row
/// that looks stranded when it hugs the left edge.
class UtilityChips extends StatelessWidget {
  final Utility? selected;
  final ValueChanged<Utility?> onChanged;
  final Color color;
  final int? allCount;
  final int? waterCount;
  final int? electricityCount;

  const UtilityChips({
    super.key,
    required this.selected,
    required this.onChanged,
    this.color = AppColors.adminPrimary,
    this.allCount,
    this.waterCount,
    this.electricityCount,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedChipRow(
      spacing: 8,
      centered: true,
      children: [
        SegmentedChip(
          label: 'All',
          count: allCount,
          selected: selected == null,
          onTap: () => onChanged(null),
          color: color,
        ),
        SegmentedChip(
          label: 'Water',
          icon: Icons.water_drop_outlined,
          count: waterCount,
          selected: selected == Utility.water,
          onTap: () => onChanged(Utility.water),
          color: color,
        ),
        SegmentedChip(
          label: 'Electricity',
          icon: Icons.electric_bolt_outlined,
          count: electricityCount,
          selected: selected == Utility.electricity,
          onTap: () => onChanged(Utility.electricity),
          color: color,
        ),
      ],
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
