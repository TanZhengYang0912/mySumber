import 'package:flutter/material.dart';

import '../modules/admin/services/admin_tablet_layout.dart';
import 'logout_confirmation_dialog.dart';
import 'tokens.dart';

const adminLandscapeHorizontalInset = 16.0;
const adminLandscapeHeaderRowHeight = 48.0;

/// Shared header used by both Admin and Worker page surfaces — a rounded
/// colored band with brand/logout on top and an icon+title row below.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    required this.onLogout,
    this.color = AppColors.adminPrimary,
    this.brand = 'mySumber · ADMIN',
    this.icon,
    this.titleAccessory,
    this.action,
    this.leading,
    this.compact = false,
  });

  final String title;
  final Color color;
  final String brand;
  final IconData? icon;
  final Widget? titleAccessory;
  final Widget? action;
  final Widget? leading;
  final VoidCallback onLogout;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final useCompact =
        compact || usesAdminCompactHeader(MediaQuery.sizeOf(context));
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        useCompact ? adminLandscapeHorizontalInset : 20,
        useCompact ? 12 : 14,
        useCompact ? adminLandscapeHorizontalInset : 20,
        useCompact ? 16 : 16,
      ),
      child: SafeArea(
        left: !useCompact,
        right: !useCompact,
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    brand,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _LogoutButton(
                  onPressed: () => showLogoutConfirmation(
                    context,
                    onConfirm: onLogout,
                  ),
                ),
              ],
            ),
            SizedBox(height: useCompact ? 8 : 12),
            SizedBox(
              height: useCompact ? adminLandscapeHeaderRowHeight : null,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(width: 4),
                  ],
                  if (icon != null) ...[
                    _HeaderIcon(icon: icon!, compact: useCompact),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: useCompact ? 22 : 26,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                  ),
                  if (titleAccessory != null) ...[
                    const SizedBox(width: 8),
                    titleAccessory!,
                  ],
                  if (action != null) ...[
                    const SizedBox(width: 12),
                    action!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminHeaderAction extends StatelessWidget {
  const AdminHeaderAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.secondary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    final shape = StadiumBorder(
      side: secondary
          ? BorderSide(color: Colors.white.withValues(alpha: 0.55))
          : BorderSide.none,
    );
    return Material(
      color:
          secondary ? Colors.transparent : Colors.white.withValues(alpha: 0.16),
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        customBorder: shape,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 42),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: Colors.white),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AdminHeaderIconButton extends StatelessWidget {
  const AdminHeaderIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 21),
        color: Colors.white,
        style: IconButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.16),
          minimumSize: const Size(42, 42),
          fixedSize: const Size(42, 42),
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({required this.icon, required this.compact});

  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 38.0 : 44.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(compact ? 12 : 14),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: Colors.white, size: compact ? 22 : 24),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.logout_outlined, size: 18),
      label: const Text('Logout'),
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
