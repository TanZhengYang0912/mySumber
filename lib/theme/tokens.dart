import 'package:flutter/material.dart';

/// Design tokens extracted from the Figma reference at
/// https://react-omen-82271244.figma.site — kept in one place so the shared
/// widgets below and every screen reference the same values.
class AppColors {
  AppColors._();

  static const Color adminPrimary = Color(0xFF0F766E);
  static const Color adminPrimaryDark = Color(0xFF0B5C55);
  static const Color adminSurface = Color(0xFFECFDF5);

  static const Color workerPrimary = Color(0xFF1E40AF);
  static const Color workerPrimaryDark = Color(0xFF1B3894);
  static const Color workerSurface = Color(0xFFDBE7FF);

  static const Color customerPrimary = Color(0xFF6366F1);
  static const Color customerPrimaryDark = Color(0xFF4F46E5);
  static const Color customerSurface = Color(0xFFEEF2FF);

  static const Color waterAccent = Color(0xFF3B82F6);
  static const Color waterSurface = Color(0xFFE0EBFB);
  static const Color electricityAccent = Color(0xFF3B82F6);
  static const Color electricitySurface = Color(0xFFE0EBFB);

  static const Color success = Color(0xFF16A34A);
  static const Color successSurface = Color(0xFFDCFCE7);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningSurface = Color(0xFFFEF3C7);
  static const Color critical = Color(0xFFDC2626);
  static const Color criticalSurface = Color(0xFFFEE2E2);

  static const Color canvas = Color(0xFFF3F4F6);
  static const Color surface = Colors.white;
  static const Color divider = Color(0xFFE5E7EB);

  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
}

Color rolePrimary(String? role) {
  switch (role) {
    case 'admin':
      return AppColors.adminPrimary;
    case 'worker':
      return AppColors.workerPrimary;
    case 'user':
    case 'customer':
      return AppColors.customerPrimary;
    default:
      return AppColors.adminPrimary;
  }
}

Color roleSurface(String? role) {
  switch (role) {
    case 'admin':
      return AppColors.adminSurface;
    case 'worker':
      return AppColors.workerSurface;
    case 'user':
    case 'customer':
      return AppColors.customerSurface;
    default:
      return AppColors.adminSurface;
  }
}

/// Small UPPERCASE tracked label used as section headings across the design.
class SectionLabel extends StatelessWidget {
  final String text;
  final Color? color;
  const SectionLabel(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: color ?? AppColors.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}

/// Rounded coloured pill used for severity, outcome, count badges.
class Pill extends StatelessWidget {
  final String text;
  final Color color;
  final Color? background;
  final IconData? icon;

  /// Transparent fill with a [color] border instead of a tinted background.
  /// Severity and alert status use this so they read as tags rather than
  /// competing blocks of colour on the same card.
  final bool outlined;

  const Pill(this.text,
      {super.key,
      required this.color,
      this.background,
      this.icon,
      this.outlined = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: outlined
            ? Colors.transparent
            : (background ?? color.withValues(alpha: 0.12)),
        borderRadius: BorderRadius.circular(999),
        border: outlined ? Border.all(color: color) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// The tall rounded coloured banner every role screen sits under.
class RoleHeader extends StatelessWidget {
  final String role;
  final String subtitle;
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showLogout;

  const RoleHeader({
    super.key,
    required this.role,
    required this.subtitle,
    required this.title,
    this.actions,
    this.leading,
    this.showLogout = true,
  });

  @override
  Widget build(BuildContext context) {
    final primary = rolePrimary(role);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: primary,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 12)],
                Expanded(
                  child: Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (actions != null) ...actions!,
              ],
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// White rounded card. Matches the container style used for every content
/// block in the Figma design.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? background;
  final BorderSide? border;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.background,
    this.border,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: background ?? AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: border != null ? Border.fromBorderSide(border!) : null,
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

/// Big-number stat cell used in "System Overview" and similar rows.
class StatCell extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final Color? background;
  final bool compact;

  const StatCell({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    this.background,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: compact ? 76 : null,
      padding: EdgeInsets.symmetric(
        vertical: compact ? 6 : 14,
        horizontal: 8,
      ),
      decoration: BoxDecoration(
        color: background ?? const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: compact ? 16 : 20),
          SizedBox(height: compact ? 4 : 8),
          Text(
            value,
            style: TextStyle(
              fontSize: compact ? 22 : 26,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              height: 1.0,
            ),
          ),
          SizedBox(height: compact ? 2 : 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Sits over an outlined AppBar-shaped area on the header, e.g. the "Import"
/// pill on the Admin Equipment header or the "Logout" text button.
Widget headerActionButton({
  required IconData icon,
  required String label,
  required VoidCallback onTap,
}) {
  return Material(
    color: Colors.white.withValues(alpha: 0.16),
    borderRadius: BorderRadius.circular(999),
    child: InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ],
        ),
      ),
    ),
  );
}
