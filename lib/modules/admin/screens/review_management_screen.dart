import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../theme/tokens.dart';
import '../../leakage/models/alert.dart';
import '../../leakage/state/app_state.dart';
import '../services/anomaly_review_filter.dart';
import 'anomaly_review_detail_screen.dart';

class ReviewManagementScreen extends StatefulWidget {
  const ReviewManagementScreen({super.key});

  @override
  State<ReviewManagementScreen> createState() => _ReviewManagementScreenState();
}

class _ReviewManagementScreenState extends State<ReviewManagementScreen> {
  Set<String> _statuses = {
    AlertStatus.pending,
    AlertStatus.investigating,
    AlertStatus.notFixed,
  };
  Utility? _utility;
  String? _state;
  String? _facilityName;
  String? _equipmentName;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final alerts = app.alerts;
    final query = AnomalyReviewQuery(
      statuses: _statuses,
      utility: _utility,
      state: _state,
      facilityName: _facilityName,
      equipmentName: _equipmentName,
    );
    final results = AnomalyReviewFilter.apply(alerts, query);
    final states = AnomalyReviewFilter.states(alerts);
    final facilities = AnomalyReviewFilter.facilities(alerts, state: _state);
    final equipment = AnomalyReviewFilter.equipment(
      alerts,
      state: _state,
      facilityName: _facilityName,
    );

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _header(),
          if (app.loading)
            const LinearProgressIndicator(minHeight: 2)
          else ...[
            _summary(alerts),
            _filters(
              states: states,
              facilities: facilities,
              equipment: equipment,
            ),
            _resultsHeader(results.length),
            for (final alert in results) _alertCard(alert),
            if (results.isEmpty) _emptyState(),
          ],
          const SizedBox(height: 24),
        ],
      ),
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
          FilterChip(
            label: Text(option.label),
            selected: _statuses.containsAll(option.values) &&
                option.values.every(_statuses.contains),
            onSelected: (_) => setState(() => _statuses = option.values),
            selectedColor: AppColors.adminPrimary,
            checkmarkColor: Colors.white,
            labelStyle: TextStyle(
              color: _statuses.containsAll(option.values) &&
                      option.values.every(_statuses.contains)
                  ? Colors.white
                  : AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
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

  Widget _resultsHeader(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
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
      _statuses = {
        AlertStatus.pending,
        AlertStatus.investigating,
        AlertStatus.notFixed,
      };
      _utility = null;
      _state = null;
      _facilityName = null;
      _equipmentName = null;
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
