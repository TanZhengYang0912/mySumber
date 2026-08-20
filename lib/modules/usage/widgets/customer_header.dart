import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/tokens.dart';
import '../../auth/state/auth_state.dart';
import '../screens/notifications_screen.dart';
import 'logout_confirmation_dialog.dart';

/// Shared rounded header used by the customer Home, Usage, and Profile
/// tabs so the three pages present one consistent top bar (avatar, title,
/// notification bell, logout) instead of drifting independently.
class CustomerHeader extends StatelessWidget {
  const CustomerHeader({
    super.key,
    required this.subtitle,
    required this.title,
    required this.notificationCount,
  });

  final String subtitle;
  final String title;
  final int notificationCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.adminPrimary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_outline,
                  color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(subtitle,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 14)),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            _notificationBell(context, notificationCount),
            IconButton(
              icon:
                  const Icon(Icons.logout, color: Colors.white70, size: 20),
              onPressed: () => showLogoutConfirmation(
                context,
                onConfirm: () => context.read<RoleState>().logout(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _notificationBell(BuildContext context, int count) {
    final size = _notificationButtonSize(context);
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.notifications_outlined,
                color: Colors.white, size: size * 0.5),
          ),
          if (count > 0)
            Positioned(
              top: -size * 0.05,
              right: -size * 0.05,
              child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: size * 0.125, vertical: size * 0.025),
                decoration: BoxDecoration(
                  color: AppColors.critical,
                  borderRadius: BorderRadius.circular(999),
                  border:
                      Border.all(color: AppColors.adminPrimary, width: 1.5),
                ),
                child: Text(
                  count > 9 ? '9+' : '$count',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: size * 0.225,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Notification bell scales with screen width, clamped to a sane range
  /// so it stays legible on small phones and doesn't balloon on tablets.
  double _notificationButtonSize(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return (width * 0.1).clamp(32.0, 48.0);
  }
}
