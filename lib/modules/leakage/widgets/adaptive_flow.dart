import 'package:flutter/material.dart';

/// One layout for every orientation: cards reflow into two columns when there
/// is room and fall back to one when there isn't.
///
/// [builder] receives the usable content width and the paired-column width, so
/// a screen declares its cards once instead of maintaining a portrait tree and
/// a landscape tree that drift apart.
class AdaptiveFlow extends StatelessWidget {
  const AdaptiveFlow({
    super.key,
    required this.builder,
    this.spacing = 12,
    this.minColumnWidth = 300,
    this.padding = const EdgeInsets.all(14),
  });

  final List<Widget> Function(double full, double half) builder;
  final double spacing;
  final double minColumnWidth;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final full = constraints.maxWidth - padding.horizontal;
        final fitsTwo = full >= minColumnWidth * 2 + spacing;
        final half = fitsTwo ? (full - spacing) / 2 : full;

        return SingleChildScrollView(
          padding: padding,
          child: Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: builder(full, half),
          ),
        );
      },
    );
  }
}
