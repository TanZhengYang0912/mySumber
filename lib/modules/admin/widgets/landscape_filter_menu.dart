import 'package:flutter/material.dart';

import '../../../theme/tokens.dart';

class LandscapeFilterMenu extends StatelessWidget {
  const LandscapeFilterMenu({
    super.key,
    required this.child,
    this.label = 'Filter',
    this.tooltip = 'Filter anomalies',
    this.activeCount = 0,
    this.footer,
  });

  final Widget child;
  final String label;
  final String tooltip;
  final int activeCount;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      style: const MenuStyle(
        alignment: AlignmentDirectional.centerEnd,
        elevation: WidgetStatePropertyAll(4),
      ),
      alignmentOffset: const Offset(8, 0),
      menuChildren: [
        Builder(
          builder: (context) {
            final maxHeight =
                (MediaQuery.sizeOf(context).height * 0.58).clamp(220.0, 300.0);
            return SizedBox(
              width: 360,
              height: maxHeight,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      primary: false,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: child,
                    ),
                  ),
                  if (footer != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: footer,
                    ),
                ],
              ),
            );
          },
        ),
      ],
      builder: (context, controller, _) => Tooltip(
        message: tooltip,
        child: TextButton.icon(
          onPressed: controller.isOpen ? controller.close : controller.open,
          icon: const Icon(Icons.tune, size: 18),
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label),
              if (activeCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.adminPrimary,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$activeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.adminPrimary,
            backgroundColor: AppColors.adminSurface,
          ),
        ),
      ),
    );
  }
}
