import 'package:flutter/material.dart';

import '../../../theme/tokens.dart';
import 'hide_on_scroll.dart';

/// Shared phone-landscape shell for the customer Home, Usage, and Profile
/// tabs.
///
/// Renders the same [header] used in portrait (hiding it on scroll) above
/// a vertically-scrolling column of [children] — the same cards/sections
/// portrait stacks, in the same order, just scrolled the same way portrait
/// does. [floatingActionButton] mirrors the portrait FAB position (bottom
/// right).
class CustomerLandscapeScaffold extends StatefulWidget {
  const CustomerLandscapeScaffold({
    super.key,
    required this.header,
    required this.children,
    this.floatingActionButton,
    this.spacing = 10,
  });

  final Widget header;
  final List<Widget> children;
  final Widget? floatingActionButton;
  final double spacing;

  @override
  State<CustomerLandscapeScaffold> createState() =>
      _CustomerLandscapeScaffoldState();
}

class _CustomerLandscapeScaffoldState
    extends State<CustomerLandscapeScaffold> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      floatingActionButton: widget.floatingActionButton,
      body: SafeArea(
        child: Column(
          children: [
            HideOnScroll(controller: _controller, child: widget.header),
            Expanded(
              child: ListView.separated(
                controller: _controller,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                itemCount: widget.children.length,
                separatorBuilder: (_, __) => SizedBox(height: widget.spacing),
                itemBuilder: (_, i) => widget.children[i],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
