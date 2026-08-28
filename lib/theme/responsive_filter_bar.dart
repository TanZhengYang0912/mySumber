import 'package:flutter/material.dart';

import 'filter_controls.dart';
import 'landscape_filter_menu.dart';
import 'tokens.dart';

enum ResponsiveFilterBarMode { inline, menu }

int countActiveFilters({
  required String query,
  required Iterable<bool> filters,
}) =>
    (query.trim().isNotEmpty ? 1 : 0) +
    filters.where((active) => active).length;

class FilterDropdownGrid extends StatelessWidget {
  const FilterDropdownGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < children.length; index += 2) ...[
          if (index > 0) const SizedBox(height: 8),
          if (index + 1 < children.length)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: children[index]),
                const SizedBox(width: 8),
                Expanded(child: children[index + 1]),
              ],
            )
          else
            SizedBox(width: double.infinity, child: children[index]),
        ],
      ],
    );
  }
}

class ResponsiveFilterBar extends StatelessWidget {
  const ResponsiveFilterBar({
    super.key,
    required this.mode,
    required this.searchController,
    required this.onSearchChanged,
    required this.filters,
    this.searchHint = 'Type anything to search',
    this.accent = AppColors.adminPrimary,
    this.activeFilterCount = 0,
    this.menuLabel = 'Filters',
    this.menuTooltip = 'Filter results',
  });

  final ResponsiveFilterBarMode mode;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final List<Widget> filters;
  final String searchHint;
  final Color accent;
  final int activeFilterCount;
  final String menuLabel;
  final String menuTooltip;

  Widget get _panel => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilterSearchField(
            controller: searchController,
            hint: searchHint,
            accent: accent,
            onChanged: onSearchChanged,
          ),
          if (filters.isNotEmpty) ...[
            const SizedBox(height: 8),
            FilterDropdownGrid(children: filters),
          ],
        ],
      );

  @override
  Widget build(BuildContext context) {
    if (mode == ResponsiveFilterBarMode.menu) {
      return LandscapeFilterMenu(
        compact: true,
        label: menuLabel,
        tooltip: menuTooltip,
        activeCount: activeFilterCount,
        accent: accent,
        child: _panel,
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: _panel,
    );
  }
}
