import 'dart:ui' show DisplayFeatureType;

import 'package:flutter/material.dart';

import '../../../theme/tokens.dart';

class AdminCompactRail extends StatelessWidget {
  const AdminCompactRail({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.onLogout,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onLogout;

  static const _cutoutClearance = 8.0;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final protectedCutout = _leftRailCutout(mediaQuery);

    return Container(
      width: 56,
      color: Colors.white,
      child: SafeArea(
        left: false,
        right: false,
        child: Column(
          children: [
            ..._primaryDestinations(protectedCutout),
            const Spacer(),
            _RailDestination(
              icon: Icons.logout_outlined,
              tooltip: 'Logout',
              selected: false,
              onTap: onLogout,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Rect? _leftRailCutout(MediaQueryData mediaQuery) {
    for (final feature in mediaQuery.displayFeatures) {
      if (feature.type != DisplayFeatureType.cutout ||
          feature.bounds.right <= 0 ||
          feature.bounds.left >= 56) {
        continue;
      }

      return feature.bounds.translate(0, -mediaQuery.padding.top);
    }
    return null;
  }

  List<Widget> _primaryDestinations(Rect? protectedCutout) {
    final destinations = <_RailDestination>[
      _RailDestination(
        icon: Icons.grid_view_outlined,
        tooltip: 'Dashboard',
        selected: currentIndex == 0,
        onTap: () => onDestinationSelected(0),
      ),
      _RailDestination(
        icon: Icons.notifications_outlined,
        tooltip: 'Alerts',
        selected: currentIndex == 2,
        onTap: () => onDestinationSelected(2),
      ),
      _RailDestination(
        icon: Icons.analytics_outlined,
        tooltip: 'AI Review',
        selected: currentIndex == 4,
        onTap: () => onDestinationSelected(4),
      ),
      _RailDestination(
        icon: Icons.inventory_2_outlined,
        tooltip: 'Inventory',
        selected: currentIndex == 1,
        onTap: () => onDestinationSelected(1),
      ),
      _RailDestination(
        icon: Icons.shield_outlined,
        tooltip: 'Oversight',
        selected: currentIndex == 3,
        onTap: () => onDestinationSelected(3),
      ),
    ];

    final children = <Widget>[];
    children.add(const SizedBox(height: 8));
    var nextTop = 8.0;
    for (var index = 0; index < destinations.length; index++) {
      final nextBounds = Rect.fromLTWH(6, nextTop, 44, 44);
      if (protectedCutout != null &&
          protectedCutout.contains(nextBounds.center)) {
        final shift = protectedCutout.bottom + _cutoutClearance - nextTop;
        if (shift > 0) {
          children.add(SizedBox(height: shift));
          nextTop += shift;
        }
      }

      children.add(destinations[index]);
      nextTop += 44;
      if (index != destinations.length - 1) {
        children.add(const SizedBox(height: 8));
        nextTop += 8;
      }
    }
    return children;
  }
}

class _RailDestination extends StatelessWidget {
  const _RailDestination({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.adminPrimary : AppColors.textTertiary;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: selected ? AppColors.adminSurface : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: color),
          ),
        ),
      ),
    );
  }
}
