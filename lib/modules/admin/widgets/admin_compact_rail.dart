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

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      color: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            _RailDestination(
              icon: Icons.grid_view_outlined,
              tooltip: 'Dashboard',
              selected: currentIndex == 0,
              onTap: () => onDestinationSelected(0),
            ),
            const SizedBox(height: 8),
            _RailDestination(
              icon: Icons.notifications_outlined,
              tooltip: 'Alerts',
              selected: currentIndex == 2,
              onTap: () => onDestinationSelected(2),
            ),
            const SizedBox(height: 8),
            _RailDestination(
              icon: Icons.analytics_outlined,
              tooltip: 'AI Review',
              selected: currentIndex == 4,
              onTap: () => onDestinationSelected(4),
            ),
            const Spacer(),
            MenuAnchor(
              style: const MenuStyle(
                alignment: AlignmentDirectional.centerEnd,
                elevation: WidgetStatePropertyAll(4),
              ),
              alignmentOffset: const Offset(8, 0),
              menuChildren: [
                MenuItemButton(
                  leadingIcon: const Icon(Icons.inventory_2_outlined),
                  onPressed: () => onDestinationSelected(1),
                  child: const Text('Inventory'),
                ),
                MenuItemButton(
                  leadingIcon: const Icon(Icons.shield_outlined),
                  onPressed: () => onDestinationSelected(3),
                  child: const Text('Oversight'),
                ),
                const Divider(height: 1),
                MenuItemButton(
                  leadingIcon: const Icon(Icons.logout_outlined),
                  onPressed: onLogout,
                  child: const Text('Logout'),
                ),
              ],
              builder: (context, controller, child) => _RailDestination(
                icon: Icons.more_horiz,
                tooltip: 'More',
                selected: currentIndex == 1 || currentIndex == 3,
                onTap: controller.isOpen ? controller.close : controller.open,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
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
            height: 44,
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
