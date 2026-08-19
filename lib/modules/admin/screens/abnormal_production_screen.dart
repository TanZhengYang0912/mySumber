import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../theme/tokens.dart';
import '../../auth/state/auth_state.dart';
import '../../electricity/models/electricity_models.dart';
import '../../leakage/models/alert.dart';
import '../../leakage/screens/network_error.dart';
import '../../leakage/services/nrw_service.dart';
import '../../leakage/state/app_state.dart';
import '../services/abnormal_production_layout.dart';
import '../../../theme/page_header.dart';

class AbnormalProductionScreen extends StatefulWidget {
  final bool showBackToOversight;

  const AbnormalProductionScreen({
    super.key,
    this.showBackToOversight = false,
  });

  @override
  State<AbnormalProductionScreen> createState() =>
      _AbnormalProductionScreenState();
}

class _AbnormalProductionScreenState extends State<AbnormalProductionScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  String? _busyKey;
  String? _selectedWaterState;
  String? _selectedElectricityState;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this)..addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tab
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  Future<void> _run(
    String busyKey,
    String label,
    Future<bool> Function() action,
  ) async {
    setState(() => _busyKey = busyKey);
    try {
      final reported = await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(reported
            ? 'Reported $label to the worker queue.'
            : '$label was already reported.'),
        backgroundColor: reported ? AppColors.adminPrimary : Colors.blueGrey,
      ));
    } catch (_) {
      if (mounted) showNetworkErrorSnackBar(context);
    } finally {
      if (mounted) setState(() => _busyKey = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (app.loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final water = [...app.nrw.analyse()]
      ..sort((a, b) => b.lossPct.compareTo(a.lossPct));
    final electricity = [...app.electricityLoss.analyse()]
      ..sort((a, b) => b.lossPct.compareTo(a.lossPct));
    final tampering = [...app.tamperingCandidates]
      ..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          _buildHeader(context),
          _buildTabBar(water.length, electricity.length),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _waterTab(app, water),
                _electricityTab(app, electricity, tampering),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return PageHeader(
      title: 'Abnormal Production',
      icon: Icons.notifications_outlined,
      leading: widget.showBackToOversight
          ? IconButton(
              tooltip: 'Back to Oversight',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
            )
          : null,
      onLogout: () => context.read<RoleState>().logout(),
    );
  }

  Widget _buildTabBar(int waterCount, int electricityCount) {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tab,
        labelColor: AppColors.adminPrimary,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        indicatorColor: AppColors.adminPrimary,
        indicatorWeight: 3,
        dividerColor: AppColors.divider,
        tabs: [
          Tab(text: 'Water $waterCount'),
          Tab(text: 'Electricity $electricityCount'),
        ],
      ),
    );
  }

  Widget _waterTab(AppState app, List<NrwResult> water) {
    return _anomalyWorkspace(
      results: water,
      unit: 'MLD',
      reportedStates: app.reportedWaterStates,
      selectedState: _selectedWaterState,
      onSelected: (state) => setState(() => _selectedWaterState = state),
      onReport: (result) => _run(
        'W-${result.state}',
        result.state,
        () => app.reportAbnormalState(result),
      ),
      busyKeyFor: (result) => 'W-${result.state}',
    );
  }

  Widget _electricityTab(
    AppState app,
    List<NrwResult> electricity,
    List<ElectricityRecord> tampering,
  ) {
    return _anomalyWorkspace(
      results: electricity,
      unit: 'GWh',
      reportedStates: app.reportedElectricityStates,
      selectedState: _selectedElectricityState,
      onSelected: (state) => setState(() => _selectedElectricityState = state),
      onReport: (result) => _run(
        'E-${result.state}',
        result.state,
        () => app.reportElectricityState(result),
      ),
      busyKeyFor: (result) => 'E-${result.state}',
      tampering: tampering,
      onReportTampering: (record) {
        final key = AppState.monthKey(record.date);
        return _run(
          'T-$key',
          DateFormat('MMM y').format(record.date),
          () => app.reportElectricityTampering(record),
        );
      },
      isTamperingReported: (record) =>
          app.reportedTamperingKeys.contains(AppState.monthKey(record.date)),
    );
  }

  Widget _anomalyWorkspace({
    required List<NrwResult> results,
    required String unit,
    required Set<String> reportedStates,
    required String? selectedState,
    required ValueChanged<String> onSelected,
    required Future<void> Function(NrwResult result) onReport,
    required String Function(NrwResult result) busyKeyFor,
    List<ElectricityRecord> tampering = const [],
    Future<void> Function(ElectricityRecord record)? onReportTampering,
    bool Function(ElectricityRecord record)? isTamperingReported,
  }) {
    final selected = _selectedResult(results, selectedState);
    final split = usesAbnormalProductionSplitView(MediaQuery.sizeOf(context));
    final summary = _summaryStrip(results, reportedStates);

    if (results.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [summary, const SizedBox(height: 16), _emptyCard(unit)],
      );
    }

    final listChildren = _rankedChildren(
      results: results,
      unit: unit,
      reportedStates: reportedStates,
      selectedState: selected?.state,
      onSelected: onSelected,
      onReport: onReport,
      busyKeyFor: busyKeyFor,
      tampering: tampering,
      onReportTampering: onReportTampering,
      isTamperingReported: isTamperingReported,
    );

    if (!split) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [summary, const SizedBox(height: 16), ...listChildren],
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          summary,
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 330,
                    child: ListView(children: listChildren),
                  ),
                  const VerticalDivider(width: 1, color: AppColors.divider),
                  Expanded(
                    child: _detailPanel(
                      result: selected!,
                      unit: unit,
                      reported: reportedStates.contains(selected.state),
                      busyKey: busyKeyFor(selected),
                      onReport: () => onReport(selected),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  NrwResult? _selectedResult(List<NrwResult> results, String? selectedState) {
    if (results.isEmpty) return null;
    return results.firstWhere(
      (result) => result.state == selectedState,
      orElse: () => results.first,
    );
  }

  Widget _summaryStrip(List<NrwResult> results, Set<String> reportedStates) {
    final critical =
        results.where((result) => result.severity == Severity.high).length;
    final high =
        results.where((result) => result.severity == Severity.medium).length;
    final reported =
        results.where((result) => reportedStates.contains(result.state)).length;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _summaryPill('$critical Critical', AppColors.critical,
            AppColors.criticalSurface),
        _summaryPill('$high High', AppColors.warning, AppColors.warningSurface),
        _summaryPill('$reported Reported', AppColors.waterAccent,
            AppColors.waterSurface),
        const Padding(
          padding: EdgeInsets.only(left: 4),
          child: Text(
            'Sorted by highest loss',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryPill(String text, Color color, Color surface) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style:
            TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800),
      ),
    );
  }

  List<Widget> _rankedChildren({
    required List<NrwResult> results,
    required String unit,
    required Set<String> reportedStates,
    required String? selectedState,
    required ValueChanged<String> onSelected,
    required Future<void> Function(NrwResult result) onReport,
    required String Function(NrwResult result) busyKeyFor,
    required List<ElectricityRecord> tampering,
    required Future<void> Function(ElectricityRecord record)? onReportTampering,
    required bool Function(ElectricityRecord record)? isTamperingReported,
  }) {
    return [
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(
          'Ranked by loss',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: .2,
          ),
        ),
      ),
      ...results.map(
        (result) => _anomalyRow(
          result: result,
          unit: unit,
          selected: selectedState == result.state,
          reported: reportedStates.contains(result.state),
          onTap: () => _showResult(
            result,
            unit,
            reportedStates.contains(result.state),
            busyKeyFor(result),
            () => onReport(result),
          ),
          onSelect: () => onSelected(result.state),
        ),
      ),
      if (tampering.isNotEmpty) ...[
        const Divider(height: 28, color: AppColors.divider),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            'Tampering spikes',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        ...tampering.map(
          (record) => _tamperingRow(
            record,
            isTamperingReported?.call(record) ?? false,
            () => onReportTampering?.call(record),
          ),
        ),
      ],
    ];
  }

  Widget _anomalyRow({
    required NrwResult result,
    required String unit,
    required bool selected,
    required bool reported,
    required VoidCallback onTap,
    required VoidCallback onSelect,
  }) {
    final severity = _severityStyle(result.severity);
    return Material(
      color: selected ? AppColors.adminSurface : Colors.transparent,
      child: InkWell(
        onTap: () {
          onSelect();
          if (!usesAbnormalProductionSplitView(MediaQuery.sizeOf(context))) {
            onTap();
          }
        },
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: selected ? AppColors.adminPrimary : Colors.transparent,
                width: 4,
              ),
              bottom: const BorderSide(color: AppColors.divider),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: severity.surface, shape: BoxShape.circle),
                child: Text(
                  '${result.lossPct.round()}',
                  style: TextStyle(
                      color: severity.color,
                      fontSize: 9,
                      fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(result.state,
                              style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800)),
                        ),
                        _statusPill(
                            reported ? 'Reported' : severity.label,
                            reported ? AppColors.waterAccent : severity.color,
                            reported
                                ? AppColors.waterSurface
                                : severity.surface),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${result.lossPct.toStringAsFixed(1)}% loss · '
                      '${(result.producedMld - result.billedMld).round()} $unit gap',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 2),
              const Icon(Icons.chevron_right, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  void _showResult(
    NrwResult result,
    String unit,
    bool reported,
    String busyKey,
    VoidCallback onReport,
  ) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * .78,
            child: _detailPanel(
              result: result,
              unit: unit,
              reported: reported,
              busyKey: busyKey,
              onReport: onReport,
            ),
          ),
        ),
      );
    });
  }

  Widget _detailPanel({
    required NrwResult result,
    required String unit,
    required bool reported,
    required String busyKey,
    required VoidCallback onReport,
  }) {
    final severity = _severityStyle(result.severity);
    final gap = result.producedMld - result.billedMld;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(result.state,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          _statusPill(severity.label, severity.color, severity.surface),
          const SizedBox(height: 14),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '${result.lossPct.toStringAsFixed(1)}%',
                  style: TextStyle(
                      color: severity.color,
                      fontSize: 42,
                      fontWeight: FontWeight.w800),
                ),
                const TextSpan(
                  text: ' loss',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${result.year} · production does not match billed consumption.',
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 24),
          _metricRow(result, unit, gap),
          const SizedBox(height: 28),
          _comparisonChart(result, unit),
          const SizedBox(height: 28),
          _actionButton(reported, busyKey, onReport),
        ],
      ),
    );
  }

  Widget _metricRow(NrwResult result, String unit, double gap) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _metric('Produced', result.producedMld, unit, AppColors.waterAccent),
        _metric('Billed', result.billedMld, unit, AppColors.adminPrimary),
        _metric('Estimated gap', gap, unit, AppColors.critical),
      ],
    );
  }

  Widget _metric(String label, double value, String unit, Color color) {
    return Container(
      width: 138,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 11)),
          const SizedBox(height: 4),
          Text('${value.round()} $unit',
              style: TextStyle(
                  color: color, fontSize: 17, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _comparisonChart(NrwResult result, String unit) {
    final produced = result.producedMld;
    final billed = result.billedMld;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Production vs. billed consumption ($unit)',
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        _comparisonBar(
            'Produced', produced, produced, unit, AppColors.waterAccent),
        const SizedBox(height: 10),
        _comparisonBar(
            'Billed', billed, produced, unit, AppColors.adminPrimary),
      ],
    );
  }

  Widget _comparisonBar(
      String label, double value, double maximum, String unit, Color color) {
    final fraction = maximum == 0 ? 0.0 : (value / maximum).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
                child: Text(label,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12))),
            Text('${value.round()} $unit',
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 10,
            color: color,
            backgroundColor: AppColors.divider,
          ),
        ),
      ],
    );
  }

  Widget _tamperingRow(
      ElectricityRecord record, bool reported, VoidCallback onReport) {
    final lossPct =
        record.supply == 0 ? 0.0 : record.losses / record.supply * 100;
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      title: Text(DateFormat('MMM y').format(record.date),
          style: const TextStyle(
              fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      subtitle: Text('${lossPct.toStringAsFixed(1)}% of supply',
          style: const TextStyle(color: AppColors.textSecondary)),
      trailing: TextButton(
        onPressed: reported ? null : onReport,
        child: Text(reported ? 'Reported' : 'Report'),
      ),
    );
  }

  Widget _emptyCard(String unit) => AppCard(
        child: Text(
          'No abnormal $unit production states detected.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      );

  Widget _statusPill(String text, Color color, Color surface) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
          color: surface, borderRadius: BorderRadius.circular(999)),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }

  _SeverityStyle _severityStyle(String severity) {
    if (severity == Severity.high) {
      return const _SeverityStyle(
          'Critical', AppColors.critical, AppColors.criticalSurface);
    }
    if (severity == Severity.medium) {
      return const _SeverityStyle(
          'High', AppColors.warning, AppColors.warningSurface);
    }
    return const _SeverityStyle(
        'Monitor', AppColors.success, AppColors.successSurface);
  }

  Widget _actionButton(bool reported, String busyKey, VoidCallback onReport) {
    final busy = _busyKey == busyKey;
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: reported
          ? OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('Already reported'),
            )
          : FilledButton.icon(
              onPressed: busy ? null : onReport,
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.adminPrimary),
              icon: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.person_add_alt_1_outlined, size: 18),
              label: const Text('Send to worker queue'),
            ),
    );
  }
}

class _SeverityStyle {
  final String label;
  final Color color;
  final Color surface;

  const _SeverityStyle(this.label, this.color, this.surface);
}
