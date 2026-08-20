import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/tokens.dart';
import '../../auth/state/auth_state.dart';

/// Nested settings page reached from Profile → App Settings. Mirrors the
/// same password-change behaviour as [ResetPasswordScreen] (min 8 chars,
/// must match confirm field, saved via [RoleState.updateRecoveredPassword])
/// but for a user who is already signed in rather than arriving via an
/// invite/recovery link.
class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen>
    with SingleTickerProviderStateMixin {
  late final bool _canResetPassword;
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _canResetPassword = !context.read<RoleState>().isGoogleOnlyAccount;
    _tab = TabController(length: _canResetPassword ? 2 : 1, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('App Settings'),
        backgroundColor: AppColors.adminPrimary,
        foregroundColor: Colors.white,
        bottom: _canResetPassword
            ? TabBar(
                controller: _tab,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: const [
                  Tab(text: 'General'),
                  Tab(text: 'Reset Password'),
                ],
              )
            : null,
      ),
      body: TabBarView(
        controller: _tab,
        physics: _canResetPassword ? null : const NeverScrollableScrollPhysics(),
        children: [
          const _GeneralTab(),
          if (_canResetPassword) const _ResetPasswordTab(),
        ],
      ),
    );
  }
}

class _GeneralTab extends StatelessWidget {
  const _GeneralTab();

  @override
  Widget build(BuildContext context) {
    final role = context.watch<RoleState>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel('SIGNED IN AS'),
              const SizedBox(height: 6),
              Text(
                role.email ?? '',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                (role.userRole ?? '').toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (role.isGoogleOnlyAccount)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: AppCard(
              child: Row(
                children: const [
                  Icon(Icons.info_outline,
                      size: 18, color: AppColors.textSecondary),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'You signed in with Google, so there is no mySumber password to reset.',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ResetPasswordTab extends StatefulWidget {
  const _ResetPasswordTab();

  @override
  State<_ResetPasswordTab> createState() => _ResetPasswordTabState();
}

class _ResetPasswordTabState extends State<_ResetPasswordTab> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  String? _validationError;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final password = _password.text;
    if (password.length < 8) {
      setState(
          () => _validationError = 'Password must be at least 8 characters');
      return;
    }
    if (password != _confirm.text) {
      setState(() => _validationError = 'Passwords do not match');
      return;
    }
    setState(() => _validationError = null);
    final ok = await context.read<RoleState>().updateRecoveredPassword(password);
    if (!mounted) return;
    if (ok) {
      _password.clear();
      _confirm.clear();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Password updated'),
        backgroundColor: AppColors.success,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<RoleState>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel('CHANGE PASSWORD'),
              const SizedBox(height: 4),
              const Text(
                'Choose a new password for your mySumber account.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _password,
                obscureText: !_showPassword,
                decoration: InputDecoration(
                  labelText: 'New password',
                  suffixIcon: IconButton(
                    icon: Icon(_showPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    onPressed: () =>
                        setState(() => _showPassword = !_showPassword),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _confirm,
                obscureText: !_showConfirmPassword,
                decoration: InputDecoration(
                  labelText: 'Confirm password',
                  suffixIcon: IconButton(
                    icon: Icon(_showConfirmPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    onPressed: () => setState(
                        () => _showConfirmPassword = !_showConfirmPassword),
                  ),
                ),
              ),
              if (_validationError != null || auth.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _validationError ?? auth.errorMessage!,
                    style: const TextStyle(color: AppColors.critical),
                  ),
                ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: auth.isLoading ? null : _save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: AppColors.adminPrimary,
                  foregroundColor: Colors.white,
                ),
                child: Text(auth.isLoading ? 'Saving…' : 'Save password'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
