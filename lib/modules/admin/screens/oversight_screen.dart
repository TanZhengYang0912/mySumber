import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_tab_bar.dart';
import '../../../theme/filter_controls.dart';
import '../../../theme/responsive_filter_bar.dart';
import '../../../theme/tokens.dart';
import '../../auth/state/auth_state.dart';
import '../../leakage/models/alert.dart';
import '../../leakage/models/report.dart';
import '../../leakage/screens/report_view_screen.dart';
import '../../leakage/screens/style.dart';
import '../../leakage/state/app_state.dart';
import 'admin_alert_detail_screen.dart';
import '../services/admin_tablet_layout.dart';
import '../../../theme/page_header.dart';

enum OversightSection { alerts, reports }

typedef _AlertQueueData = ({
  List<Alert> alerts,
  List<String> states,
  Map<String, int> stateCounts,
  Map<String, int> severityCounts,
  Map<String, int> statusCounts,
  Map<String, int> utilityCounts,
});

class OversightScreen extends StatefulWidget {
  final OversightSection initialSection;
  const OversightScreen(
      {super.key, this.initialSection = OversightSection.alerts});

  @override
  State<OversightScreen> createState() => _OversightScreenState();
}

class _OversightScreenState extends State<OversightScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _outerTab;
  Utility? _alertUtility;
  String? _alertStatus;
  String? _alertState;
  String? _alertSeverity;
  Utility? _reportUtility;
  String? _reportOutcome;
  String? _reportState;
  final _reportSearch = TextEditingController();
  final _alertSearch = TextEditingController();

  @override
  void initState() {
    super.initState();
    _outerTab = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialSection == OversightSection.alerts ? 0 : 1,
    );
    _outerTab.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _outerTab.dispose();
    _reportSearch.dispose();
    _alertSearch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final mode = adminLayoutModeFor(MediaQuery.sizeOf(context));
    final isPhoneLandscape = mode == AdminLayoutMode.phoneLandscape;
    final isAlertsTab = _outerTab.index == 0;
    final pendingCount =
        app.alerts.where((a) => a.status == AlertStatus.pending).length;

    final landscapeFilterBar = isAlertsTab
        ? _alertFilterControls(app, landscape: true)
        : _reportFilterControls(app, landscape: true);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          _header(context,
              action: isPhoneLandscape ? landscapeFilterBar : null),
          AppTabBar(
            controller: _outerTab,
            tabs: [
              (label: 'Alert Queue', count: pendingCount),
              (label: 'Reports', count: app.reports.length),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _outerTab,
              children: [
                _workerAlertQueueTab(app, landscape: isPhoneLandscape),
                _reportsTab(app, landscape: isPhoneLandscape),
              ],
            ),
          ),
        ],
      ),
    );
  }

  ResponsiveFilterBar _reportFilterControls(
    AppState app, {
    required bool landscape,
  }) {
    final states = app.alerts.map((a) => a.state).toSet().toList()..sort();
    final alertById = {
      for (final a in app.alerts)
        if (a.id != null) a.id!: a,
    };
    final query = _reportSearch.text.trim().toLowerCase();
    bool matchesQuery(Report r) {
      if (query.isEmpty) return true;
      final state = alertById[r.alertId]?.state.toLowerCase() ?? '';
      return state.contains(query) ||
          r.findings.toLowerCase().contains(query) ||
          r.actionTaken.toLowerCase().contains(query);
    }

    List<Report> excluding(
        {bool state = true, bool outcome = true, bool utility = true}) {
      return app
          .reportsFiltered(
            state: state ? _reportState : null,
            outcome: outcome ? _reportOutcome : null,
            utility: utility ? _reportUtility : null,
          )
          .where(matchesQuery)
          .toList();
    }

    final utilityCounts = countBy(
        excluding(utility: false),
        (r) => alertById[r.alertId]?.utility == Utility.electricity
            ? 'electricity'
            : 'water');

    return ResponsiveFilterBar(
      mode: landscape
          ? ResponsiveFilterBarMode.menu
          : ResponsiveFilterBarMode.inline,
      searchController: _reportSearch,
      onSearchChanged: (_) => setState(() {}),
      activeFilterCount: countActiveFilters(
        query: _reportSearch.text,
        filters: [
          _reportState != null,
          _reportOutcome != null,
          _reportUtility != null,
        ],
      ),
      menuTooltip: 'Filter reports',
      filters: [
        FilterDropdown(
          caption: 'State',
          value: _reportState,
          allLabel: 'All',
          options: states,
          counts: countBy(excluding(state: false),
              (r) => alertById[r.alertId]?.state ?? ''),
          onChanged: (value) => setState(() => _reportState = value),
        ),
        FilterDropdown(
          caption: 'Outcome',
          value: _reportOutcome,
          allLabel: 'All',
          options: const [ReportOutcome.fixed, ReportOutcome.notFixed],
          labelFor: ReportOutcome.label,
          counts: countBy(excluding(outcome: false), (r) => r.outcome),
          onChanged: (value) => setState(() => _reportOutcome = value),
        ),
        UtilityFilterDropdown(
          value: _reportUtility,
          counts: utilityCounts,
          onChanged: (value) => setState(() => _reportUtility = value),
        ),
      ],
    );
  }

  Widget _header(BuildContext context, {Widget? action}) {
    return PageHeader(
      title: 'Oversight',
      icon: Icons.shield_outlined,
      action: action,
      onLogout: () => context.read<RoleState>().logout(),
    );
  }

  static const _queueStatuses = [
    AlertStatus.pending,
    AlertStatus.investigating,
    AlertStatus.notFixed,
    AlertStatus.resolved,
  ];

  _AlertQueueData _alertQueueData(AppState app) {
    final states = app.alerts.map((a) => a.state).toSet().toList()..sort();
    final scoped = app
        .alertsFiltered(utility: _alertUtility)
        .where((a) => a.status != AlertStatus.pendingReview)
        .toList();

    final query = _alertSearch.text.trim().toLowerCase();
    bool matchesQuery(Alert a) =>
        query.isEmpty ||
        a.state.toLowerCase().contains(query) ||
        a.title.toLowerCase().contains(query);

    // Each filter's counts reflect every OTHER active filter but not its own
    // selection, so picking "High" doesn't collapse Severity's own list.
    List<Alert> excluding(
        {bool state = true, bool severity = true, bool status = true}) {
      return scoped.where((a) {
        if (!matchesQuery(a)) return false;
        if (state && _alertState != null && a.state != _alertState) {
          return false;
        }
        if (severity &&
            _alertSeverity != null &&
            a.severity != _alertSeverity) {
          return false;
        }
        if (status && _alertStatus != null && a.status != _alertStatus) {
          return false;
        }
        return true;
      }).toList();
    }

    return (
      alerts: excluding(),
      states: states,
      stateCounts: countBy(excluding(state: false), (a) => a.state),
      severityCounts: countBy(excluding(severity: false), (a) => a.severity),
      statusCounts: countBy(excluding(status: false), (a) => a.status),
      utilityCounts: countBy(
          app
              .alertsFiltered(
                  state: _alertState,
                  status: _alertStatus,
                  severity: _alertSeverity)
              .where(matchesQuery),
          (a) => a.utility == Utility.electricity ? 'electricity' : 'water'),
    );
  }

  ResponsiveFilterBar _alertFilterControls(
    AppState app, {
    required bool landscape,
  }) {
    final data = _alertQueueData(app);

    return ResponsiveFilterBar(
      mode: landscape
          ? ResponsiveFilterBarMode.menu
          : ResponsiveFilterBarMode.inline,
      searchController: _alertSearch,
      onSearchChanged: (_) => setState(() {}),
      activeFilterCount: countActiveFilters(
        query: _alertSearch.text,
        filters: [
          _alertState != null,
          _alertSeverity != null,
          _alertStatus != null,
          _alertUtility != null,
        ],
      ),
      menuTooltip: 'Filter alerts',
      filters: [
        FilterDropdown(
          caption: 'State',
          value: _alertState,
          allLabel: 'All',
          options: data.states,
          counts: data.stateCounts,
          onChanged: (value) => setState(() => _alertState = value),
        ),
        FilterDropdown(
          caption: 'Severity',
          value: _alertSeverity,
          allLabel: 'All',
          options: const [Severity.high, Severity.medium, Severity.low],
          labelFor: Severity.label,
          counts: data.severityCounts,
          onChanged: (value) => setState(() => _alertSeverity = value),
        ),
        FilterDropdown(
          caption: 'Status',
          value: _alertStatus,
          allLabel: 'All',
          options: _queueStatuses,
          labelFor: AlertStatus.label,
          counts: data.statusCounts,
          onChanged: (value) => setState(() => _alertStatus = value),
        ),
        UtilityFilterDropdown(
          value: _alertUtility,
          counts: data.utilityCounts,
          onChanged: (value) => setState(() => _alertUtility = value),
        ),
      ],
    );
  }

  Widget _workerAlertQueueTab(AppState app, {required bool landscape}) {
    final alerts = _alertQueueData(app).alerts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!landscape) _alertFilterControls(app, landscape: false),
        const SizedBox(height: 14),
        Expanded(
          child: alerts.isEmpty
              ? const FilterEmptyState('No alerts match these filters.')
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  itemCount: alerts.length,
                  itemBuilder: (context, index) {
                    final alert = alerts[index];
                    return AlertCard(
                      alert: alert,
                      utility: alert.utility,
                      resolvedAt: alert.id == null
                          ? null
                          : app.resolvedAtFor(alert.id!),
                      resolvedHandledBy:
                          app.workerNames[alert.handledById] ?? alert.handledBy,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) =>
                              AdminAlertDetailScreen(alertId: alert.id!))),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // --- Reports tab ---

  Widget _reportsTab(AppState app, {required bool landscape}) {
    final alertById = {
      for (final a in app.alerts)
        if (a.id != null) a.id!: a,
    };
    final query = _reportSearch.text.trim().toLowerCase();
    bool matchesQuery(Report r) {
      if (query.isEmpty) return true;
      final state = alertById[r.alertId]?.state.toLowerCase() ?? '';
      return state.contains(query) ||
          r.findings.toLowerCase().contains(query) ||
          r.actionTaken.toLowerCase().contains(query);
    }

    // Each filter's counts reflect every OTHER active filter but not its own
    // selection, so picking "Fixed" doesn't collapse Outcome's own list.
    List<Report> excluding(
        {bool state = true, bool outcome = true, bool utility = true}) {
      return app
          .reportsFiltered(
            state: state ? _reportState : null,
            outcome: outcome ? _reportOutcome : null,
            utility: utility ? _reportUtility : null,
          )
          .where(matchesQuery)
          .toList();
    }

    final reports = excluding();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!landscape) _reportFilterControls(app, landscape: false),
        const SizedBox(height: 14),
        Expanded(
          child: reports.isEmpty
              ? const FilterEmptyState('No reports match these filters.')
              : ListView.builder(
                  padding: landscape
                      ? const EdgeInsets.fromLTRB(16, 0, 16, 12)
                      : const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  itemCount: reports.length,
                  itemBuilder: (context, index) {
                    final report = reports[index];
                    final alert = alertById[report.alertId];
                    return ReportCard(
                      report: report,
                      locationLabel: alert?.title ?? 'Alert #${report.alertId}',
                      utility: alert?.utility,
                      resolvedWorkerName:
                          app.workerNames[report.workerId] ?? report.workerName,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => ReportViewScreen(
                              report: report,
                              barColor: AppColors.adminPrimary))),
                    );
                  },
                ),
        ),
      ],
    );
  }

}
