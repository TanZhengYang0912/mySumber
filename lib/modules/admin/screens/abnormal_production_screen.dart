import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_tab_bar.dart';
import '../../../theme/filter_controls.dart';
import '../../../theme/responsive_filter_bar.dart';
import '../../../theme/tokens.dart';
import '../../auth/state/auth_state.dart';
import '../../leakage/models/alert.dart';
import '../../leakage/screens/style.dart';
import '../../leakage/state/app_state.dart';
import '../services/abnormal_production_filter.dart';
import '../services/abnormal_production_layout.dart';
import '../services/admin_tablet_layout.dart';
import 'admin_alert_detail_screen.dart';
import '../../../theme/page_header.dart';

class AbnormalProductionScreen extends StatefulWidget {
  const AbnormalProductionScreen({super.key});

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

  ResponsiveFilterBar _anomalyFilterBar({
    required bool landscape,
    required List<String> states,
    required Map<String, int> stateCounts,
    required Map<String, int> severityCounts,
    required Map<String, int> statusCounts,
    required Utility? utility,
    required ValueChanged<Utility?> onUtilityChanged,
  }) {
    return ResponsiveFilterBar(
      mode: landscape
          ? ResponsiveFilterBarMode.menu
          : ResponsiveFilterBarMode.inline,
      searchController: _search,
      onSearchChanged: (_) => setState(() {}),
      activeFilterCount: countActiveFilters(
        query: _search.text,
        filters: [
          _anomalyState != null,
          _anomalySeverity != null,
          _anomalyStatus != null,
          utility != null,
        ],
      ),
      menuTooltip: 'Filter anomalies',
      filters: [
        FilterDropdown(
          caption: 'State',
          value: _anomalyState,
          allLabel: 'All',
          options: states,
          counts: stateCounts,
          onChanged: (value) => setState(() => _anomalyState = value),
        ),
        FilterDropdown(
          caption: 'Severity',
          value: _anomalySeverity,
          allLabel: 'All',
          options: const [Severity.high, Severity.medium, Severity.low],
          labelFor: Severity.label,
          counts: severityCounts,
          onChanged: (value) => setState(() => _anomalySeverity = value),
        ),
        FilterDropdown(
          caption: 'Status',
          value: _anomalyStatus,
          allLabel: 'All',
          options: const [AlertStatus.pendingReview, AlertStatus.faults],
          labelFor: AlertStatus.label,
          counts: statusCounts,
          onChanged: (value) => setState(() => _anomalyStatus = value),
        ),
        UtilityFilterDropdown(
          value: utility,
          onChanged: onUtilityChanged,
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
    final landscape = usesAdminCompactHeader(MediaQuery.sizeOf(context));
    final activeAlerts = _tab.index == 0
        ? stateAlerts
        : _tab.index == 1
            ? mallAlerts
            : householdAlerts;
    final activeUtility = _tab.index == 0
        ? _stateUtility
        : _tab.index == 1
            ? _mallUtility
            : _householdUtility;
    final onActiveUtilityChanged = _tab.index == 0
        ? (Utility? utility) => setState(() => _stateUtility = utility)
        : _tab.index == 1
            ? (Utility? utility) => setState(() => _mallUtility = utility)
            : (Utility? utility) => setState(() => _householdUtility = utility);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          _buildHeader(
            context,
            landscape: landscape,
            alerts: activeAlerts,
            utility: activeUtility,
            onUtilityChanged: onActiveUtilityChanged,
          ),
          AppTabBar(
            controller: _tab,
            tabs: [
              (label: 'State', count: stateAlerts.length),
              (label: 'Mall', count: mallAlerts.length),
              (label: 'Household', count: householdAlerts.length),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _stateTab(stateAlerts, landscape),
                _mallTab(mallAlerts, landscape),
                _householdTab(householdAlerts, landscape),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context, {
    required bool landscape,
    required List<Alert> alerts,
    required Utility? utility,
    required ValueChanged<Utility?> onUtilityChanged,
  }) {
    final states = alerts.map((a) => a.state).toSet().toList()..sort();
    final stateCounts = countBy(alerts, (a) => a.state);
    final severityCounts = countBy(alerts, (a) => a.severity);
    final statusCounts = countBy(alerts, (a) => a.status);
    return PageHeader(
      title: 'Anomalies',
      icon: Icons.notifications_outlined,
      onLogout: () => context.read<RoleState>().logout(),
      action: landscape
          ? _anomalyFilterBar(
              landscape: true,
              states: states,
              stateCounts: stateCounts,
              severityCounts: severityCounts,
              statusCounts: statusCounts,
              utility: utility,
              onUtilityChanged: onUtilityChanged,
            )
          : null,
    );
  }

  Widget _stateTab(List<Alert> alerts, bool landscape) => _reviewWorkspace(
        alerts,
        selectedId: _selectedStateAlertId,
        onSelected: (id) => setState(() => _selectedStateAlertId = id),
        utility: _stateUtility,
        onUtilityChanged: (u) => setState(() => _stateUtility = u),
        landscape: landscape,
      );

  Widget _mallTab(List<Alert> alerts, bool landscape) => _reviewWorkspace(
        alerts,
        selectedId: _selectedMallAlertId,
        onSelected: (id) => setState(() => _selectedMallAlertId = id),
        utility: _mallUtility,
        onUtilityChanged: (u) => setState(() => _mallUtility = u),
        landscape: landscape,
      );

  Widget _householdTab(List<Alert> alerts, bool landscape) => _reviewWorkspace(
        alerts,
        selectedId: _selectedHouseholdAlertId,
        onSelected: (id) => setState(() => _selectedHouseholdAlertId = id),
        utility: _householdUtility,
        onUtilityChanged: (u) => setState(() => _householdUtility = u),
        landscape: landscape,
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
    required bool landscape,
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
      landscape: false,
      states: states,
      stateCounts: stateCounts,
      severityCounts: severityCounts,
      statusCounts: statusCounts,
      utility: utility,
      onUtilityChanged: onUtilityChanged,
    );

    if (filtered.isEmpty) {
      return Column(
        children: [
          if (!landscape) filterBar,
          const Expanded(
            child: FilterEmptyState('No anomalies awaiting review.'),
          ),
        ],
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
      return Column(
        children: [
          if (!landscape) filterBar,
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final alert in filtered) ...[
                  AlertCard(
                    alert: alert,
                    onTap: () =>
                        _openAlert(alert, split: split, onSelected: onSelected),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        filterBar,
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
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child:
                              FilterEmptyState('No anomalies awaiting review.'),
                        )
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

}
