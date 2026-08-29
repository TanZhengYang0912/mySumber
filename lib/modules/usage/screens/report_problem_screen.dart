import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../theme/tokens.dart';
import '../../../theme/logout_confirmation_dialog.dart';
import '../../auth/state/auth_state.dart';
import '../../leakage/models/alert.dart';
import '../../leakage/screens/network_error.dart';
import '../../leakage/services/simulation_service.dart';
import '../../leakage/state/app_state.dart';
import '../state/usage_state.dart';
import 'account_settings_screen.dart';
import '../widgets/address_search_field.dart';
import '../widgets/customer_header.dart';
import '../widgets/customer_landscape_scaffold.dart';
import '../widgets/edit_address_dialog.dart';
import '../widgets/edit_profile_dialog.dart';
import '../services/customer_compact_layout.dart';

const _defaultServiceAddress = 'No. 12, Jln Merdeka, Selangor';
const _defaultServiceState = 'Selangor';

class ReportProblemScreen extends StatefulWidget {
  const ReportProblemScreen({super.key});

  @override
  State<ReportProblemScreen> createState() => _ReportProblemScreenState();
}

class _ReportProblemScreenState extends State<ReportProblemScreen> {
  late String _serviceAddress;
  late String _serviceState;

  @override
  void initState() {
    super.initState();
    final metadata = Supabase.instance.client.auth.currentUser?.userMetadata;
    _serviceAddress =
        (metadata?['service_address'] as String?) ?? _defaultServiceAddress;
    _serviceState =
        (metadata?['service_state'] as String?) ?? _defaultServiceState;
  }

  Future<void> _editAddress() async {
    final result = await showEditServiceAddressDialog(
      context,
      initialAddress: _serviceAddress,
    );
    if (result != null && mounted) {
      setState(() {
        _serviceAddress = result.address;
        _serviceState = result.state;
      });
      context.read<UsageState>().selectState(result.state);
    }
  }

  Future<void> _editProfile(RoleState role) async {
    await showEditProfileDialog(
      context,
      initialName: role.displayName,
      initialPhone: role.phoneNumber,
      initialGender: role.gender,
    );
  }

  void _requestLogout(BuildContext context) {
    showLogoutConfirmation(
      context,
      onConfirm: () => context.read<RoleState>().logout(),
    );
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: AppColors.critical, size: 20),
            SizedBox(width: 8),
            Text('Delete Account'),
          ],
        ),
        content: const Text(
          'This permanently deletes your account and all your logged usage '
          'data. This cannot be undone.',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.critical),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final ok = await context.read<RoleState>().deleteAccount();
    if (!context.mounted) return;
    if (!ok) {
      final error = context.read<RoleState>().errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error ?? 'Could not delete account'),
        backgroundColor: AppColors.critical,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = context.watch<RoleState>();
    final notificationCount = context.watch<UsageState>().notifications.length;
    final email = role.email ?? '';
    final displayName = role.displayName;
    final initials = displayName
        .split(' ')
        .where((s) => s.isNotEmpty)
        .take(2)
        .map((s) => s[0].toUpperCase())
        .join();

    if (usesCustomerPhoneLandscape(MediaQuery.sizeOf(context))) {
      return _phoneLandscapeProfile(
        context,
        role,
        displayName,
        email,
        initials,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          CustomerHeader(
            subtitle: 'mySumber · PROFILE',
            title: 'My Account',
            notificationCount: notificationCount,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
            child: _profileCard(
                displayName, email, initials, role.phoneNumber, role),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            child: _detailsCard(_serviceAddress, _serviceState),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            child: _menuCard(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: FilledButton.icon(
              onPressed: () => _requestLogout(context),
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Sign Out'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: const Color(0xFFFEF2F2),
                foregroundColor: AppColors.critical,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                textStyle:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            child: TextButton.icon(
              onPressed: () => _confirmDeleteAccount(context),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Delete Account'),
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                foregroundColor: AppColors.critical,
                textStyle:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _phoneLandscapeProfile(
    BuildContext context,
    RoleState role,
    String displayName,
    String email,
    String initials,
  ) {
    final notificationCount = context.watch<UsageState>().notifications.length;
    return CustomerLandscapeScaffold(
      header: CustomerHeader(
        subtitle: 'mySumber · PROFILE',
        title: 'My Account',
        notificationCount: notificationCount,
      ),
      children: [
        _profileCard(displayName, email, initials, role.phoneNumber, role),
        _detailsCard(_serviceAddress, _serviceState),
        _menuCard(),
        FilledButton.icon(
          onPressed: () => _requestLogout(context),
          icon: const Icon(Icons.logout, size: 18),
          label: const Text('Sign Out'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            backgroundColor: const Color(0xFFFEF2F2),
            foregroundColor: AppColors.critical,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            textStyle:
                const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
        ),
        TextButton.icon(
          onPressed: () => _confirmDeleteAccount(context),
          icon: const Icon(Icons.delete_outline, size: 18),
          label: const Text('Delete Account'),
          style: TextButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            foregroundColor: AppColors.critical,
            textStyle:
                const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _profileCard(String name, String email, String initials, String? phone,
      RoleState role) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            onTap: () => _editProfile(role),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.adminPrimary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        initials.isEmpty ? '·' : initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          email.isEmpty ? '—' : email,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.edit_outlined,
                      size: 16, color: AppColors.textTertiary),
                ],
              ),
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _detailRow(
            icon: Icons.call_outlined,
            label: 'Phone Number',
            value: phone == null || phone.isEmpty ? 'Add phone number' : phone,
            onTap: () => _editProfile(role),
            trailing: const Icon(Icons.edit_outlined,
                size: 16, color: AppColors.textTertiary),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _detailRow(
            icon: Icons.wc_outlined,
            label: 'Gender',
            value: role.gender ?? 'Not set',
            onTap: () => _editProfile(role),
            trailing: const Icon(Icons.edit_outlined,
                size: 16, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _detailsCard(String serviceAddress, String serviceState) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _detailRow(
            icon: Icons.location_on_outlined,
            label: 'Service Address',
            value: serviceAddress,
            onTap: _editAddress,
            trailing: const Icon(Icons.edit_outlined,
                size: 16, color: AppColors.textTertiary),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _detailRow(
            icon: Icons.map_outlined,
            label: 'State',
            value: serviceState,
          ),
        ],
      ),
    );
  }

  Widget _detailRow({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    final row = Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing,
          ],
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }

  Widget _menuCard() {
    final usage = context.watch<UsageState>();
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
            child: Row(
              children: [
                const Icon(Icons.notifications_outlined,
                    size: 20, color: AppColors.textSecondary),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Push Notifications',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                ),
                Transform.scale(
                  scale: 0.9,
                  child: Switch(
                    value: usage.pushNotificationsEnabled,
                    activeThumbColor: Colors.white,
                    activeTrackColor: AppColors.adminPrimary,
                    onChanged: (v) => context
                        .read<UsageState>()
                        .setPushNotificationsEnabled(v),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _menuItem(
            icon: Icons.settings_outlined,
            label: 'App Settings',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const AccountSettingsScreen())),
            trailing:
                const Icon(Icons.chevron_right, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _menuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
            ),
            trailing ??
                const Icon(Icons.chevron_right, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

enum _ElecScenario {
  highUsage('High electricity usage', false),
  meterTampering('Suspected meter tampering', true),
  frequentTrips('Frequent power trips', false),
  other('Other', false);

  final String label;
  final bool isTampering;
  const _ElecScenario(this.label, this.isTampering);
}

/// Dedicated flow for reporting a problem — moved off the profile screen so
/// account details stay focused on identity.
class ReportFlowScreen extends StatefulWidget {
  const ReportFlowScreen({super.key});

  @override
  State<ReportFlowScreen> createState() => _ReportFlowScreenState();
}

enum _LocationChoice { mine, other }

class _ReportFlowScreenState extends State<ReportFlowScreen> {
  bool _isWater = true;
  String? _pendingCategory;
  final _description = TextEditingController();
  DateTime _occurredAt = DateTime.now();
  bool _submitting = false;

  _LocationChoice _locationChoice = _LocationChoice.mine;
  final _otherAddressKey = GlobalKey<AddressSearchFieldState>();
  String? _otherLocationError;
  late String _profileAddress;
  late String _profileState;

  @override
  void initState() {
    super.initState();
    final metadata = Supabase.instance.client.auth.currentUser?.userMetadata;
    _profileAddress =
        (metadata?['service_address'] as String?) ?? _defaultServiceAddress;
    _profileState =
        (metadata?['service_state'] as String?) ?? _defaultServiceState;
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  List<String> get _categoryOptions => _isWater
      ? [...LeakScenario.values.map((s) => s.label), 'Other']
      : _ElecScenario.values.map((s) => s.label).toList();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    final perCapita = _locationChoice == _LocationChoice.mine
        ? app.baseline.perCapitaLPerDay(_profileState)
        : null;
    final accent =
        _isWater ? AppColors.waterAccent : AppColors.electricityAccent;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Report a Problem'),
        backgroundColor: AppColors.adminPrimary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          // Utility toggle
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 6,
                    offset: Offset(0, 2))
              ],
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                Expanded(
                    child: _utilityTab(
                        'Water',
                        Icons.water_drop_outlined,
                        AppColors.waterAccent,
                        _isWater,
                        () => setState(() {
                              _isWater = true;
                              _pendingCategory = null;
                            }))),
                Expanded(
                    child: _utilityTab(
                        'Electricity',
                        Icons.electric_bolt_outlined,
                        AppColors.electricityAccent,
                        !_isWater,
                        () => setState(() {
                              _isWater = false;
                              _pendingCategory = null;
                            }))),
              ],
            ),
          ),
          const SizedBox(height: 10),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('LOCATION OF INCIDENT'),
                const SizedBox(height: 12),
                DropdownButtonFormField<_LocationChoice>(
                  initialValue: _locationChoice,
                  isDense: true,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Location',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: _LocationChoice.mine,
                      child: Text(
                        _profileAddress,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const DropdownMenuItem(
                      value: _LocationChoice.other,
                      child: Text('Other'),
                    ),
                  ],
                  onChanged: (choice) => setState(() {
                    _locationChoice = choice ?? _LocationChoice.mine;
                    _otherLocationError = null;
                  }),
                ),
                if (_locationChoice == _LocationChoice.other) ...[
                  const SizedBox(height: 12),
                  AddressSearchField(
                    key: _otherAddressKey,
                    errorText: _otherLocationError,
                  ),
                ],
                if (_isWater && perCapita != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Average domestic use: ${perCapita.toStringAsFixed(0)} L/person/day (${app.baseline.latestYear})',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('REPORT DETAILS'),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _categoryOptions
                      .map((label) => _categoryChip(label, accent))
                      .toList(),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _description,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Describe the incident (e.g. Leak from roof...) ',
                    hintStyle: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Date of Incident',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 40),
                      ),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _occurredAt,
                          firstDate: DateTime.now()
                              .subtract(const Duration(days: 30)),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null && mounted) {
                          setState(() => _occurredAt = picked);
                        }
                      },
                      icon: const Icon(Icons.calendar_today_outlined, size: 16),
                      label: Text(
                          '${_occurredAt.day}/${_occurredAt.month}/${_occurredAt.year}'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _submitting ? null : () => _submit(app),
            style:
                FilledButton.styleFrom(backgroundColor: AppColors.adminPrimary),
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_outlined),
            label: const Text('Submit Report'),
          ),
          const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _utilityTab(String label, IconData icon, Color accent, bool selected,
      VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 16, color: selected ? accent : AppColors.textTertiary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? accent : AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryChip(String label, Color accent) {
    final selected = _pendingCategory == label;
    return GestureDetector(
      onTap: () => setState(() => _pendingCategory = label),
      child: _chip(label, selected, accent),
    );
  }

  Widget _chip(String label, bool selected, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? accent : accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: selected ? accent : accent.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: selected ? Colors.white : accent,
        ),
      ),
    );
  }

  Future<void> _submit(AppState app) async {
    final category = _pendingCategory;
    if (category == null || _description.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Choose a category and describe what happened.')));
      return;
    }

    setState(() => _submitting = true);

    String address;
    String state;
    if (_locationChoice == _LocationChoice.other) {
      final resolved = await _otherAddressKey.currentState?.validate(
        onError: (msg) => _otherLocationError = msg,
      );
      if (resolved == null) {
        if (mounted) {
          setState(() => _submitting = false);
        }
        return;
      }
      address = resolved.address;
      state = resolved.state;
    } else {
      address = _profileAddress;
      state = _profileState;
    }

    try {
      await app.submitHouseholdProblem(
        utility: _isWater ? Utility.water : Utility.electricity,
        state: state,
        address: address,
        category: category,
        description: _description.text.trim(),
        occurredAt: _occurredAt,
      );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _description.clear();
        _pendingCategory = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text(
            'Submitted for Admin review. You will see updates after it is reviewed.'),
        backgroundColor: AppColors.adminPrimary,
      ));
    } catch (_) {
      if (mounted) {
        setState(() => _submitting = false);
        showNetworkErrorSnackBar(context);
      }
    }
  }
}
