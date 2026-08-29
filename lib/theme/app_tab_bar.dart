import 'package:flutter/material.dart';

import 'filter_controls.dart';
import 'tokens.dart';

/// The white tab strip every tabbed list screen was hand-rolling. Only the
/// accent differs between roles, so that is the one knob callers get.
class AppTabBar extends StatelessWidget {
  final TabController controller;
  final List<({String label, int count})> tabs;
  final Color accent;

  const AppTabBar({
    super.key,
    required this.controller,
    required this.tabs,
    this.accent = AppColors.adminPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: controller,
        labelColor: accent,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        indicatorColor: accent,
        indicatorWeight: 3,
        dividerColor: AppColors.divider,
        tabs: [
          // FittedBox keeps three labels legible on a phone, where "Household"
          // plus its badge would otherwise overflow the tab width.
          for (final tab in tabs)
            Tab(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(tab.label),
                    const SizedBox(width: 6),
                    CountBadge(tab.count),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
