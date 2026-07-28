import 'package:flutter/material.dart';

import '../../../theme/tokens.dart';

class LandscapeFilterMenu extends StatelessWidget {
  const LandscapeFilterMenu({
    super.key,
    required this.child,
  });

  final Widget child;

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
                (MediaQuery.sizeOf(context).height - 32).clamp(200.0, 360.0);
            return SizedBox(
              width: 360,
              height: maxHeight,
              child: SingleChildScrollView(
                primary: false,
                padding: const EdgeInsets.all(16),
                child: child,
              ),
            );
          },
        ),
      ],
      builder: (context, controller, _) => Tooltip(
        message: 'Filter anomalies',
        child: TextButton.icon(
          onPressed: controller.isOpen ? controller.close : controller.open,
          icon: const Icon(Icons.tune, size: 18),
          label: const Text('Filter'),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.adminPrimary,
            backgroundColor: AppColors.adminSurface,
          ),
        ),
      ),
    );
  }
}
