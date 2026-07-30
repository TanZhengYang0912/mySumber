import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/tokens.dart';
import '../../auth/state/auth_state.dart';
import '../services/validators.dart';
import '../state/usage_state.dart';
import '../widgets/address_search_field.dart';

const _totalSteps = 4;

/// Enforced step-by-step profile setup shown right after registration.
/// The user cannot dismiss or back out of this — it's pushed on top of the
/// (already logged-in) app and only pops once every step is completed.
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  int _step = 0;
  bool _saving = false;
  String? _error;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressKey = GlobalKey<AddressSearchFieldState>();
  String? _gender;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String get _stepTitle {
    switch (_step) {
      case 0:
        return "What's your full name?";
      case 1:
        return "What's your gender?";
      case 2:
        return "What's your phone number?";
      default:
        return "Where's your service address?";
    }
  }

  bool _validateCurrentStep() {
    setState(() => _error = null);
    switch (_step) {
      case 0:
        if (_nameController.text.trim().isEmpty) {
          setState(() => _error = 'Enter your full name');
          return false;
        }
        return true;
      case 1:
        if (_gender == null) {
          setState(() => _error = 'Select a gender');
          return false;
        }
        return true;
      case 2:
        if (!isValidMalaysianPhone(_phoneController.text)) {
          setState(() => _error = 'Enter a valid Malaysian mobile number');
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  Future<void> _next() async {
    if (!_validateCurrentStep()) return;
    if (_step < _totalSteps - 1) {
      setState(() => _step++);
      return;
    }
    await _finish();
  }

  Future<void> _finish() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final resolved = await _addressKey.currentState!.validate(
      onError: (msg) => _error = msg,
    );
    if (resolved == null) {
      setState(() => _saving = false);
      return;
    }
    if (!mounted) return;
    final role = context.read<RoleState>();
    final ok = await role.completeProfileSetup(
          displayName: _nameController.text.trim(),
          gender: _gender!,
          phoneNumber: _phoneController.text.trim(),
          serviceAddress: resolved.address,
          serviceState: resolved.state,
        );
    if (!mounted) return;
    if (ok) {
      // Don't navigate manually — completeProfileSetup's notifyListeners()
      // makes the app root itself swap from this wizard to AppShell now
      // that needsProfileSetup is false. Also, this screen is always the
      // app root (never pushed), so PopScope(canPop: false) above would
      // block an explicit pop here anyway.
      context.read<UsageState>().selectState(resolved.state);
    } else {
      setState(() {
        _saving = false;
        _error = role.errorMessage ??
            'Could not save your profile. Please try again.';
      });
    }
  }

  void _back() {
    if (_step == 0) return;
    setState(() {
      _step--;
      _error = null;
    });
  }

  /// Escape hatch for when the wizard itself is broken (e.g. the address
  /// lookup is down) so a real bug here can never permanently lock someone
  /// out of the app. You can finish setup later from the Profile tab.
  Future<void> _confirmSkip() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Skip for now?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'You can finish setting up your name, gender, phone number, and '
              'address later from the Profile tab.',
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(false),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.customerPrimary,
                minimumSize: const Size.fromHeight(52),
              ),
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: const Text('Skip'),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true && mounted) {
      context.read<RoleState>().skipProfileSetupForNow();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_step > 0) {
          _back();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Please complete your profile to continue'),
          ));
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Step ${_step + 1} of $_totalSteps',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        )),
                    Row(
                      children: [
                        Text('${(((_step + 1) / _totalSteps) * 100).round()}%',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.customerPrimary,
                            )),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: _confirmSkip,
                          child: const Text(
                            'Skip for now',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: (_step + 1) / _totalSteps,
                    minHeight: 8,
                    backgroundColor: AppColors.divider,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.customerPrimary),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  _stepTitle,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'We use this to personalize your account and utility comparisons.',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: SingleChildScrollView(child: _stepBody()),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.criticalSurface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: AppColors.critical, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_error!,
                                style: const TextStyle(
                                    color: AppColors.critical, fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                  ),
                Row(
                  children: [
                    if (_step > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _saving ? null : _back,
                          child: const Text('Back'),
                        ),
                      ),
                    if (_step > 0) const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                            backgroundColor: AppColors.customerPrimary),
                        onPressed: _saving ? null : _next,
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : Text(_step == _totalSteps - 1
                                ? 'Finish'
                                : 'Next'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepBody() {
    switch (_step) {
      case 0:
        return TextField(
          controller: _nameController,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Full name',
            hintText: 'e.g. Ahmad bin Ali',
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.customerPrimary),
            ),
          ),
        );
      case 1:
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: genderOptions.map((g) {
            final selected = _gender == g;
            return ChoiceChip(
              label: Text(g),
              selected: selected,
              onSelected: (_) => setState(() => _gender = g),
              selectedColor: AppColors.customerPrimary,
              labelStyle: TextStyle(
                color: selected ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              backgroundColor: Colors.white,
              side: BorderSide(
                  color: selected
                      ? AppColors.customerPrimary
                      : AppColors.divider),
            );
          }).toList(),
        );
      case 2:
        return TextField(
          controller: _phoneController,
          autofocus: true,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: 'Phone number',
            hintText: '012-345 6789',
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.customerPrimary),
            ),
          ),
        );
      default:
        return AddressSearchField(key: _addressKey);
    }
  }
}
