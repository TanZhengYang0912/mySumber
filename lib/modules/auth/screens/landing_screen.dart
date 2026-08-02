import 'package:flutter/material.dart';

import '../../../theme/tokens.dart';
import 'login_screen.dart';

/// Initial role picker matching the Figma landing screen at
/// https://react-omen-82271244.figma.site — three coloured role buttons on top
/// of the mySumber brand mark. Clicking a role forwards to the auth flow with
/// the intended role pre-set so the LoginScreen can theme itself.
class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  void _pick(BuildContext context, String role) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LoginScreen(intendedRole: role)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    if (viewport.shortestSide < 600 && viewport.width > viewport.height) {
      return _phoneLandscapeLanding(context);
    }

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 4),
              Center(
                child: Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    color: AppColors.adminPrimary,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(
                    Icons.water_drop_rounded,
                    color: Colors.white,
                    size: 44,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'mySumber',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Utility Management Platform',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 32),
              _RoleButton(
                label: 'Continue as Admin',
                icon: Icons.shield_outlined,
                color: AppColors.adminPrimary,
                onTap: () => _pick(context, 'admin'),
              ),
              const SizedBox(height: 12),
              _RoleButton(
                label: 'Continue as Worker',
                icon: Icons.build_outlined,
                color: AppColors.workerPrimary,
                onTap: () => _pick(context, 'worker'),
              ),
              const SizedBox(height: 12),
              _RoleButton(
                label: 'Continue as Customer',
                icon: Icons.person_outline,
                color: AppColors.customerPrimary,
                onTap: () => _pick(context, 'user'),
              ),
              const SizedBox(height: 20),
              const Text(
                'Select your role to preview the interface',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(flex: 5),
            ],
          ),
        ),
      ),
    );
  }

  Widget _phoneLandscapeLanding(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 16, 28, 16),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.adminPrimary,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.water_drop_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'mySumber',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Utility Management Platform',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 34),
              Expanded(
                flex: 6,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 48,
                      child: _RoleButton(
                        compact: true,
                        label: 'Continue as Admin',
                        icon: Icons.shield_outlined,
                        color: AppColors.adminPrimary,
                        onTap: () => _pick(context, 'admin'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 48,
                      child: _RoleButton(
                        compact: true,
                        label: 'Continue as Worker',
                        icon: Icons.build_outlined,
                        color: AppColors.workerPrimary,
                        onTap: () => _pick(context, 'worker'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 48,
                      child: _RoleButton(
                        compact: true,
                        label: 'Continue as Customer',
                        icon: Icons.person_outline,
                        color: AppColors.customerPrimary,
                        onTap: () => _pick(context, 'user'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Select your role to preview the interface',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleButton extends StatelessWidget {
  final bool compact;
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _RoleButton({
    this.compact = false,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(14),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: compact ? 10 : 18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: compact ? 18 : 20),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 14 : 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
