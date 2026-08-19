import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
import '../widgets/landscape_filter_menu.dart';
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
    final pendingCount = app.pendingAlerts().length;

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
                _alertQueueTab(app),
                _reportsTab(app),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: isAlertsTab
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.adminPrimary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_alert_outlined),
              label: const Text('Report State'),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const AbnormalProductionScreen(
                        showBackToOversight: true,
                      ))),
            )
          : null,
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
    if (_landscapeStatuses.length == 1 &&
        _landscapeStatuses.contains(AlertStatus.faults)) {
      return 'Fault alerts';
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
            _landscapeStatusChip('Faults', {AlertStatus.faults}),
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

  // --- Alert Queue tab ---

  /// The statuses offered in the queue filter. `dismissed` is deliberately
  /// left out — it is a terminal state nobody triages from this screen.
  static const _queueStatuses = [
    AlertStatus.pending,
    AlertStatus.investigating,
    AlertStatus.notFixed,
    AlertStatus.resolved,
    AlertStatus.faults,
  ];

  Widget _alertQueueTab(AppState app) {
    final states = app.alerts.map((a) => a.state).toSet().toList()..sort();
    final scoped = app.alertsFiltered(utility: _alertUtility);

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
        if (severity && _alertSeverity != null && a.severity != _alertSeverity) {
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
          child: FilterSearchField(
            controller: _alertSearch,
            hint: 'Search location or alert',
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: FilterDropdown(
                  value: _alertState,
                  allLabel: 'All States',
                  options: states,
                  counts: stateCounts,
                  onChanged: (v) => setState(() => _alertState = v),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilterDropdown(
                  value: _alertSeverity,
                  allLabel: 'All Severity',
                  options: const [
                    Severity.high,
                    Severity.medium,
                    Severity.low,
                  ],
                  labelFor: Severity.label,
                  counts: severityCounts,
                  onChanged: (v) => setState(() => _alertSeverity = v),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: FilterDropdown(
            value: _alertStatus,
            allLabel: 'All Status',
            options: _queueStatuses,
            labelFor: AlertStatus.label,
            counts: statusCounts,
            onChanged: (v) => setState(() => _alertStatus = v),
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
                    return _AlertCard(
                      alert: alert,
                      resolvedAt: alert.id == null
                          ? null
                          : app.resolvedAtFor(alert.id!),
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
    final stateCounts =
        countBy(excluding(state: false), (r) => alertById[r.alertId]?.state ?? '');
    final outcomeCounts = countBy(excluding(outcome: false), (r) => r.outcome);
    final utilityCounts = countBy(
        excluding(utility: false),
        (r) => alertById[r.alertId]?.utility == Utility.electricity
            ? 'electricity'
            : 'water');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: compact
              ? const EdgeInsets.fromLTRB(16, 8, 16, 0)
              : const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: FilterSearchField(
            controller: _reportSearch,
            hint: 'Search location or alert',
            onChanged: (_) => setState(() {}),
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: FilterDropdown(
                    value: _reportState,
                    allLabel: 'All States',
                    options: states,
                    counts: stateCounts,
                    onChanged: (v) => setState(() => _reportState = v),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilterDropdown(
                    value: _reportOutcome,
                    allLabel: 'All Outcomes',
                    options: const [
                      ReportOutcome.fixed,
                      ReportOutcome.notFixed
                    ],
                    labelFor: ReportOutcome.label,
                    counts: outcomeCounts,
                    onChanged: (v) => setState(() => _reportOutcome = v),
                  ),
                ),
              ],
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
                    if (compact) {
                      return _ReportCard(report: report, app: app);
                    }
                    final alert = alertById[report.alertId];
                    return ReportCard(
                      report: report,
                      locationLabel: alert?.title ?? 'Alert #${report.alertId}',
                      utility: alert?.utility,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => ReportViewScreen(
                              report: report, barColor: AppColors.adminPrimary))),
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

  // --- Shared controls ---

  static Widget _landscapeContent({
    required bool isFixed,
    required Color outcomeColor,
    required Color outcomeBg,
    required String state,
    required Color utilityColor,
    required Color utilityBg,
    required IconData utilityIcon,
    required String utilityLabel,
    required String date,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 2,
          child: Row(
            children: [
              Icon(
                isFixed ? Icons.check_circle : Icons.warning_amber_rounded,
                color: outcomeColor,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      state,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: utilityBg,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(utilityIcon, size: 12, color: utilityColor),
                          const SizedBox(width: 4),
                          Text(
                            utilityLabel,
                            style: TextStyle(
                              fontSize: 11,
                              color: utilityColor,
                              fontWeight: FontWeight.w700,
                            ),
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
        _landscapeDivider(),
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _landscapeMetricColumn(
              label: 'Details',
              value: Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
            ),
          ),
        ),
        _landscapeDivider(),
        SizedBox(
          width: 136,
          child: _landscapeMetricColumn(
            label: 'Outcome',
            value: Pill(
              isFixed ? 'Fixed' : 'Not Fixed',
              color: outcomeColor,
              background: outcomeBg,
            ),
          ),
        ),
        _landscapeDivider(),
        SizedBox(
          width: 126,
          child: _landscapeMetricColumn(
            label: 'Updated',
            value: Text(
              date,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        const Icon(Icons.chevron_right, color: AppColors.textTertiary),
      ],
    );
  }

  static Widget _landscapeMetricColumn({
    required String label,
    required Widget value,
  }) {
    const labelStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: AppColors.textTertiary,
    );
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 18,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(label, style: labelStyle),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 38,
          child: Align(
            alignment: Alignment.centerLeft,
            child: value,
          ),
        ),
        const SizedBox(height: 6),
        const SizedBox(height: 6),
      ],
    );
  }

  static Widget _landscapeDivider() {
    return Container(
      width: 1,
      height: 48,
      color: AppColors.divider,
    );
  }
}

class _AlertCard extends StatelessWidget {
  final Alert alert;
  final DateTime? resolvedAt;
  const _AlertCard({required this.alert, this.resolvedAt});

  @override
  Widget build(BuildContext context) {
    final sev = alert.severity;
    final sevColor = severityColor(sev);
    final isWater = alert.utility == Utility.water;
    final utilityColor =
        isWater ? AppColors.waterAccent : AppColors.electricityAccent;
    final utilityBg =
        isWater ? AppColors.waterSurface : AppColors.electricitySurface;
    final utilityIcon =
        isWater ? Icons.water_drop_outlined : Icons.electric_bolt_outlined;
    final utilityLabel = isWater ? 'Water' : 'Electricity';
    final date = DateFormat('d MMM').format(alert.detectedAt);

    final usesLossPct = alert.lossPct != null;
    final metric = usesLossPct
        ? '${alert.lossPct!.toStringAsFixed(1)}%'
        : '${alert.ratio.toStringAsFixed(1)}x';
    final metricUnit = usesLossPct ? 'of supply lost' : 'of state average';

    final typeLabel = alertReasonLabel(alert);
    final handled = handledLabel(alert, resolvedAt);
    final handledColor =
        alert.status == AlertStatus.resolved ? AppColors.success : AppColors.textSecondary;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => AdminAlertDetailScreen(alertId: alert.id!))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: sevColor),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          alert.title,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: utilityBg,
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(utilityIcon,
                                                  size: 12,
                                                  color: utilityColor),
                                              const SizedBox(width: 4),
                                              Text(
                                                utilityLabel,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: utilityColor,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  severityPill(alert.severity),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  statusPill(alert.status),
                                  Text(
                                    '$typeLabel · Flagged $date',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              if (alert.baselineL > 0 ||
                                  alert.lossPct != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.trending_up,
                                        size: 14, color: sevColor),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$metric $metricUnit',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: sevColor,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (handled != null) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(
                                      alert.status == AlertStatus.resolved
                                          ? Icons.check_circle_outline
                                          : Icons.person_outline,
                                      size: 14,
                                      color: handledColor,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      handled,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: handledColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right,
                            color: AppColors.textTertiary, size: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}

/// The wide, tablet-landscape report row. Portrait uses the shared
/// [ReportCard] from `style.dart` instead — this one only ever renders in
/// [OversightLandscapeWorkspace]'s `reportsBody`.
class _ReportCard extends StatelessWidget {
  final Report report;
  final AppState app;

  const _ReportCard({required this.report, required this.app});

  @override
  Widget build(BuildContext context) {
    final isFixed = report.isFixed;
    final outcomeColor = isFixed ? AppColors.success : AppColors.warning;
    final outcomeBg =
        isFixed ? AppColors.successSurface : AppColors.warningSurface;
    final matches = app.alerts.where((a) => a.id == report.alertId);
    final alert = matches.isEmpty ? null : matches.first;
    final state = alert?.state ?? 'Unknown';
    final isWater = alert?.utility == Utility.water;
    final utilityColor =
        isWater ? AppColors.waterAccent : AppColors.electricityAccent;
    final utilityBg =
        isWater ? AppColors.waterSurface : AppColors.electricitySurface;
    final utilityIcon =
        isWater ? Icons.water_drop_outlined : Icons.electric_bolt_outlined;
    final utilityLabel = isWater ? 'Water' : 'Electricity';
    final date = DateFormat('d MMM y, HH:mm').format(report.updatedAt);
    final description = report.findings.isEmpty
        ? (isFixed
            ? 'No findings. Sensor reading normalized.'
            : 'No findings recorded.')
        : report.findings;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ReportViewScreen(
              report: report, barColor: AppColors.adminPrimary))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        key: const Key('oversight-landscape-report-card'),
        child: _OversightScreenState._landscapeContent(
          isFixed: isFixed,
          outcomeColor: outcomeColor,
          outcomeBg: outcomeBg,
          state: state,
          utilityColor: utilityColor,
          utilityBg: utilityBg,
          utilityIcon: utilityIcon,
          utilityLabel: utilityLabel,
          date: date,
          description: description,
        ),
      ),
    );
  }
}
