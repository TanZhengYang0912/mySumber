import 'dart:ui' show DisplayFeatureType;

import 'package:flutter/material.dart';

import '../../../theme/tokens.dart';
import '../models/alert.dart';
import '../services/worker_utility_colors.dart';

/// Compact Worker navigation for a phone in landscape orientation.
class WorkerCompactRail extends StatelessWidget {
  const WorkerCompactRail({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.onLogout,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onLogout;

  /// Electricity sits fixed right below Water — only Reports floats to
  /// dodge a camera cutout, since floating both non-Water items risks them
  /// swapping order on odd screen heights.
  static const _electricityTop = 108.0;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final cameraCutout = _leftRailCutout(mediaQuery);

    return Container(
      width: 88,
      color: Colors.white,
      child: SafeArea(
        left: false,
        right: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final logoutTop = constraints.maxHeight - 80;
            return Stack(
              children: [
                Positioned(
                  left: 14,
                  top: 36,
                  child: _utilityDestination(0),
                ),
                Positioned(
                  left: 14,
                  top: _electricityTop,
                  child: _utilityDestination(1),
                ),
                Positioned(
                  left: 14,
                  top: _middleDestinationTop(
                    height: constraints.maxHeight,
                    logoutTop: logoutTop,
                    cameraCutout: cameraCutout,
                  ),
                  child: _WorkerRailDestination(
                    icon: Icons.description_outlined,
                    label: 'Reports',
                    selected: currentIndex == 2,
                    onTap: () => onDestinationSelected(2),
                  ),
                ),
                Positioned(
                  left: 14,
                  top: logoutTop,
                  child: _WorkerRailDestination(
                    icon: Icons.logout_outlined,
                    label: 'Logout',
                    selected: false,
                    onTap: onLogout,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Rect? _leftRailCutout(MediaQueryData mediaQuery) {
    for (final feature in mediaQuery.displayFeatures) {
      if (feature.type == DisplayFeatureType.cutout &&
          feature.bounds.left < 88 &&
          feature.bounds.right > 0) {
        return feature.bounds.translate(0, -mediaQuery.padding.top);
      }
    }
    return null;
  }

  _WorkerRailDestination _utilityDestination(int index) {
    if (index == 0) {
      return _WorkerRailDestination(
        icon: Icons.water_drop_outlined,
        label: 'Water',
        selected: currentIndex == 0,
        selectedColor: workerUtilityPrimary(Utility.water),
        selectedSurface: workerUtilitySurface(Utility.water),
        onTap: () => onDestinationSelected(0),
      );
    }
    return _WorkerRailDestination(
      icon: Icons.electric_bolt_outlined,
      label: 'Electricity',
      selected: currentIndex == 1,
      selectedColor: workerUtilityPrimary(Utility.electricity),
      selectedSurface: workerUtilitySurface(Utility.electricity),
      onTap: () => onDestinationSelected(1),
    );
  }

  double _middleDestinationTop({
    required double height,
    required double logoutTop,
    required Rect? cameraCutout,
  }) {
    const destinationHeight = 64.0;
    const clearance = 8.0;
    const minimumTop = _electricityTop + destinationHeight + clearance;
    final maximumTop = logoutTop - destinationHeight - clearance;
    final centeredTop = ((height - destinationHeight) / 2)
        .clamp(minimumTop, maximumTop)
        .toDouble();

    if (cameraCutout == null ||
        !Rect.fromLTWH(14, centeredTop, 60, destinationHeight)
            .overlaps(cameraCutout)) {
      return centeredTop;
    }

    final above = (cameraCutout.top - destinationHeight - clearance)
        .clamp(minimumTop, maximumTop)
        .toDouble();
    final below = (cameraCutout.bottom + clearance)
        .clamp(minimumTop, maximumTop)
        .toDouble();
    return (centeredTop - above).abs() <= (below - centeredTop).abs()
        ? above
        : below;
  }
}

class _WorkerRailDestination extends StatelessWidget {
  const _WorkerRailDestination({
    required this.icon,
    required this.label,
    required this.selected,
    this.selectedColor = AppColors.workerPrimary,
    this.selectedSurface = AppColors.workerSurface,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final Color selectedColor;
  final Color selectedSurface;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? selectedColor : AppColors.textTertiary;
    return Tooltip(
      message: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 60,
            height: 64,
            decoration: BoxDecoration(
              color: selected ? selectedSurface : Colors.transparent,
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
