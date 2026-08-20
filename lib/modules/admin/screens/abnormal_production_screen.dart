import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../theme/filter_controls.dart';
import '../../../theme/tokens.dart';
import '../../auth/state/auth_state.dart';
import '../../dataset/models/models.dart';
import '../../dataset/state/dataset_state.dart';
import '../../electricity/models/electricity_models.dart';
import '../../leakage/models/ai_anomaly_analysis.dart';
import '../../leakage/models/alert.dart';
import '../../leakage/screens/network_error.dart';
import '../../leakage/screens/style.dart';
import '../../leakage/services/anomaly_ai_service.dart';
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
  String? _selectedMallNodeId;
  String? _selectedAllState;
  Utility? _stateUtility = Utility.water;
  Utility? _mallUtility = Utility.water;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this)..addListener(_refresh);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<DatasetState>().loadNodes();
    });
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tab
      ..removeListener(_refresh)
      ..dispose();
    _search.dispose();
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

    final dataset = context.watch<DatasetState>();
    final water = [...app.nrw.analyse()]
      ..sort((a, b) => b.lossPct.compareTo(a.lossPct));
    final electricity = [...app.electricityLoss.analyse()]
      ..sort((a, b) => b.lossPct.compareTo(a.lossPct));
    final tampering = [...app.tamperingCandidates]
      ..sort((a, b) => b.date.compareTo(a.date));
    final mallNodes = dataset.nodes.where(AppState.needsAttention).toList();
    final stateCount = switch (_stateUtility) {
      Utility.water => water.length,
      Utility.electricity => electricity.length,
      null => water.length + electricity.length,
    };
    final mallCount = mallNodes
        .where((n) =>
            _mallUtility == null ||
            n.utilityType ==
                (_mallUtility == Utility.water ? 'Water' : 'Electricity'))
        .length;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          _buildHeader(context),
          _buildTabBar(stateCount, mallCount),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _stateTab(app, water, electricity, tampering),
                _mallTab(app, mallNodes),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return PageHeader(
      title: 'Anomalies',
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

  Widget _buildTabBar(int stateCount, int mallCount) {
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
          Tab(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('State'),
                  const SizedBox(width: 6),
                  CountBadge(stateCount),
                ],
              ),
            ),
          ),
          Tab(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Mall'),
                  const SizedBox(width: 6),
                  CountBadge(mallCount),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stateTab(
    AppState app,
    List<NrwResult> water,
    List<NrwResult> electricity,
    List<ElectricityRecord> tampering,
  ) {
    // A shared tampering-report closure, since it's identical whether the
    // Electricity chip or the merged "All" view triggered it.
    Future<void> reportTamperingRecord(ElectricityRecord record) {
      final key = AppState.monthKey(record.date);
      return _run(
        'T-$key',
        DateFormat('MMM y').format(record.date),
        () => app.reportElectricityTampering(record),
      );
    }

    bool tamperingReported(ElectricityRecord record) =>
        app.reportedTamperingKeys.contains(AppState.monthKey(record.date));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: UtilityChips(
            selected: _stateUtility,
            onChanged: (u) => setState(() => _stateUtility = u),
          ),
        ),
        Expanded(
          child: switch (_stateUtility) {
            Utility.water => _anomalyWorkspace(
                app: app,
                results: water,
                unitOf: (_) => 'MLD',
                reportedStates: app.reportedWaterStates,
                selectedState: _selectedWaterState,
                onSelected: (state) =>
                    setState(() => _selectedWaterState = state),
                onReport: (result) => _run(
                  'W-${result.state}',
                  result.state,
                  () => app.reportAbnormalState(result),
                ),
                busyKeyFor: (result) => 'W-${result.state}',
              ),
            Utility.electricity => _anomalyWorkspace(
                app: app,
                results: electricity,
                unitOf: (_) => 'GWh',
                reportedStates: app.reportedElectricityStates,
                selectedState: _selectedElectricityState,
                onSelected: (state) =>
                    setState(() => _selectedElectricityState = state),
                onReport: (result) => _run(
                  'E-${result.state}',
                  result.state,
                  () => app.reportElectricityState(result),
                ),
                busyKeyFor: (result) => 'E-${result.state}',
                tampering: tampering,
                onReportTampering: reportTamperingRecord,
                isTamperingReported: tamperingReported,
              ),
            null => _anomalyWorkspace(
                app: app,
                results: [...water, ...electricity]
                  ..sort((a, b) => b.lossPct.compareTo(a.lossPct)),
                // NrwResult carries no utility tag of its own — identity
                // against the source list is how a merged row's unit gets
                // recovered. Safe: these are the exact same object
                // instances, never copies, so reference equality holds.
                unitOf: (r) => water.contains(r) ? 'MLD' : 'GWh',
                reportedStates: {
                  ...app.reportedWaterStates,
                  ...app.reportedElectricityStates,
                },
                selectedState: _selectedAllState,
                onSelected: (state) =>
                    setState(() => _selectedAllState = state),
                onReport: (result) => water.contains(result)
                    ? _run('W-${result.state}', result.state,
                        () => app.reportAbnormalState(result))
                    : _run('E-${result.state}', result.state,
                        () => app.reportElectricityState(result)),
                busyKeyFor: (result) => water.contains(result)
                    ? 'W-${result.state}'
                    : 'E-${result.state}',
                tampering: tampering,
                onReportTampering: reportTamperingRecord,
                isTamperingReported: tamperingReported,
              ),
          },
        ),
      ],
    );
  }

  Widget _mallTab(AppState app, List<EquipmentNode> allNodes) {
    final nodes = _mallUtility == null
        ? allNodes
        : allNodes
            .where((n) =>
                n.utilityType ==
                (_mallUtility == Utility.water ? 'Water' : 'Electricity'))
            .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: UtilityChips(
            selected: _mallUtility,
            onChanged: (u) => setState(() => _mallUtility = u),
          ),
        ),
        Expanded(child: _mallWorkspace(app, nodes)),
      ],
    );
  }

  Widget _mallWorkspace(AppState app, List<EquipmentNode> nodes) {
    final split = usesAbnormalProductionSplitView(MediaQuery.sizeOf(context));
    final query = _search.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? nodes
        : nodes
            .where((n) =>
                n.nodeName.toLowerCase().contains(query) ||
                (n.facilityName?.toLowerCase().contains(query) ?? false))
            .toList();
    final selected = _selectedMallNode(filtered);
    final searchBar = FilterSearchField(
      controller: _search,
      hint: 'Type anything to search',
      accent: AppColors.adminPrimary,
      onChanged: (_) => setState(() {}),
      onClear: () => setState(_search.clear),
    );

    if (filtered.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          searchBar,
          const SizedBox(height: 16),
          const AppCard(child: Text('No equipment flagged for attention.')),
        ],
      );
    }

    final listChildren = filtered
        .map((node) => _mallRow(
              node: node,
              reported: app.reportedEquipmentNodeIds.contains(node.nodeId),
              selected: node.nodeId == selected?.nodeId,
              onTap: () {
                setState(() => _selectedMallNodeId = node.nodeId);
                if (!split) _showMallResult(app, node);
              },
            ))
        .toList();

    if (!split) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [searchBar, const SizedBox(height: 16), ...listChildren],
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          searchBar,
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
                  SizedBox(width: 330, child: ListView(children: listChildren)),
                  const VerticalDivider(width: 1, color: AppColors.divider),
                  Expanded(
                    child: _mallDetailPanel(
                      app: app,
                      node: selected!,
                      reported: app.reportedEquipmentNodeIds
                          .contains(selected.nodeId),
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

  EquipmentNode? _selectedMallNode(List<EquipmentNode> nodes) {
    if (nodes.isEmpty) return null;
    return nodes.firstWhere(
      (n) => n.nodeId == _selectedMallNodeId,
      orElse: () => nodes.first,
    );
  }

  Widget _mallRow({
    required EquipmentNode node,
    required bool reported,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? AppColors.adminSurface : Colors.transparent,
      child: InkWell(
        onTap: onTap,
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(node.nodeName,
                              style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800)),
                        ),
                        reported
                            ? const Pill('Reported',
                                color: AppColors.waterAccent, outlined: true)
                            : severityPill(
                                AppState.equipmentSeverity(node.status)),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${node.facilityName ?? 'Facility not linked'} · ${node.status}',
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

  void _showMallResult(AppState app, EquipmentNode node) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * .78,
            child: _mallDetailPanel(
              app: app,
              node: node,
              reported: app.reportedEquipmentNodeIds.contains(node.nodeId),
            ),
          ),
        ),
      );
    });
  }

  Widget _mallDetailPanel({
    required AppState app,
    required EquipmentNode node,
    required bool reported,
  }) {
    final busyKey = 'M-${node.nodeId}';
    final severity = AppState.equipmentSeverity(node.status);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(node.nodeName,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          severityPill(severity),
          const SizedBox(height: 14),
          Text(
            '${node.facilityName ?? 'Facility not linked'}'
            '${node.facilityCity != null ? ', ${node.facilityCity}' : ''}',
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 18),
          Text(
            'Status: ${node.status}',
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 18),
          _AiPreviewCard(key: ValueKey('mall-${node.nodeId}'), evidence: {
            'alert_type': node.utilityType == 'Water'
                ? 'nrw_hotspot'
                : 'electricity_hotspot',
            'state': node.zoneId,
            'facility_name': node.facilityName,
            'facility_city': node.facilityCity,
            'equipment_name': node.nodeName,
            'severity': severity,
            'explanation': app.explainer.describeEquipmentAnomaly(node),
          }),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: reported
                ? const OutlinedButton(
                    onPressed: null, child: Text('Already reported'))
                : FilledButton.icon(
                    onPressed: _busyKey == busyKey
                        ? null
                        : () => _run(busyKey, node.nodeName,
                            () => app.reportEquipmentAnomaly(node)),
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.adminPrimary),
                    icon: _busyKey == busyKey
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.person_add_alt_1_outlined, size: 18),
                    label: const Text('Send to worker queue'),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _anomalyWorkspace({
    required AppState app,
    required List<NrwResult> results,
    required String Function(NrwResult) unitOf,
    required Set<String> reportedStates,
    required String? selectedState,
    required ValueChanged<String> onSelected,
    required Future<void> Function(NrwResult result) onReport,
    required String Function(NrwResult result) busyKeyFor,
    List<ElectricityRecord> tampering = const [],
    Future<void> Function(ElectricityRecord record)? onReportTampering,
    bool Function(ElectricityRecord record)? isTamperingReported,
  }) {
    final split = usesAbnormalProductionSplitView(MediaQuery.sizeOf(context));
    final query = _search.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? results
        : results.where((r) => r.state.toLowerCase().contains(query)).toList();
    final selected = _selectedResult(filtered, selectedState);
    final searchBar = FilterSearchField(
      controller: _search,
      hint: 'Type anything to search',
      accent: AppColors.adminPrimary,
      onChanged: (_) => setState(() {}),
      onClear: () => setState(_search.clear),
    );

    if (filtered.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [searchBar, const SizedBox(height: 16), _emptyCard()],
      );
    }

    final listChildren = _rankedChildren(
      app: app,
      results: filtered,
      unitOf: unitOf,
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
        children: [searchBar, const SizedBox(height: 16), ...listChildren],
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          searchBar,
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
                      app: app,
                      result: selected!,
                      unit: unitOf(selected),
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

  List<Widget> _rankedChildren({
    required AppState app,
    required List<NrwResult> results,
    required String Function(NrwResult) unitOf,
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
          unit: unitOf(result),
          selected: selectedState == result.state,
          reported: reportedStates.contains(result.state),
          onTap: () => _showResult(
            app,
            result,
            unitOf(result),
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
                        reported
                            ? const Pill('Reported',
                                color: AppColors.waterAccent, outlined: true)
                            : severityPill(result.severity),
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
    AppState app,
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
              app: app,
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
    required AppState app,
    required NrwResult result,
    required String unit,
    required bool reported,
    required String busyKey,
    required VoidCallback onReport,
  }) {
    final severityColorValue = severityColor(result.severity);
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
          severityPill(result.severity),
          const SizedBox(height: 14),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '${result.lossPct.toStringAsFixed(1)}%',
                  style: TextStyle(
                      color: severityColorValue,
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
          const SizedBox(height: 18),
          Builder(builder: (context) {
            final isWater = unit == 'MLD';
            return _AiPreviewCard(
                key: ValueKey('state-${result.state}-$isWater'),
                evidence: {
                  'alert_type': isWater ? 'nrw_hotspot' : 'electricity_hotspot',
                  'state': result.state,
                  'produced_mld': result.producedMld,
                  'billed_mld': result.billedMld,
                  'loss_mld': result.lossMld,
                  'loss_pct': result.lossPct,
                  'severity': result.severity,
                  'explanation': isWater
                      ? app.explainer
                          .describeNrw(result, app.nrw.nationalLossPct)
                      : app.explainer.describeElectricityLoss(
                          result, app.electricityLoss.nationalLossPct),
                });
          }),
          const SizedBox(height: 18),
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

  Widget _emptyCard() => const AppCard(
        child: Text(
          'No abnormal production states detected.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );

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

/// AI's read of a detected anomaly before admin decides whether to forward
/// it — nothing is written anywhere. Distinct from [AiAnalysisCard]: that
/// one reads/writes a persisted Alert row, this one is a throwaway preview
/// over evidence that has no alert_id yet, since the alert doesn't exist
/// until "Send to worker queue" is tapped.
class _AiPreviewCard extends StatefulWidget {
  final Map<String, Object?> evidence;
  // A stable Key (keyed by the result's identity, e.g. state name or node
  // id) is required from every call site. Map doesn't override ==, so a
  // freshly-built evidence literal is never equal to the previous one on
  // rebuild — without a stable key, a naive didUpdateWidget map comparison
  // would treat every parent rebuild as "the evidence changed" and re-fire
  // the Groq call on every rebuild (e.g. every 10s poll tick). The key lets
  // Flutter's own widget identity do this instead: same key across a
  // rebuild reuses this State (no reload); a different key (a genuinely
  // different result selected) tears down and recreates it, running
  // initState fresh exactly once for that result.
  const _AiPreviewCard({required super.key, required this.evidence});

  @override
  State<_AiPreviewCard> createState() => _AiPreviewCardState();
}

class _AiPreviewCardState extends State<_AiPreviewCard> {
  AiAnomalyAnalysis? _analysis;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final analysis =
          await context.read<AppState>().anomalyAi.preview(widget.evidence);
      if (!mounted) return;
      setState(() {
        _analysis = analysis;
        _loading = false;
      });
    } on AnomalyAiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'AI preview is unavailable right now.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      background: AppColors.adminSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('AI PREVIEW', color: AppColors.adminPrimary),
          const SizedBox(height: 10),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Text(_error!,
                style: const TextStyle(color: Colors.deepOrange, height: 1.35))
          else if (_analysis != null) ...[
            Text(_analysis!.summary, style: const TextStyle(height: 1.45)),
            const SizedBox(height: 10),
            Text(_analysis!.recommendation,
                style:
                    const TextStyle(height: 1.45, fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }
}
