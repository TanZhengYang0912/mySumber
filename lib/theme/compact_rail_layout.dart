import 'dart:ui';

/// Vertical offsets for a compact rail's destinations, centred as one group.
///
/// The group moves as a unit. When it would sit under a camera cutout the
/// whole run shifts to the nearer clear side, rather than nudging one button
/// out of line and breaking the rhythm — which is what the three hand-rolled
/// rails this replaced each did differently.
///
/// Returns one top per destination, in order.
List<double> compactRailTops({
  required double height,
  required int count,
  double destinationHeight = 54,
  double spacing = 8,
  double topInset = 8,
  double bottomInset = 8,
  double cutoutClearance = 2,
  Rect? cutout,
}) {
  if (count <= 0) return const <double>[];

  final groupHeight = count * destinationHeight + (count - 1) * spacing;
  final minimumTop = topInset;
  final maximumTop = height - bottomInset - groupHeight;

  // A rail shorter than its own destinations pins the group to the top. The
  // last destination overflows, which is recoverable by scrolling the device
  // into a taller orientation; starting above the inset would instead hide
  // the first one behind the status bar.
  if (maximumTop <= minimumTop) {
    return _offsetsFrom(minimumTop, count, destinationHeight, spacing);
  }

  final centred =
      ((height - groupHeight) / 2).clamp(minimumTop, maximumTop).toDouble();
  var start = centred;

  if (cutout != null) {
    final blockedTop = cutout.top - cutoutClearance;
    final blockedBottom = cutout.bottom + cutoutClearance;
    final overlapsCutout =
        centred < blockedBottom && centred + groupHeight > blockedTop;

    if (overlapsCutout) {
      final above =
          (blockedTop - groupHeight).clamp(minimumTop, maximumTop).toDouble();
      final below = blockedBottom.clamp(minimumTop, maximumTop).toDouble();
      final aboveClears = above + groupHeight <= blockedTop;
      final belowClears = below >= blockedBottom;

      if (aboveClears && belowClears) {
        start = (centred - above).abs() <= (below - centred).abs()
            ? above
            : below;
      } else if (aboveClears) {
        start = above;
      } else if (belowClears) {
        start = below;
      }
      // Neither side clears: the cutout spans the whole rail. Stay centred —
      // a partly obscured rail beats one shoved off-screen.
    }
  }

  return _offsetsFrom(start, count, destinationHeight, spacing);
}

List<double> _offsetsFrom(
  double start,
  int count,
  double destinationHeight,
  double spacing,
) =>
    <double>[
      for (var index = 0; index < count; index++)
        start + index * (destinationHeight + spacing),
    ];
