import 'dart:ui' show DisplayFeatureType;

import 'package:flutter/material.dart';

import '../../../theme/tokens.dart';

class CustomerCompactRail extends StatelessWidget {
  const CustomerCompactRail({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final cameraCutout = _leftRailCutout(mediaQuery);

    return Container(
      width: 72,
      color: Colors.white,
      child: SafeArea(
        left: false,
        right: false,
        child: Column(
          children: [
            ..._destinations(cameraCutout),
          ],
        ),
      ),
    );
  }

  Rect? _leftRailCutout(MediaQueryData mediaQuery) {
    for (final feature in mediaQuery.displayFeatures) {
      if (feature.type == DisplayFeatureType.cutout &&
          feature.bounds.left < 72 &&
          feature.bounds.right > 0) {
        return feature.bounds.translate(0, -mediaQuery.padding.top);
      }
    }
    return null;
  }

  List<Widget> _destinations(Rect? cameraCutout) {
    final destinations = <_CustomerRailDestination>[
      _CustomerRailDestination(
        icon: Icons.home_outlined,
        label: 'Home',
        tooltip: 'Home',
        selected: currentIndex == 0,
        onTap: () => onDestinationSelected(0),
      ),
      _CustomerRailDestination(
        icon: Icons.bar_chart_outlined,
        label: 'Usage',
        tooltip: 'Usage',
        selected: currentIndex == 1,
        onTap: () => onDestinationSelected(1),
      ),
      _CustomerRailDestination(
        icon: Icons.camera_alt_outlined,
        label: 'Report',
        tooltip: 'Report',
        selected: currentIndex == 2,
        onTap: () => onDestinationSelected(2),
      ),
      _CustomerRailDestination(
        icon: Icons.person_outline,
        label: 'Profile',
        tooltip: 'Profile',
        selected: currentIndex == 3,
        onTap: () => onDestinationSelected(3),
      ),
    ];

    final children = <Widget>[const SizedBox(height: 8)];
    var nextTop = 8.0;
    for (var index = 0; index < destinations.length; index++) {
      final nextBounds = Rect.fromLTWH(10, nextTop, 52, 54);
      if (cameraCutout != null && cameraCutout.contains(nextBounds.center)) {
        final shift = cameraCutout.bottom + 8 - nextTop;
        if (shift > 0) {
          children.add(SizedBox(height: shift));
          nextTop += shift;
        }
      }
      children.add(destinations[index]);
      nextTop += 54;
      if (index != destinations.length - 1) {
        children.add(const SizedBox(height: 8));
        nextTop += 8;
      }
    }
    return children;
  }
}

class _CustomerRailDestination extends StatelessWidget {
  const _CustomerRailDestination({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.customerPrimary : AppColors.textTertiary;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 52,
            height: 54,
            decoration: BoxDecoration(
              color: selected ? AppColors.customerSurface : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 21),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
