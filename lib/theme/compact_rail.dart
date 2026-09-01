import 'dart:ui' show DisplayFeatureType;

import 'package:flutter/material.dart';

import 'compact_rail_layout.dart';
import 'tokens.dart';

/// One entry in a [CompactRail]. The label doubles as the tooltip — all three
/// rails this replaced set them to the same string at every call site.
class RailDestination {
  final IconData icon;
  final String label;

  const RailDestination({required this.icon, required this.label});
}

/// The phone-landscape navigation rail, shared by every role.
///
/// Positioning lives entirely in [compactRailTops]; this widget only paints
/// what that returns. Colours come from [rolePrimary] / [roleSurface], so a
/// role is described by its name here rather than by a colour literal.
class CompactRail extends StatelessWidget {
  const CompactRail({
    super.key,
    required this.destinations,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.role,
    this.width = 88,
  });

  static const destinationWidth = 60.0;
  static const destinationHeight = 54.0;

  final List<RailDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final String? role;
  final double width;

  @override
  Widget build(BuildContext context) {
    final cutout = _leftRailCutout(MediaQuery.of(context));
    final accent = rolePrimary(role);
    final surface = roleSurface(role);

    return Container(
      width: width,
      color: Colors.white,
      child: SafeArea(
        left: false,
        right: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tops = compactRailTops(
              height: constraints.maxHeight,
              count: destinations.length,
              destinationHeight: destinationHeight,
              cutout: cutout,
            );

            return Stack(
              children: [
                for (var index = 0; index < destinations.length; index++)
                  Positioned(
                    left: (width - destinationWidth) / 2,
                    top: tops[index],
                    child: _RailDestinationButton(
                      destination: destinations[index],
                      selected: index == currentIndex,
                      accent: accent,
                      surface: surface,
                      onTap: () => onDestinationSelected(index),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// The camera cutout overlapping this rail, in rail-local coordinates.
  ///
  /// Offsets come back relative to the viewport, so the status-bar inset is
  /// subtracted to match the coordinate space [SafeArea] hands the children.
  Rect? _leftRailCutout(MediaQueryData mediaQuery) {
    for (final feature in mediaQuery.displayFeatures) {
      if (feature.type != DisplayFeatureType.cutout ||
          feature.bounds.right <= 0 ||
          feature.bounds.left >= width) {
        continue;
      }
      return feature.bounds.translate(0, -mediaQuery.viewPadding.top);
    }
    return null;
  }
}

class _RailDestinationButton extends StatelessWidget {
  const _RailDestinationButton({
    required this.destination,
    required this.selected,
    required this.accent,
    required this.surface,
    required this.onTap,
  });

  final RailDestination destination;
  final bool selected;
  final Color accent;
  final Color surface;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? accent : AppColors.textTertiary;

    return Tooltip(
      message: destination.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: CompactRail.destinationWidth,
            height: CompactRail.destinationHeight,
            decoration: BoxDecoration(
              color: selected ? surface : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(destination.icon, color: color, size: 21),
                const SizedBox(height: 2),
                Text(
                  destination.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
