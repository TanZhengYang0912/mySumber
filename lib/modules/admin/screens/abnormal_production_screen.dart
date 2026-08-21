import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/filter_controls.dart';
import '../../../theme/tokens.dart';
import '../../auth/state/auth_state.dart';
import '../../leakage/models/alert.dart';
import '../../leakage/screens/style.dart';
import '../../leakage/state/app_state.dart';
import '../services/abnormal_production_filter.dart';
import '../services/abnormal_production_layout.dart';
import 'admin_alert_detail_screen.dart';
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
  int? _selectedStateAlertId;
  int? _selectedMallAlertId;
  int? _selectedHouseholdAlertId;
  Utility? _stateUtility;
  Utility? _mallUtility;
  Utility? _householdUtility;
  String? _anomalyState;
  String? _anomalySeverity;
  String? _anomalyStatus;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this)..addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _clearAnomalyFilters() {
    setState(() {
      _search.clear();
      _anomalyState = null;
      _anomalySeverity = null;
      _anomalyStatus = null;
      _stateUtility = null;
      _mallUtility = null;
      _householdUtility = null;
    });
  }

  /// Tablet split view selects the row in place; a phone opens the same
  /// pushed detail page Oversight uses, so both admin surfaces behave alike.
  void _openAlert(
    Alert alert, {
    required bool split,
    required ValueChanged<int> onSelected,
  }) {
    final id = alert.id;
    if (id == null) return;
    if (split) {
      onSelected(id);
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AdminAlertDetailScreen(alertId: id),
    ));
  }

  Widget _anomalyFilterBar({
    required List<String> states,
    required Map<String, int> stateCounts,
    required Map<String, int> severityCounts,
    required Map<String, int> statusCounts,
    required Utility? utility,
    required ValueChanged<Utility?> onUtilityChanged,
  }) {
    return Column(
      children: [
        AlertFilterBar(
          searchController: _search,
          onSearchChanged: (_) => setState(() {}),
          onSearchClear: () => setState(_search.clear),
          selectedState: _anomalyState,
          states: states,
          stateCounts: stateCounts,
          onStateChanged: (value) => setState(() => _anomalyState = value),
          selectedSeverity: _anomalySeverity,
          severityCounts: severityCounts,
          onSeverityChanged: (value) =>
              setState(() => _anomalySeverity = value),
          // Only two statuses can reach this queue, and both stay listed even
          // at a count of zero so the option set does not shift as rows are
          // decided. Mirrors how Oversight passes a const queueStatuses list.
          selectedStatus: _anomalyStatus,
          statusOptions: const [AlertStatus.pendingReview, AlertStatus.faults],
          statusCounts: statusCounts,
          onStatusChanged: (value) => setState(() => _anomalyStatus = value),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: UtilityChips(selected: utility, onChanged: onUtilityChanged),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _clearAnomalyFilters,
            child: const Text('Clear filters'),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _tab
      ..removeListener(_refresh)
      ..dispose();
    _search.dispose();
    super.dispose();
  }

  List<Alert> _narrow(List<Alert> source, Utility? utility) => utility == null
      ? source
      : source.where((a) => a.utility == utility).toList();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (app.loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final stateAlerts = _narrow(
        app.reviewQueue(sourceScope: AlertSourceScope.state), _stateUtility);
    final mallAlerts = _narrow(
        app.reviewQueue(sourceScope: AlertSourceScope.mall), _mallUtility);
    // Customer-submitted reports land here as pending_review alerts too, so
    // they need their own tab — without one they are raised, analysed, and
    // then invisible to everybody.
    final householdAlerts = _narrow(
        app.reviewQueue(sourceScope: AlertSourceScope.household),
        _householdUtility);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          _buildHeader(context),
          _buildTabBar(
              stateAlerts.length, mallAlerts.length, householdAlerts.length),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _stateTab(stateAlerts),
                _mallTab(mallAlerts),
                _householdTab(householdAlerts),
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

  Widget _buildTabBar(int stateCount, int mallCount, int householdCount) {
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
          _countedTab('State', stateCount),
          _countedTab('Mall', mallCount),
          _countedTab('Household', householdCount),
        ],
      ),
    );
  }

  /// FittedBox keeps three labels legible on a phone, where "Household" plus
  /// its badge would otherwise overflow the tab width.
  Widget _countedTab(String label, int count) => Tab(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label),
              const SizedBox(width: 6),
              CountBadge(count),
            ],
          ),
        ),
      );

  Widget _stateTab(List<Alert> alerts) => _reviewWorkspace(
        alerts,
        selectedId: _selectedStateAlertId,
        onSelected: (id) => setState(() => _selectedStateAlertId = id),
        utility: _stateUtility,
        onUtilityChanged: (u) => setState(() => _stateUtility = u),
      );

  Widget _mallTab(List<Alert> alerts) => _reviewWorkspace(
        alerts,
        selectedId: _selectedMallAlertId,
        onSelected: (id) => setState(() => _selectedMallAlertId = id),
        utility: _mallUtility,
        onUtilityChanged: (u) => setState(() => _mallUtility = u),
      );

  Widget _householdTab(List<Alert> alerts) => _reviewWorkspace(
        alerts,
        selectedId: _selectedHouseholdAlertId,
        onSelected: (id) => setState(() => _selectedHouseholdAlertId = id),
        utility: _householdUtility,
        onUtilityChanged: (u) => setState(() => _householdUtility = u),
      );

  /// The row whose detail panel is open. Falls back to the first row so the
  /// split view is never blank, and self-heals when the selected alert leaves
  /// the queue (approved, rejected, or filtered out).
  Alert? _selectedAlert(List<Alert> filtered, int? selectedId) {
    if (filtered.isEmpty) return null;
    return filtered.firstWhere((a) => a.id == selectedId,
        orElse: () => filtered.first);
  }

  Widget _reviewWorkspace(
    List<Alert> alerts, {
    required int? selectedId,
    required ValueChanged<int> onSelected,
    required Utility? utility,
    required ValueChanged<Utility?> onUtilityChanged,
  }) {
    final split = usesAbnormalProductionSplitView(MediaQuery.sizeOf(context));
    final states = alerts.map((a) => a.state).toSet().toList()..sort();
    final stateCounts = countBy(alerts, (a) => a.state);
    final severityCounts = countBy(alerts, (a) => a.severity);
    final statusCounts = countBy(alerts, (a) => a.status);
    final filtered = alerts
        .where((a) => ReviewQueueFilter.matches(
              query: _search.text,
              alert: a,
              selectedState: _anomalyState,
              selectedSeverity: _anomalySeverity,
              selectedStatus: _anomalyStatus,
            ))
        .toList();
    final selected = _selectedAlert(filtered, selectedId);
    final filterBar = _anomalyFilterBar(
      states: states,
      stateCounts: stateCounts,
      severityCounts: severityCounts,
      statusCounts: statusCounts,
      utility: utility,
      onUtilityChanged: onUtilityChanged,
    );

    if (filtered.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [filterBar, const SizedBox(height: 12), _emptyCard()],
      );
    }

    final list = ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final alert = filtered[index];
        return AlertCard(
          alert: alert,
          onTap: () => _openAlert(alert, split: split, onSelected: onSelected),
        );
      },
    );

    if (!split) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          filterBar,
          const SizedBox(height: 12),
          for (final alert in filtered) ...[
            AlertCard(
              alert: alert,
              onTap: () =>
                  _openAlert(alert, split: split, onSelected: onSelected),
            ),
            const SizedBox(height: 10),
          ],
        ],
      );
    }

    return Column(
      children: [
        Padding(padding: const EdgeInsets.all(16), child: filterBar),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: list),
              Expanded(
                flex: 4,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: selected == null
                      ? _emptyCard()
                      : _reviewDetailPanel(selected),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _reviewDetailPanel(Alert alert) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(alert.title,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            severityPill(alert.severity),
            utilityPill(alert.utility),
            Pill(alert.sourceLabel,
                color: AppColors.adminPrimary, outlined: true),
          ]),
          const SizedBox(height: 10),
          Text(alert.explanation,
              style: const TextStyle(
                  color: AppColors.textSecondary, height: 1.35)),
          const SizedBox(height: 12),
          // Every alert in this list already has its AI saved, so the card
          // always has content to show — no generate button needed here.
          AiAnalysisCard(alert: alert, canGenerate: false),
          const SizedBox(height: 14),
          AlertDecisionBar(alert: alert),
          if (!AppState.awaitingDecision(alert))
            Align(
              alignment: Alignment.centerLeft,
              child: Pill(AlertStatus.label(alert.status),
                  color: statusColor(alert.status), outlined: true),
            ),
        ],
      ),
    );
  }

  Widget _emptyCard() => const AppCard(
        child: Text(
          'No anomalies awaiting review.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
}
