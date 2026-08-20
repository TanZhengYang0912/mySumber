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

  static const _cutoutClearance = 2.0;
  static const _destinationHeight = 36.0;
  static const _destinationGap = 2.0;
  static const _railTopInset = 8.0;
  static const _railBottomInset = 54.0;

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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final destinations = _primaryDestinations();
            final firstTop = _railTopInset;
            final lastTop =
                (constraints.maxHeight - _destinationHeight - _railBottomInset)
                    .clamp(firstTop, double.infinity)
                    .toDouble();
            final tops = _destinationTops(
              firstTop: firstTop,
              lastTop: lastTop,
              count: destinations.length,
              protectedCutout: protectedCutout,
            );

            return Stack(
              children: [
                for (var index = 0; index < destinations.length; index++) ...[
                  Positioned(
                    left: 6,
                    top: tops[index],
                    child: destinations[index],
                  ),
                ],
              ],
            );
          },
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

      return feature.bounds.translate(0, -mediaQuery.viewPadding.top);
    }
    return null;
  }

  List<Widget> _primaryDestinations() {
    return <Widget>[
      _RailDestination(
        icon: Icons.grid_view_outlined,
        tooltip: 'Dashboard',
        selected: currentIndex == 0,
        onTap: () => onDestinationSelected(0),
      ),
      _RailDestination(
        icon: Icons.inventory_2_outlined,
        tooltip: 'Inventory',
        selected: currentIndex == 1,
        onTap: () => onDestinationSelected(1),
      ),
      _RailDestination(
        icon: Icons.notifications_outlined,
        tooltip: 'Anomalies',
        selected: currentIndex == 2,
        onTap: () => onDestinationSelected(2),
      ),
      _RailDestination(
        icon: Icons.shield_outlined,
        tooltip: 'Oversight',
        selected: currentIndex == 3,
        onTap: () => onDestinationSelected(3),
      ),
      _MoreRailDestination(
        currentIndex: currentIndex,
        onDestinationSelected: onDestinationSelected,
        onLogout: onLogout,
      ),
    ];
  }

  List<double> _destinationTops({
    required double firstTop,
    required double lastTop,
    required int count,
    required Rect? protectedCutout,
  }) {
    final idealStep = count <= 1 ? 0.0 : (lastTop - firstTop) / (count - 1);
    final idealTops = [
      for (var index = 0; index < count; index++) firstTop + idealStep * index,
    ];
    if (protectedCutout == null) {
      return idealTops;
    }

    // Treat the camera as a reserved slot in the rail. Evaluate every split
    // of the ordered destinations around that slot and choose the split that
    // gives the best spacing in the two usable segments. This prevents one
    // shifted item from forcing all following items to collapse together.
    final topSegmentEnd =
        protectedCutout.top - _cutoutClearance - _destinationHeight;
    final bottomSegmentStart = protectedCutout.bottom + _cutoutClearance;
    final candidates = <_RailLayoutCandidate>[];

    for (var beforeCount = 0; beforeCount <= count; beforeCount++) {
      final afterCount = count - beforeCount;
      if (beforeCount > 0 && topSegmentEnd < firstTop) {
        continue;
      }
      if (afterCount > 0 && bottomSegmentStart > lastTop) {
        continue;
      }

      final tops = [
        ..._evenlySpacedTops(firstTop, topSegmentEnd, beforeCount),
        ..._evenlySpacedTops(bottomSegmentStart, lastTop, afterCount),
      ];
      candidates.add(
        _RailLayoutCandidate(
          tops: tops,
          minimumGap: _minimumInternalGap(tops, beforeCount),
          distanceFromIdeal: _distanceFromIdeal(tops, idealTops),
        ),
      );
    }

    if (candidates.isEmpty) {
      return _fallbackDestinationTops(
        idealTops: idealTops,
        firstTop: firstTop,
        lastTop: lastTop,
        protectedCutout: protectedCutout,
      );
    }

    candidates.sort((a, b) {
      final gapComparison = b.minimumGap.compareTo(a.minimumGap);
      if (gapComparison != 0) {
        return gapComparison;
      }
      return a.distanceFromIdeal.compareTo(b.distanceFromIdeal);
    });
    return candidates.first.tops;
  }

  List<double> _evenlySpacedTops(double start, double end, int count) {
    if (count == 0) {
      return const [];
    }
    if (count == 1) {
      return [(start + end) / 2];
    }
    final step = (end - start) / (count - 1);
    return [for (var index = 0; index < count; index++) start + step * index];
  }

  double _minimumInternalGap(List<double> tops, int beforeCount) {
    var minimum = double.infinity;
    for (var index = 1; index < beforeCount; index++) {
      final gap = tops[index] - tops[index - 1] - _destinationHeight;
      if (gap < minimum) {
        minimum = gap;
      }
    }
    for (var index = beforeCount + 1; index < tops.length; index++) {
      final gap = tops[index] - tops[index - 1] - _destinationHeight;
      if (gap < minimum) {
        minimum = gap;
      }
    }
    return minimum == double.infinity ? 0.0 : minimum;
  }

  double _distanceFromIdeal(List<double> tops, List<double> idealTops) {
    var distance = 0.0;
    for (var index = 0; index < tops.length; index++) {
      distance += (tops[index] - idealTops[index]).abs();
    }
    return distance;
  }

  List<double> _fallbackDestinationTops({
    required List<double> idealTops,
    required double firstTop,
    required double lastTop,
    required Rect protectedCutout,
  }) {
    final tops = <double>[];
    var previousTop = double.negativeInfinity;
    for (var index = 0; index < idealTops.length; index++) {
      final top = _destinationTop(
        idealTop: idealTops[index],
        minTop: index == 0
            ? firstTop
            : previousTop + _destinationHeight + _destinationGap,
        maxTop: lastTop,
        protectedCutout: protectedCutout,
      );
      tops.add(top);
      previousTop = top;
    }
    return tops;
  }

  double _destinationTop({
    required double idealTop,
    required double minTop,
    required double maxTop,
    required Rect? protectedCutout,
  }) {
    // A very short landscape viewport can make the previous destination's
    // minimum top exceed the bottom-safe limit. Collapse that constraint to
    // the available edge instead of passing reversed bounds to clamp().
    final safeMinTop = minTop > maxTop ? maxTop : minTop;
    final boundedIdealTop = idealTop.clamp(safeMinTop, maxTop).toDouble();
    final idealBounds = Rect.fromLTWH(
      6,
      boundedIdealTop,
      44,
      _destinationHeight,
    );
    if (protectedCutout == null || !idealBounds.overlaps(protectedCutout)) {
      return boundedIdealTop;
    }

    final candidates = [
      (protectedCutout.top - _destinationHeight - _cutoutClearance)
          .clamp(safeMinTop, maxTop)
          .toDouble(),
      (protectedCutout.bottom + _cutoutClearance)
          .clamp(safeMinTop, maxTop)
          .toDouble(),
    ]
        .where(
          (candidate) => !Rect.fromLTWH(
            6,
            candidate,
            44,
            _destinationHeight,
          ).overlaps(protectedCutout),
        )
        .toList();
    if (candidates.isEmpty) {
      return boundedIdealTop;
    }
    candidates.sort(
      (a, b) =>
          (a - boundedIdealTop).abs().compareTo((b - boundedIdealTop).abs()),
    );
    return candidates.first;
  }
}

enum _AdminMoreAction { workers, logout }

class _MoreRailDestination extends StatelessWidget {
  const _MoreRailDestination({
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.onLogout,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final selected = currentIndex == 4;
    final color = selected ? AppColors.adminPrimary : AppColors.textTertiary;
    return PopupMenuButton<_AdminMoreAction>(
      tooltip: 'More',
      position: PopupMenuPosition.over,
      offset: const Offset(48, 0),
      padding: EdgeInsets.zero,
      onSelected: (action) {
        switch (action) {
          case _AdminMoreAction.workers:
            onDestinationSelected(4);
          case _AdminMoreAction.logout:
            onLogout();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _AdminMoreAction.workers,
          child: _menuItem(Icons.manage_accounts_outlined, 'Workers'),
        ),
        PopupMenuItem(
          value: _AdminMoreAction.logout,
          child: _menuItem(Icons.logout_outlined, 'Logout'),
        ),
      ],
      child: Container(
        width: 44,
        height: AdminCompactRail._destinationHeight,
        decoration: BoxDecoration(
          color: selected ? AppColors.adminSurface : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Icon(Icons.more_horiz, color: color),
      ),
    );
  }

  Widget _menuItem(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Text(label),
      ],
    );
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
            height: AdminCompactRail._destinationHeight,
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

class _RailLayoutCandidate {
  const _RailLayoutCandidate({
    required this.tops,
    required this.minimumGap,
    required this.distanceFromIdeal,
  });

  final List<double> tops;
  final double minimumGap;
  final double distanceFromIdeal;
}
