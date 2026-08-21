import 'package:flutter/material.dart';

/// Wraps [child] so it collapses away once [controller] scrolls away from
/// the start (in either axis), and reappears once the user scrolls back
/// toward the start. Used to let the green customer header hide while
/// browsing the horizontally-scrolling phone-landscape layouts.
class HideOnScroll extends StatefulWidget {
  const HideOnScroll({
    super.key,
    required this.controller,
    required this.child,
  });

  final ScrollController controller;
  final Widget child;

  @override
  State<HideOnScroll> createState() => _HideOnScrollState();
}

class _HideOnScrollState extends State<HideOnScroll> {
  bool _visible = true;
  double _lastOffset = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (!widget.controller.hasClients) return;
    final offset = widget.controller.offset;
    final delta = offset - _lastOffset;
    _lastOffset = offset;
    if (delta.abs() < 2) return;
    final shouldShow = offset <= 0 || delta < 0;
    if (shouldShow != _visible) setState(() => _visible = shouldShow);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        heightFactor: _visible ? 1 : 0,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 160),
          opacity: _visible ? 1 : 0,
          child: widget.child,
        ),
      ),
    );
  }
}
