import 'package:flutter/material.dart';

import '../../../theme/tokens.dart';

/// A compact, side-anchored filter menu for Worker phone-landscape screens.
class WorkerLandscapeFilterMenu extends StatelessWidget {
  const WorkerLandscapeFilterMenu({
    super.key,
    required this.child,
    this.activeCount = 0,
  });

  final Widget child;
  final int activeCount;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      style: const MenuStyle(
        alignment: AlignmentDirectional.bottomEnd,
        elevation: WidgetStatePropertyAll(5),
      ),
      alignmentOffset: const Offset(0, 6),
      menuChildren: [
        Builder(
          builder: (context) {
            final maxHeight =
                (MediaQuery.sizeOf(context).height * 0.66).clamp(250.0, 320.0);
            return SizedBox(
              width: 340,
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
        message: 'Filter alerts',
        child: TextButton.icon(
          onPressed: controller.isOpen ? controller.close : controller.open,
          icon: const Icon(Icons.tune, size: 18),
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Filter'),
              if (activeCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.workerPrimary,
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
            foregroundColor: AppColors.workerPrimary,
            backgroundColor: AppColors.workerSurface,
          ),
        ),
      ),
    );
  }
}
