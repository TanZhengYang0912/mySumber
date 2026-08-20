import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/filter_controls.dart';
import '../../../theme/tokens.dart';
import '../../auth/state/auth_state.dart';
import '../../leakage/models/alert.dart';
import '../../leakage/screens/network_error.dart';
import '../../leakage/screens/style.dart';
import '../../leakage/state/app_state.dart';
import '../services/abnormal_production_filter.dart';
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
  int? _selectedStateAlertId;
  int? _selectedMallAlertId;
  Utility? _stateUtility;
  Utility? _mallUtility;
  String? _anomalyState;
  String? _anomalySeverity;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this)..addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _clearAnomalyFilters() {
    setState(() {
      _search.clear();
      _anomalyState = null;
      _anomalySeverity = null;
      _stateUtility = null;
      _mallUtility = null;
    });
  }

  Widget _anomalyFilterBar({
    required List<String> states,
    required Map<String, int> stateCounts,
    required Map<String, int> severityCounts,
    required Utility? utility,
    required ValueChanged<Utility?> onUtilityChanged,
  }) {
    return Column(
      children: [
        // Status arguments are omitted deliberately: AlertFilterBar hides the
        // dropdown when statusOptions is null, and every row in this queue is
        // pending review, so Reported/Unreported no longer means anything.
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

  Future<void> _decide(AppState app, int alertId,
      {required bool approve}) async {
    try {
      if (approve) {
        await app.approveAlert(alertId);
      } else {
        await app.rejectAlert(alertId);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(approve
            ? 'Approved — sent to the worker queue.'
            : 'Faulted — kept in Anomalies for the record.'),
        backgroundColor: approve ? AppColors.adminPrimary : Colors.blueGrey,
      ));
    } catch (_) {
      if (mounted) showNetworkErrorSnackBar(context);
    }
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

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          _buildHeader(context),
          _buildTabBar(stateAlerts.length, mallAlerts.length),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _stateTab(app, stateAlerts),
                _mallTab(app, mallAlerts),
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

  Widget _stateTab(AppState app, List<Alert> alerts) => _reviewWorkspace(
        app,
        alerts,
        selectedId: _selectedStateAlertId,
        onSelected: (id) => setState(() => _selectedStateAlertId = id),
        utility: _stateUtility,
        onUtilityChanged: (u) => setState(() => _stateUtility = u),
      );

  Widget _mallTab(AppState app, List<Alert> alerts) => _reviewWorkspace(
        app,
        alerts,
        selectedId: _selectedMallAlertId,
        onSelected: (id) => setState(() => _selectedMallAlertId = id),
        utility: _mallUtility,
        onUtilityChanged: (u) => setState(() => _mallUtility = u),
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
    AppState app,
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
    final filtered = alerts
        .where((a) => ReviewQueueFilter.matches(
              query: _search.text,
              alert: a,
              selectedState: _anomalyState,
              selectedSeverity: _anomalySeverity,
            ))
        .toList();
    final selected = _selectedAlert(filtered, selectedId);
    final filterBar = _anomalyFilterBar(
      states: states,
      stateCounts: stateCounts,
      severityCounts: severityCounts,
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AlertCard(
              alert: alert,
              onTap: () {
                if (alert.id != null) onSelected(alert.id!);
              },
            ),
            _statusStrip(alert),
          ],
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AlertCard(
                  alert: alert,
                  onTap: () {
                    if (alert.id != null) onSelected(alert.id!);
                  },
                ),
                _statusStrip(alert),
              ],
            ),
            if (alert.id == selected?.id) ...[
              const SizedBox(height: 10),
              _reviewDetailPanel(app, alert),
            ],
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
                      : _reviewDetailPanel(app, selected),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _reviewDetailPanel(AppState app, Alert alert) {
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
          if (AppState.awaitingDecision(alert))
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: alert.id == null
                      ? null
                      : () => _decide(app, alert.id!, approve: false),
                  child: const Text('Fault'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: alert.id == null
                      ? null
                      : () => _decide(app, alert.id!, approve: true),
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.adminPrimary),
                  child: const Text('Approve to Worker queue'),
                ),
              ),
            ])
          else
            Align(
              alignment: Alignment.centerLeft,
              child: Pill(AlertStatus.label(alert.status),
                  color: statusColor(alert.status), outlined: true),
            ),
        ],
      ),
    );
  }

  Widget _statusStrip(Alert alert) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Pill(AlertStatus.label(alert.status),
              color: statusColor(alert.status), outlined: true),
        ),
      );

  Widget _emptyCard() => const AppCard(
        child: Text(
          'No anomalies awaiting review.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
}
