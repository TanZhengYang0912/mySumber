import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/filter_controls.dart';
import '../../../theme/tokens.dart';
import '../../auth/state/auth_state.dart';
import '../../leakage/models/alert.dart';
import '../../leakage/models/report.dart';
import '../../leakage/screens/report_view_screen.dart';
import '../../leakage/screens/style.dart';
import '../../leakage/state/app_state.dart';
import 'abnormal_production_screen.dart';
import 'admin_alert_detail_screen.dart';
import '../services/admin_tablet_layout.dart';
import '../services/anomaly_review_filter.dart';
import '../../../theme/landscape_filter_menu.dart';
import '../../../theme/page_header.dart';
import '../widgets/oversight_landscape_workspace.dart';

enum OversightSection { alerts, reports }

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
  Set<String> _landscapeStatuses = {AlertStatus.pending};
  Utility? _landscapeUtility;
  bool _landscapeHighSeverityOnly = false;
  final _landscapeAlertController = ScrollController();
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
    _landscapeAlertController.dispose();
    _reportSearch.dispose();
    _alertSearch.dispose();
    super.dispose();
  }

  AnomalyReviewQuery _oversightAlertQuery() => AnomalyReviewQuery(
        statuses: _landscapeStatuses,
        utility: _landscapeUtility,
        highSeverityOnly: _landscapeHighSeverityOnly,
      );

  int get _activeLandscapeFilterCount {
    var count = 0;
    if (!_landscapeStatuses.contains(AlertStatus.pending) ||
        _landscapeStatuses.length != 1) {
      count++;
    }
    if (_landscapeUtility != null) count++;
    if (_landscapeHighSeverityOnly) count++;
    return count;
  }

  void _clearLandscapeAlertFilters() {
    setState(() {
      _landscapeStatuses = {AlertStatus.pending};
      _landscapeUtility = null;
      _landscapeHighSeverityOnly = false;
    });
  }

  void _clearAlertFilters() {
    setState(() {
      _alertSearch.clear();
      _alertState = null;
      _alertSeverity = null;
      _alertStatus = null;
      _alertUtility = null;
    });
  }

  void _clearReportFilters() {
    setState(() {
      _reportSearch.clear();
      _reportState = null;
      _reportOutcome = null;
      _reportUtility = null;
    });
  }

  int get _activeLandscapeReportFilterCount {
    var count = 0;
    if (_reportState != null) count++;
    if (_reportUtility != null) count++;
    if (_reportOutcome != null) count++;
    return count;
  }

  void _clearLandscapeReportFilters() {
    setState(() {
      _reportState = null;
      _reportUtility = null;
      _reportOutcome = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final mode = adminLayoutModeFor(MediaQuery.sizeOf(context));
    final isPhoneLandscape = mode == AdminLayoutMode.phoneLandscape;
    final isAlertsTab = _outerTab.index == 0;
    final pendingCount =
        app.alerts.where((a) => a.status == AlertStatus.pending).length;

    if (isPhoneLandscape) {
      final landscapeAlerts =
          AnomalyReviewFilter.apply(app.alerts, _oversightAlertQuery());
      final landscapeFilterMenu = isAlertsTab
          ? LandscapeFilterMenu(
              compact: true,
              activeCount: _activeLandscapeFilterCount,
              footer: TextButton(
                onPressed: _clearLandscapeAlertFilters,
                child: const Text('Clear'),
              ),
              child: _landscapeFilterControls(),
            )
          : LandscapeFilterMenu(
              compact: true,
              tooltip: 'Filter reports',
              activeCount: _activeLandscapeReportFilterCount,
              footer: TextButton(
                onPressed: _clearLandscapeReportFilters,
                child: const Text('Clear'),
              ),
              child: _landscapeReportFilterControls(app.alerts),
            );
      return Scaffold(
        backgroundColor: AppColors.canvas,
        body: OversightLandscapeWorkspace(
          sectionIndex: _outerTab.index,
          pendingCount: pendingCount,
          queueLabel: _landscapeQueueLabel(),
          alerts: landscapeAlerts,
          alertController: _landscapeAlertController,
          filterMenu: landscapeFilterMenu,
          onSectionChanged: (index) => setState(() => _outerTab.index = index),
          onAlertTap: (alert) {
            if (alert.id == null) return;
            Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => AdminAlertDetailScreen(alertId: alert.id!)));
          },
          onClearFilters: _clearLandscapeAlertFilters,
          onLogout: () => context.read<RoleState>().logout(),
          onReportState: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const AbnormalProductionScreen(
                showBackToOversight: true,
              ),
            ),
          ),
          reportsBody: _reportsTab(app, compact: true),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          _header(context),
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _outerTab,
              labelColor: AppColors.adminPrimary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.adminPrimary,
              indicatorWeight: 3,
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              tabs: [
                Tab(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Alert Queue'),
                        const SizedBox(width: 6),
                        CountBadge(pendingCount),
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
                        const Text('Reports'),
                        const SizedBox(width: 6),
                        CountBadge(app.reports.length),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _outerTab,
              children: [
                _workerAlertQueueTab(app),
                _reportsTab(app),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _landscapeQueueLabel() {
    if (_landscapeStatuses.length == 1 &&
        _landscapeStatuses.contains(AlertStatus.pending)) {
      return 'Pending alerts';
    }
    if (_landscapeStatuses.length == 1 &&
        _landscapeStatuses.contains(AlertStatus.resolved)) {
      return 'Resolved alerts';
    }
    return 'Filtered alerts';
  }

  Widget _landscapeFilterControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: SectionLabel('Filter anomalies')),
          ],
        ),
        const SizedBox(height: 8),
        const Text('Status', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _landscapeStatusChip('Pending', {AlertStatus.pending}),
            _landscapeStatusChip('Investigating', {AlertStatus.investigating}),
            _landscapeStatusChip('Not Fixed', {AlertStatus.notFixed}),
            _landscapeStatusChip('Resolved', {AlertStatus.resolved}),
          ],
        ),
        const SizedBox(height: 12),
        const Text('Utility', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('All utilities'),
              selected: _landscapeUtility == null,
              onSelected: (_) => setState(() => _landscapeUtility = null),
            ),
            ChoiceChip(
              label: const Text('Water'),
              selected: _landscapeUtility == Utility.water,
              onSelected: (_) =>
                  setState(() => _landscapeUtility = Utility.water),
            ),
            ChoiceChip(
              label: const Text('Electricity'),
              selected: _landscapeUtility == Utility.electricity,
              onSelected: (_) =>
                  setState(() => _landscapeUtility = Utility.electricity),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FilterChip(
          label: const Text('High severity'),
          selected: _landscapeHighSeverityOnly,
          selectedColor: AppColors.criticalSurface,
          checkmarkColor: AppColors.critical,
          labelStyle: TextStyle(
            color: _landscapeHighSeverityOnly
                ? AppColors.critical
                : AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
          onSelected: (selected) =>
              setState(() => _landscapeHighSeverityOnly = selected),
        ),
      ],
    );
  }

  Widget _landscapeReportFilterControls(List<Alert> alerts) {
    final states = alerts.map((alert) => alert.state).toSet().toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: SectionLabel('Filter reports')),
          ],
        ),
        const SizedBox(height: 8),
        _dropdown(
          value: _reportState,
          hint: 'All States',
          items: [
            const DropdownMenuItem(value: null, child: Text('All States')),
            ...states.map((state) => DropdownMenuItem(
                  value: state,
                  child: Text(state),
                )),
          ],
          onChanged: (value) => setState(() => _reportState = value),
        ),
        const SizedBox(height: 8),
        _dropdown(
          value: _reportUtility?.name,
          hint: 'All Types',
          items: const [
            DropdownMenuItem(value: null, child: Text('All Types')),
            DropdownMenuItem(value: 'water', child: Text('Water')),
            DropdownMenuItem(value: 'electricity', child: Text('Electricity')),
          ],
          onChanged: (value) => setState(() {
            _reportUtility = value == null
                ? null
                : Utility.values.firstWhere((utility) => utility.name == value);
          }),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _outcomeToggle(
                'All',
                _reportOutcome == null,
                () => setState(() => _reportOutcome = null),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _outcomeToggle(
                'Fixed',
                _reportOutcome == ReportOutcome.fixed,
                () => setState(() => _reportOutcome = ReportOutcome.fixed),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _outcomeToggle(
                'Not Fixed',
                _reportOutcome == ReportOutcome.notFixed,
                () => setState(() => _reportOutcome = ReportOutcome.notFixed),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _landscapeStatusChip(String label, Set<String> statuses) {
    final selected = _sameStatuses(_landscapeStatuses, statuses);
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _landscapeStatuses = {...statuses}),
    );
  }

  bool _sameStatuses(Set<String> left, Set<String> right) =>
      left.length == right.length && left.containsAll(right);

  Widget _header(BuildContext context) {
    return PageHeader(
      title: 'Oversight',
      icon: Icons.shield_outlined,
      onLogout: () => context.read<RoleState>().logout(),
    );
  }

  Widget _workerAlertQueueTab(AppState app) {
    const queueStatuses = [
      AlertStatus.pending,
      AlertStatus.investigating,
      AlertStatus.notFixed,
      AlertStatus.resolved,
    ];

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

    final alerts = excluding();
    final stateCounts = countBy(excluding(state: false), (a) => a.state);
    final severityCounts =
        countBy(excluding(severity: false), (a) => a.severity);
    final statusCounts = countBy(excluding(status: false), (a) => a.status);
    final utilityCounts = countBy(
        app
            .alertsFiltered(
                state: _alertState,
                status: _alertStatus,
                severity: _alertSeverity)
            .where(matchesQuery),
        (a) => a.utility == Utility.electricity ? 'electricity' : 'water');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: AlertFilterBar(
            searchController: _alertSearch,
            onSearchChanged: (_) => setState(() {}),
            selectedState: _alertState,
            states: states,
            stateCounts: stateCounts,
            onStateChanged: (v) => setState(() => _alertState = v),
            selectedSeverity: _alertSeverity,
            severityCounts: severityCounts,
            onSeverityChanged: (v) => setState(() => _alertSeverity = v),
            selectedStatus: _alertStatus,
            statusOptions: queueStatuses,
            statusCounts: statusCounts,
            onStatusChanged: (v) => setState(() => _alertStatus = v),
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: UtilityChips(
            selected: _alertUtility,
            allCount: utilityCounts.values.fold<int>(0, (a, b) => a + b),
            waterCount: utilityCounts['water'] ?? 0,
            electricityCount: utilityCounts['electricity'] ?? 0,
            onChanged: (u) => setState(() => _alertUtility = u),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _clearAlertFilters,
            child: const Text('Clear filters'),
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: alerts.isEmpty
              ? const Center(
                  child: Text('No alerts match these filters.',
                      style: TextStyle(color: AppColors.textSecondary)),
                )
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

  Widget _reportsTab(AppState app, {bool compact = false}) {
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
    final stateCounts = countBy(
        excluding(state: false), (r) => alertById[r.alertId]?.state ?? '');
    final outcomeCounts = countBy(excluding(outcome: false), (r) => r.outcome);
    final utilityCounts = countBy(
        excluding(utility: false),
        (r) => alertById[r.alertId]?.utility == Utility.electricity
            ? 'electricity'
            : 'water');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (compact)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: FilterSearchField(
              controller: _reportSearch,
              hint: 'Type anything to search',
              onChanged: (_) => setState(() {}),
            ),
          ),
        if (!compact) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: ReportFilterBar(
              searchController: _reportSearch,
              onSearchChanged: (_) => setState(() {}),
              selectedState: _reportState,
              states: states,
              stateCounts: stateCounts,
              onStateChanged: (v) => setState(() => _reportState = v),
              selectedOutcome: _reportOutcome,
              outcomeCounts: outcomeCounts,
              onOutcomeChanged: (v) => setState(() => _reportOutcome = v),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: UtilityChips(
              selected: _reportUtility,
              allCount: utilityCounts.values.fold<int>(0, (a, b) => a + b),
              waterCount: utilityCounts['water'] ?? 0,
              electricityCount: utilityCounts['electricity'] ?? 0,
              onChanged: (u) => setState(() => _reportUtility = u),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _clearReportFilters,
              child: const Text('Clear filters'),
            ),
          ),
        ],
        const SizedBox(height: 14),
        Expanded(
          child: reports.isEmpty
              ? const Center(
                  child: Text('No reports match these filters.',
                      style: TextStyle(color: AppColors.textSecondary)),
                )
              : ListView.builder(
                  padding: compact
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

  Widget _dropdown({
    required String? value,
    required String hint,
    required List<DropdownMenuItem<String?>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          isExpanded: true,
          isDense: true,
          hint: Text(hint,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
          items: items,
          onChanged: onChanged,
          style: const TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _outcomeToggle(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.adminPrimary : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? AppColors.adminPrimary : AppColors.divider),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
