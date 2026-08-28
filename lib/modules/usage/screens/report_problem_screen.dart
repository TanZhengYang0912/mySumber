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
import '../widgets/customer_header.dart';
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
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          child: Column(
            key: const PageStorageKey('customer-phone-landscape-profile'),
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.customerSurface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.person_outline,
                      color: AppColors.customerPrimary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MY ACCOUNT',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Text(
                          'My Account',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _landscapeNotificationButton(),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 4,
                      child: ListView(
                        padding: EdgeInsets.zero,
                        children: [
                          _profileCard(
                            displayName,
                            email,
                            initials,
                            role.phoneNumber,
                            role,
                          ),
                          const SizedBox(height: 4),
                          _landscapeAddressCard(
                            _serviceAddress,
                            _serviceState,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 6,
                      child: ListView(
                        padding: EdgeInsets.zero,
                        children: [
                          _menuCard(),
                          const SizedBox(height: 8),
                          FilledButton.icon(
                            onPressed: () => _requestLogout(context),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 40),
                              backgroundColor: const Color(0xFFFEF2F2),
                              foregroundColor: AppColors.critical,
                            ),
                            icon: const Icon(Icons.logout, size: 18),
                            label: const Text('Sign Out'),
                          ),
                        ],
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

  Widget _landscapeNotificationButton() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.divider),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.notifications_outlined,
            color: AppColors.textSecondary,
            size: 21,
          ),
        ),
        Positioned(
          top: -4,
          right: -4,
          child: Container(
            width: 17,
            height: 17,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.critical,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.canvas, width: 2),
            ),
            child: const Text(
              '2',
              style: TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _landscapeAddressCard(String serviceAddress, String serviceState) {
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
            icon: Icons.flag_outlined,
            label: 'Report a Problem',
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ReportFlowScreen())),
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
  other('Other issue', false);

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

class _ReportFlowScreenState extends State<ReportFlowScreen> {
  String _selectedState = 'Selangor';
  bool _isWater = true;
  LeakScenario? _pendingWater;
  _ElecScenario? _pendingElec;
  final _description = TextEditingController();
  final _address = TextEditingController();
  DateTime _occurredAt = DateTime.now();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _address.text = (Supabase.instance.client.auth.currentUser
            ?.userMetadata?['service_address'] as String?) ??
        _defaultServiceAddress;
  }

  @override
  void dispose() {
    _description.dispose();
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    if (app.loading) {
      return const Scaffold(
        backgroundColor: AppColors.canvas,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final states = app.baseline.states;
    if (!states.contains(_selectedState) && states.isNotEmpty) {
      _selectedState = states.first;
    }
    final perCapita = app.baseline.perCapitaLPerDay(_selectedState);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Report a Problem'),
        backgroundColor: AppColors.adminPrimary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
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
                              _pendingElec = null;
                            }))),
                Expanded(
                    child: _utilityTab(
                        'Electricity',
                        Icons.electric_bolt_outlined,
                        AppColors.electricityAccent,
                        !_isWater,
                        () => setState(() {
                              _isWater = false;
                              _pendingWater = null;
                            }))),
              ],
            ),
          ),
          const SizedBox(height: 10),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('YOUR STATE'),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedState,
                  isDense: true,
                  decoration: const InputDecoration(
                    labelText: 'State',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(),
                  ),
                  items: states
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (s) =>
                      setState(() => _selectedState = s ?? _selectedState),
                ),
                if (_isWater) ...[
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
                const SectionLabel('WHAT\'S HAPPENING'),
                const SizedBox(height: 4),
                const Text(
                  'Choose a category, then give the Admin enough detail to review it.',
                  style:
                      TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _isWater
                      ? LeakScenario.values
                          .map((s) => _waterChip(app, s))
                          .toList()
                      : _ElecScenario.values
                          .map((s) => _elecChip(app, s))
                          .toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('REPORT DETAILS'),
                const SizedBox(height: 12),
                TextField(
                  controller: _address,
                  decoration:
                      const InputDecoration(labelText: 'Service address'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _description,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'What happened?',
                    hintText:
                        'For example: water is pooling under the kitchen sink.',
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _occurredAt,
                      firstDate:
                          DateTime.now().subtract(const Duration(days: 30)),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null && mounted) {
                      setState(() => _occurredAt = picked);
                    }
                  },
                  icon: const Icon(Icons.schedule_outlined),
                  label: Text(
                      'Occurred: ${_occurredAt.day}/${_occurredAt.month}/${_occurredAt.year}'),
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
            label: const Text('Submit for Admin review'),
          ),
          const SizedBox(height: 24),
        ],
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

  Widget _waterChip(AppState app, LeakScenario scenario) {
    final selected = _pendingWater == scenario;
    return GestureDetector(
      onTap: () {
        setState(() => _pendingWater = scenario);
      },
      child: _chip(scenario.label, selected, AppColors.waterAccent),
    );
  }

  Widget _elecChip(AppState app, _ElecScenario scenario) {
    final selected = _pendingElec == scenario;
    return GestureDetector(
      onTap: () {
        setState(() => _pendingElec = scenario);
      },
      child: _chip(scenario.label, selected, AppColors.electricityAccent),
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
    final category = _isWater ? _pendingWater?.label : _pendingElec?.label;
    if (category == null ||
        _description.text.trim().isEmpty ||
        _address.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Choose a category and complete the address and description.')));
      return;
    }
    setState(() => _submitting = true);
    try {
      await app.submitHouseholdProblem(
        utility: _isWater ? Utility.water : Utility.electricity,
        state: _selectedState,
        address: _address.text.trim(),
        category: category,
        description: _description.text.trim(),
        occurredAt: _occurredAt,
      );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _description.clear();
        _pendingWater = null;
        _pendingElec = null;
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
