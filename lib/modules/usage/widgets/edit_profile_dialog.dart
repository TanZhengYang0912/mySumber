import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/tokens.dart';
import '../../auth/state/auth_state.dart';
import '../services/customer_compact_layout.dart';
import '../services/validators.dart';

/// Opens a dialog to edit the account's display name and phone number,
/// persisting both to Supabase auth user metadata via [RoleState].
/// Returns true if saved, false/null if cancelled.
Future<bool?> showEditProfileDialog(
  BuildContext context, {
  required String initialName,
  required String? initialPhone,
  required String? initialGender,
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => _EditProfileDialog(
      initialName: initialName,
      initialPhone: initialPhone,
      initialGender: initialGender,
    ),
  );
}

class _EditProfileDialog extends StatefulWidget {
  final String initialName;
  final String? initialPhone;
  final String? initialGender;
  const _EditProfileDialog({
    required this.initialName,
    this.initialPhone,
    this.initialGender,
  });

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  String? _gender;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _phoneController =
        TextEditingController(text: widget.initialPhone ?? '');
    _gender = widget.initialGender;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_gender == null) {
      setState(() => _error = 'Select a gender');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final ok = await context.read<RoleState>().updateProfile(
          displayName: _nameController.text.trim(),
          phoneNumber: _phoneController.text.trim(),
          gender: _gender,
        );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _saving = false;
        _error = 'Could not save changes. Please try again.';
      });
    }
  }

  InputDecoration _decoration(
    String label, {
    required bool compact,
    String? hintText,
  }) {
    return InputDecoration(
      labelText: compact ? null : label,
      hintText: compact ? hintText : null,
      isDense: compact,
      contentPadding:
          compact ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10) : null,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.adminPrimary),
      ),
    );
  }

  Widget _compactField(String label, Widget field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        field,
      ],
    );
  }

  Widget _nameField({required bool compact}) {
    return TextFormField(
      controller: _nameController,
      autofocus: true,
      decoration: _decoration(
        'Name',
        compact: compact,
        hintText: 'Your name',
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Enter your name';
        return null;
      },
    );
  }

  Widget _genderField({required bool compact}) {
    return DropdownButtonFormField<String>(
      initialValue: _gender,
      decoration: _decoration(
        'Gender',
        compact: compact,
        hintText: 'Select',
      ),
      items: genderOptions
          .map((g) => DropdownMenuItem(value: g, child: Text(g)))
          .toList(),
      onChanged: (v) => setState(() => _gender = v),
    );
  }

  Widget _phoneField({required bool compact}) {
    return TextFormField(
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      decoration: _decoration(
        'Phone number',
        compact: compact,
        hintText: '012-345 6789',
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) {
          return 'Enter your phone number';
        }
        if (!isValidMalaysianPhone(v)) {
          return 'Enter a valid Malaysian mobile number';
        }
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPhoneLandscape =
        usesCustomerPhoneLandscape(MediaQuery.sizeOf(context));

    return AlertDialog(
      insetPadding: isPhoneLandscape
          ? const EdgeInsets.symmetric(horizontal: 24, vertical: 12)
          : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: isPhoneLandscape
          ? const EdgeInsets.fromLTRB(20, 14, 20, 0)
          : null,
      contentPadding: isPhoneLandscape
          ? const EdgeInsets.fromLTRB(20, 8, 20, 4)
          : null,
      actionsPadding: isPhoneLandscape
          ? const EdgeInsets.fromLTRB(12, 0, 12, 10)
          : null,
      title: const Row(
        children: [
          Icon(Icons.person_outline, color: AppColors.adminPrimary, size: 20),
          SizedBox(width: 8),
          Text('Edit Profile'),
        ],
      ),
      content: SizedBox(
        width: isPhoneLandscape ? 360 : null,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isPhoneLandscape) ...[
                _compactField('Name', _nameField(compact: true)),
                const SizedBox(height: 8),
                _compactField('Gender', _genderField(compact: true)),
              ]
              else ...[
                _nameField(compact: false),
                const SizedBox(height: 14),
                _genderField(compact: false),
              ],
              SizedBox(height: isPhoneLandscape ? 8 : 14),
              if (isPhoneLandscape)
                _compactField('Phone number', _phoneField(compact: true))
              else
                _phoneField(compact: false),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!,
                    style: const TextStyle(
                        color: AppColors.critical, fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (isPhoneLandscape)
          Row(
            children: [
              TextButton(
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const Spacer(),
              SizedBox(
                width: 112,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.adminPrimary,
                    minimumSize: const Size(0, 40),
                  ),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save'),
                ),
              ),
            ],
          )
        else ...[
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.adminPrimary,
            ),
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Save'),
          ),
        ],
      ],
    );
  }
}
