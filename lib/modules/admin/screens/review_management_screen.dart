import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../theme/tokens.dart';
import '../../leakage/models/alert.dart';
import '../../leakage/state/app_state.dart';
import '../services/admin_tablet_layout.dart';
import '../services/anomaly_review_filter.dart';
import '../widgets/landscape_filter_menu.dart';
import 'anomaly_review_detail_screen.dart';

class ReviewManagementScreen extends StatefulWidget {
  const ReviewManagementScreen({super.key});

  @override
  State<ReviewManagementScreen> createState() => _ReviewManagementScreenState();
}

class _ReviewManagementScreenState extends State<ReviewManagementScreen> {
  Set<String> _statuses = {AlertStatus.pending};
  Utility? _utility;
  String? _state;
  String? _facilityName;
  String? _equipmentName;
  bool _highSeverityOnly = false;
  int? _selectedAlertId;
  bool _selectionSyncScheduled = false;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final alerts = app.alerts;
    final states = AnomalyReviewFilter.states(alerts);
    final selectedState = AnomalyReviewFilter.normalizeOption(_state, states);
    final facilities =
        AnomalyReviewFilter.facilities(alerts, state: selectedState);
    final selectedFacility =
        AnomalyReviewFilter.normalizeOption(_facilityName, facilities);
    final equipment = AnomalyReviewFilter.equipment(
      alerts,
      state: selectedState,
      facilityName: selectedFacility,
    );
    final selectedEquipment =
        AnomalyReviewFilter.normalizeOption(_equipmentName, equipment);
    _syncLocationFilters(
      state: selectedState,
      facilityName: selectedFacility,
      equipmentName: selectedEquipment,
    );
    final query = AnomalyReviewQuery(
      statuses: _statuses,
      utility: _utility,
      state: selectedState,
      facilityName: selectedFacility,
      equipmentName: selectedEquipment,
      highSeverityOnly: _highSeverityOnly,
    );
    final results = AnomalyReviewFilter.apply(alerts, query);

    return LayoutBuilder(
      builder: (context, constraints) {
        final mode = adminLayoutModeFor(MediaQuery.sizeOf(context));
        final isTablet = mode == AdminLayoutMode.tabletLandscape;
        if (app.loading) {
          return Scaffold(
            backgroundColor: AppColors.canvas,
            body: Column(
              children: [
                isTablet
                    ? _tabletHeader(results)
                    : mode == AdminLayoutMode.phoneLandscape
                        ? _phoneLandscapeHeader(
                            states: states,
                            facilities: facilities,
                            equipment: equipment,
                          )
                        : _header(),
                const LinearProgressIndicator(minHeight: 2),
              ],
            ),
          );
        }
        return Scaffold(
          backgroundColor: AppColors.canvas,
          body: isTablet
              ? _tabletLayout(
                  results: results,
                  states: states,
                  facilities: facilities,
                  equipment: equipment,
                )
              : mode == AdminLayoutMode.phoneLandscape
                  ? _phoneLandscapeLayout(
                      results: results,
                      states: states,
                      facilities: facilities,
                      equipment: equipment,
                    )
                  : _phoneLayout(
                      alerts: alerts,
                      results: results,
                      states: states,
                      facilities: facilities,
                      equipment: equipment,
                    ),
        );
      },
    );
  }

  Widget _phoneLandscapeLayout({
    required List<Alert> results,
    required List<String> states,
    required List<String> facilities,
    required List<String> equipment,
  }) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          children: [
            _phoneLandscapeHeader(
              states: states,
              facilities: facilities,
              equipment: equipment,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: results.isEmpty
                  ? _emptyState()
                  : GridView.builder(
                      key: const PageStorageKey('phone-landscape-review-grid'),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1.65,
                      ),
                      itemCount: results.length,
                      itemBuilder: (context, index) =>
                          _landscapeAlertCard(results[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _phoneLandscapeHeader({
    required List<String> states,
    required List<String> facilities,
    required List<String> equipment,
  }) {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.adminSurface,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.analytics_outlined,
              color: AppColors.adminPrimary,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'AI Review',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          _landscapeStatusLabel(),
          const SizedBox(width: 8),
          LandscapeFilterMenu(
            child: _landscapeFilterControls(
              states: states,
              facilities: facilities,
              equipment: equipment,
            ),
          ),
        ],
      ),
    );
  }

  Widget _landscapeStatusLabel() {
    final label = _statuses.length == AlertStatus.all.length
        ? 'All'
        : _statuses.length == 2 &&
                _statuses.contains(AlertStatus.investigating) &&
                _statuses.contains(AlertStatus.notFixed)
            ? 'Ongoing'
            : AlertStatus.label(_statuses.first);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _landscapeFilterControls({
    required List<String> states,
    required List<String> facilities,
    required List<String> equipment,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: SectionLabel('Filter anomalies')),
            TextButton(onPressed: _clearFilters, child: const Text('Clear')),
          ],
        ),
        const SizedBox(height: 8),
        _statusChips(),
        const SizedBox(height: 10),
        _utilityChips(),
        const SizedBox(height: 10),
        FilterChip(
          label: const Text('High severity'),
          selected: _highSeverityOnly,
          onSelected: (selected) =>
              setState(() => _highSeverityOnly = selected),
          selectedColor: AppColors.criticalSurface,
          checkmarkColor: AppColors.critical,
          labelStyle: TextStyle(
            color:
                _highSeverityOnly ? AppColors.critical : AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        _dropdown(
          label: 'State / Federal Territory',
          value: _state,
          values: states,
          onChanged: (value) => setState(() {
            _state = value;
            _facilityName = null;
            _equipmentName = null;
          }),
        ),
        const SizedBox(height: 10),
        _dropdown(
          label: 'Shopping Mall',
          value: _facilityName,
          values: facilities,
          onChanged: (value) => setState(() {
            _facilityName = value;
            _equipmentName = null;
          }),
        ),
        const SizedBox(height: 10),
        _dropdown(
          label: 'Equipment',
          value: _equipmentName,
          values: equipment,
          onChanged: (value) => setState(() => _equipmentName = value),
        ),
      ],
    );
  }

  Widget _phoneLayout({
    required List<Alert> alerts,
    required List<Alert> results,
    required List<String> states,
    required List<String> facilities,
    required List<String> equipment,
  }) {
    return ListView(
      key: const PageStorageKey('admin-review-phone-list'),
      padding: EdgeInsets.zero,
      children: [
        _header(),
        _summary(alerts),
        _filters(
          states: states,
          facilities: facilities,
          equipment: equipment,
        ),
        _resultsHeader(results.length),
        for (final alert in results) _alertCard(alert),
        if (results.isEmpty) _emptyState(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 44, 18, 20),
      decoration: const BoxDecoration(
        color: AppColors.adminPrimary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.analytics_outlined,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI Anomaly Review',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w800)),
                SizedBox(height: 4),
                Text('Review water and electricity detection results',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabletLayout({
    required List<Alert> results,
    required List<String> states,
    required List<String> facilities,
    required List<String> equipment,
  }) {
    _syncSelection(results);
    final selectedAlert = _selectedAlert(results);

    return Column(
      children: [
        _tabletHeader(results),
        _tabletFilters(
          states: states,
          facilities: facilities,
          equipment: equipment,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Row(
              children: [
                SizedBox(
                  width: 400,
                  child: Column(
                    children: [
                      _resultsHeader(results.length, compact: true),
                      Expanded(
                        child: results.isEmpty
                            ? _emptyState()
                            : ListView.separated(
                                key: const PageStorageKey(
                                  'admin-review-tablet-list',
                                ),
                                padding: const EdgeInsets.only(top: 2),
                                itemCount: results.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, index) =>
                                    _tabletResultTile(
                                  results[index],
                                  selected:
                                      results[index].id == selectedAlert?.id,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 32),
                Expanded(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 840),
                      child: selectedAlert?.id == null
                          ? _tabletEmptyDetail()
                          : AnomalyReviewDetailContent(
                              key: ValueKey(selectedAlert!.id),
                              alertId: selectedAlert.id!,
                              pane: true,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _tabletHeader(List<Alert> results) {
    final pending =
        results.where((alert) => alert.status == AlertStatus.pending).length;
    final high =
        results.where((alert) => alert.severity == Severity.high).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            const Icon(Icons.analytics_outlined,
                color: AppColors.adminPrimary, size: 28),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Anomaly Review',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Review water and electricity detection results',
                    style:
                        TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            _tabletStat('$pending', 'Pending'),
            const SizedBox(width: 18),
            _tabletStat('$high', 'High severity'),
            const SizedBox(width: 18),
            _tabletStat('${results.length}', 'Results'),
          ],
        ),
      ),
    );
  }

  Widget _tabletStat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(value,
            style: const TextStyle(
                color: AppColors.adminPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w800)),
        Text(label,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
      ],
    );
  }

  Widget _tabletFilters({
    required List<String> states,
    required List<String> facilities,
    required List<String> equipment,
  }) {
    return Container(
      width: double.infinity,
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 12),
      child: Column(
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const _FilterCaption('Status'),
              _statusChips(),
              const _FilterCaption('Utility'),
              _utilityChips(),
              FilterChip(
                label: const Text('High severity'),
                selected: _highSeverityOnly,
                onSelected: (selected) =>
                    setState(() => _highSeverityOnly = selected),
                selectedColor: AppColors.criticalSurface,
                checkmarkColor: AppColors.critical,
                labelStyle: TextStyle(
                  color: _highSeverityOnly
                      ? AppColors.critical
                      : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _dropdown(
                  label: 'State / Federal Territory',
                  value: _state,
                  values: states,
                  onChanged: (value) => setState(() {
                    _state = value;
                    _facilityName = null;
                    _equipmentName = null;
                  }),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _dropdown(
                  label: 'Shopping Mall',
                  value: _facilityName,
                  values: facilities,
                  onChanged: (value) => setState(() {
                    _facilityName = value;
                    _equipmentName = null;
                  }),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _dropdown(
                  label: 'Equipment',
                  value: _equipmentName,
                  values: equipment,
                  onChanged: (value) => setState(() => _equipmentName = value),
                ),
              ),
              const SizedBox(width: 6),
              TextButton(
                onPressed: _clearFilters,
                child: const Text('Clear'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Alert? _selectedAlert(List<Alert> results) {
    for (final alert in results) {
      if (alert.id == _selectedAlertId) return alert;
    }
    for (final alert in results) {
      if (alert.id != null) return alert;
    }
    return null;
  }

  void _syncSelection(List<Alert> results) {
    final selectedStillMatches = _selectedAlertId != null &&
        results.any((a) => a.id == _selectedAlertId);
    final nextId = _selectedAlert(results)?.id;
    if (selectedStillMatches ||
        _selectedAlertId == nextId ||
        _selectionSyncScheduled) {
      return;
    }
    final previousId = _selectedAlertId;
    _selectionSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _selectedAlertId = nextId;
        _selectionSyncScheduled = false;
      });
      if (previousId != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content:
                  Text('The selected anomaly changed with the latest results.'),
            ),
          );
      }
    });
  }

  void _syncLocationFilters({
    required String? state,
    required String? facilityName,
    required String? equipmentName,
  }) {
    if (_state == state &&
        _facilityName == facilityName &&
        _equipmentName == equipmentName) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _state = state;
        _facilityName = facilityName;
        _equipmentName = equipmentName;
      });
    });
  }

  Widget _tabletEmptyDetail() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.rule_folder_outlined,
                size: 42, color: AppColors.textTertiary),
            SizedBox(height: 10),
            Text('Select an anomaly to review',
                style: TextStyle(fontWeight: FontWeight.w700)),
            SizedBox(height: 4),
            Text(
              'Its evidence and AI analysis will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summary(List<Alert> alerts) {
    final pending = alerts.where((a) => a.status == AlertStatus.pending).length;
    final ongoing = alerts
        .where((a) =>
            a.status == AlertStatus.investigating ||
            a.status == AlertStatus.notFixed)
        .length;
    final high = alerts.where((a) => a.severity == Severity.high).length;

    return SizedBox(
      height: 108,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        children: [
          _summaryCard('Pending', '$pending', Icons.pending_actions,
              AppColors.warningSurface, AppColors.warning),
          _summaryCard('Ongoing', '$ongoing', Icons.sync,
              AppColors.waterSurface, AppColors.waterAccent),
          _summaryCard('High severity', '$high', Icons.priority_high,
              AppColors.criticalSurface, AppColors.critical),
        ],
      ),
    );
  }

  Widget _summaryCard(
    String label,
    String value,
    IconData icon,
    Color background,
    Color foreground,
  ) {
    return Container(
      width: 135,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: foreground, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(value,
                  style: TextStyle(
                      color: foreground,
                      fontSize: 20,
                      fontWeight: FontWeight.w800)),
              Text(label,
                  style: TextStyle(
                      color: foreground.withValues(alpha: 0.8), fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filters({
    required List<String> states,
    required List<String> facilities,
    required List<String> equipment,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SectionLabel('FILTER ANOMALIES'),
              const Spacer(),
              TextButton(
                onPressed: _clearFilters,
                child: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _statusChips(),
          const SizedBox(height: 8),
          _utilityChips(),
          const SizedBox(height: 8),
          FilterChip(
            label: const Text('High severity'),
            selected: _highSeverityOnly,
            onSelected: (selected) =>
                setState(() => _highSeverityOnly = selected),
            selectedColor: AppColors.criticalSurface,
            checkmarkColor: AppColors.critical,
            labelStyle: TextStyle(
              color: _highSeverityOnly
                  ? AppColors.critical
                  : AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          _dropdown(
            label: 'State / Federal Territory',
            value: _state,
            values: states,
            onChanged: (value) => setState(() {
              _state = value;
              _facilityName = null;
              _equipmentName = null;
            }),
          ),
          const SizedBox(height: 10),
          _dropdown(
            label: 'Shopping Mall',
            value: _facilityName,
            values: facilities,
            onChanged: (value) => setState(() {
              _facilityName = value;
              _equipmentName = null;
            }),
          ),
          const SizedBox(height: 10),
          _dropdown(
            label: 'Equipment',
            value: _equipmentName,
            values: equipment,
            onChanged: (value) => setState(() => _equipmentName = value),
          ),
        ],
      ),
    );
  }

  Widget _statusChips() {
    final options = <({String label, Set<String> values})>[
      (label: 'All', values: AlertStatus.all.toSet()),
      (label: 'Pending', values: {AlertStatus.pending}),
      (
        label: 'Ongoing',
        values: {AlertStatus.investigating, AlertStatus.notFixed},
      ),
      (label: 'Solved', values: {AlertStatus.resolved}),
      (label: 'Faults', values: {AlertStatus.faults}),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        for (final option in options)
          Builder(
            builder: (context) {
              final selected = _statuses.length == option.values.length &&
                  _statuses.containsAll(option.values);
              return FilterChip(
                label: Text(option.label),
                selected: selected,
                onSelected: (_) => setState(() => _statuses = option.values),
                selectedColor: AppColors.adminPrimary,
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _utilityChips() {
    return Wrap(
      spacing: 8,
      children: [
        _utilityChip('All utilities', null),
        _utilityChip('Water', Utility.water),
        _utilityChip('Electricity', Utility.electricity),
      ],
    );
  }

  Widget _utilityChip(String label, Utility? utility) {
    final selected = _utility == utility;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _utility = utility),
      selectedColor: AppColors.adminPrimary,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String? value,
    required List<String> values,
    required ValueChanged<String?> onChanged,
  }) {
    final selectedValue = values.contains(value) ? value : null;
    return DropdownButtonFormField<String>(
      initialValue: selectedValue,
      decoration: InputDecoration(labelText: label),
      items: [
        const DropdownMenuItem<String>(value: null, child: Text('All')),
        for (final item in values)
          DropdownMenuItem<String>(value: item, child: Text(item)),
      ],
      onChanged: values.isEmpty ? null : onChanged,
    );
  }

  Widget _resultsHeader(int count, {bool compact = false}) {
    return Padding(
      padding: compact
          ? const EdgeInsets.fromLTRB(2, 0, 2, 10)
          : const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Row(
        children: [
          const SectionLabel('ANOMALY RESULTS'),
          const Spacer(),
          Text('$count found',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _alertCard(Alert alert) {
    final facility = alert.facilityName ?? 'Facility not linked';
    final equipment = alert.equipmentName ?? 'Equipment not linked';
    final city = alert.facilityCity;
    final explanation = _reviewExplanation(alert.explanation);
    final utilityLabel =
        alert.utility == Utility.water ? 'Water' : 'Electricity';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: alert.id == null
            ? null
            : () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => AnomalyReviewDetailScreen(alertId: alert.id!),
                )),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(facility,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                  Icon(Icons.chevron_right,
                      color: alert.id == null
                          ? AppColors.textTertiary
                          : AppColors.adminPrimary),
                ],
              ),
              if (city != null && city.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text('$city, ${alert.state}',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ] else ...[
                const SizedBox(height: 2),
                Text(alert.state,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.settings_input_component_outlined,
                      size: 17, color: AppColors.adminPrimary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(equipment,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  _statusPill(alert.status),
                ],
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  _utilityPill(utilityLabel, alert.utility),
                  const SizedBox(width: 6),
                  _severityPill(alert.severity),
                  const Spacer(),
                  Text(DateFormat('d MMM y').format(alert.detectedAt),
                      style: const TextStyle(
                          color: AppColors.textTertiary, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 10),
              Text(explanation,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.textSecondary, height: 1.35)),
              const SizedBox(height: 10),
              _valueSummary(alert),
            ],
          ),
        ),
      ),
    );
  }

  Widget _landscapeAlertCard(Alert alert) {
    final facility = alert.facilityName ?? 'Facility not linked';
    final equipment = alert.equipmentName ?? 'Equipment not linked';
    final city = alert.facilityCity;
    final utilityLabel =
        alert.utility == Utility.water ? 'Water' : 'Electricity';
    final location = city == null || city.trim().isEmpty
        ? '${alert.state} · $equipment'
        : '$city, ${alert.state} · $equipment';

    return Semantics(
      button: alert.id != null,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: alert.id == null
            ? null
            : () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => AnomalyReviewDetailScreen(alertId: alert.id!),
                )),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      facility,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: alert.id == null
                        ? AppColors.textTertiary
                        : AppColors.adminPrimary,
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                location,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
              const Spacer(),
              Wrap(
                spacing: 5,
                runSpacing: 4,
                children: [
                  _utilityPill(utilityLabel, alert.utility),
                  _severityPill(alert.severity),
                  _statusPill(alert.status),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                DateFormat('d MMM y').format(alert.detectedAt),
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabletResultTile(Alert alert, {required bool selected}) {
    final facility = alert.facilityName ?? 'Facility not linked';
    final equipment = alert.equipmentName ?? 'Equipment not linked';
    final city = alert.facilityCity;
    final utilityLabel =
        alert.utility == Utility.water ? 'Water' : 'Electricity';

    return Semantics(
      selected: selected,
      button: alert.id != null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: alert.id == null
            ? null
            : () => setState(() => _selectedAlertId = alert.id),
        child: Container(
          constraints: const BoxConstraints(minHeight: 78),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.adminPrimary : AppColors.divider,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      facility,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w800),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: alert.id == null
                        ? AppColors.textTertiary
                        : AppColors.adminPrimary,
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                city == null || city.trim().isEmpty
                    ? '${alert.state} · $equipment'
                    : '$city, ${alert.state} · $equipment',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 11),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _utilityPill(utilityLabel, alert.utility),
                  const SizedBox(width: 5),
                  _severityPill(alert.severity),
                  const SizedBox(width: 5),
                  _statusPill(alert.status),
                  const Spacer(),
                  Text(
                    DateFormat('d MMM y').format(alert.detectedAt),
                    style: const TextStyle(
                        color: AppColors.textTertiary, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _valueSummary(Alert alert) {
    final hasBalance = alert.lossPct != null;
    final text = hasBalance
        ? 'Loss ${alert.lossPct!.toStringAsFixed(1)}%'
        : (alert.actualL != 0 || alert.baselineL != 0
            ? '${alert.actualL.round()} L vs ${alert.baselineL.round()} L baseline'
            : 'Evidence linked to alert details');
    return Row(
      children: [
        const Icon(Icons.show_chart, size: 16, color: AppColors.textTertiary),
        const SizedBox(width: 6),
        Text(text,
            style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _statusPill(String status) {
    return Pill(AlertStatus.label(status), color: _statusColor(status));
  }

  Widget _severityPill(String severity) {
    return Pill(Severity.label(severity), color: _severityColor(severity));
  }

  Widget _utilityPill(String utility, Utility type) {
    final color = type == Utility.water
        ? AppColors.waterAccent
        : AppColors.electricityAccent;
    return Pill(utility, color: color);
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      child: Column(
        children: const [
          Icon(Icons.search_off, size: 42, color: AppColors.textTertiary),
          SizedBox(height: 10),
          Text('No anomalies match these filters.',
              style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  void _clearFilters() {
    setState(() {
      _statuses = {AlertStatus.pending};
      _utility = null;
      _state = null;
      _facilityName = null;
      _equipmentName = null;
      _highSeverityOnly = false;
    });
  }

  String _reviewExplanation(String explanation) {
    final recommendationStart = RegExp(
      r'\s+Recommend\b.*$',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(explanation);
    if (recommendationStart == null) return explanation.trim();
    return explanation.substring(0, recommendationStart.start).trim();
  }

  Color _severityColor(String severity) {
    switch (severity) {
      case Severity.high:
        return AppColors.critical;
      case Severity.medium:
        return AppColors.warning;
      default:
        return AppColors.success;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case AlertStatus.pending:
        return AppColors.textSecondary;
      case AlertStatus.investigating:
        return AppColors.waterAccent;
      case AlertStatus.resolved:
        return AppColors.success;
      case AlertStatus.notFixed:
        return AppColors.critical;
      case AlertStatus.faults:
        return AppColors.warning;
      default:
        return AppColors.textSecondary;
    }
  }
}

class _FilterCaption extends StatelessWidget {
  final String text;

  const _FilterCaption(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.7,
      ),
    );
  }
}
