import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/filter_controls.dart';
import '../../../theme/landscape_filter_menu.dart';
import '../../../theme/page_header.dart';
import '../../../theme/tokens.dart';
import '../../auth/state/auth_state.dart';
import '../models/alert.dart';
import '../services/worker_compact_layout.dart';
import '../state/app_state.dart';
import 'alert_detail_screen.dart';
import 'style.dart';

class AlertQueueScreen extends StatefulWidget {
  final Utility utility;
  const AlertQueueScreen({super.key, this.utility = Utility.water});

  @override
  State<AlertQueueScreen> createState() => _AlertQueueScreenState();
}

class _AlertQueueScreenState extends State<AlertQueueScreen>
    with SingleTickerProviderStateMixin {
  final _search = TextEditingController();
  String _severity = 'all';
  String _selectedState = 'all';
  String _status = 'all';
  late final TabController _tabController;
  int _lastIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabController.index == _lastIndex) return;
    _lastIndex = _tabController.index;
    setState(_resetFilters);
  }

  void _resetFilters() {
    _search.clear();
    _severity = 'all';
    _selectedState = 'all';
    _status = 'all';
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _search.dispose();
    super.dispose();
  }

  bool get _isWater => widget.utility == Utility.water;

  void _clearFilters() => setState(_resetFilters);

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final query = _search.text.trim().toLowerCase();

    final unresolvedAll = app.unresolvedFor(widget.utility);
    final resolvedAll = app.resolvedFor(widget.utility);

    final allStates = {
      ...unresolvedAll.map((a) => a.state),
      ...resolvedAll.map((a) => a.state),
    }.toList()
      ..sort();

    List<Alert> filter(List<Alert> source) {
      return source.where((a) {
        if (query.isNotEmpty &&
            !a.state.toLowerCase().contains(query) &&
            !(a.householdId ?? '').toLowerCase().contains(query)) {
          return false;
        }
        if (_severity != 'all' && a.severity != _severity) return false;
        if (_selectedState != 'all' && a.state != _selectedState) return false;
        return true;
      }).toList();
    }

    // Status only narrows the unresolved tab — everything in the resolved tab
    // shares one status by definition.
    final unresolved = filter(unresolvedAll)
        .where((a) => _status == 'all' || a.status == _status)
        .toList();
    final resolved = filter(resolvedAll);

    final title = _isWater ? 'Water Alerts' : 'Electricity Alerts';
    final landscape = usesWorkerPhoneLandscape(MediaQuery.sizeOf(context));

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          PageHeader(
            title: title,
            color: AppColors.workerPrimary,
            brand: 'mySumber · WORKER',
            icon: _isWater
                ? Icons.water_drop_outlined
                : Icons.electric_bolt_outlined,
            onLogout: () => context.read<RoleState>().logout(),
            action: landscape
                ? LandscapeFilterMenu(
                    compact: true,
                    tooltip: 'Filter alerts',
                    activeCount: activeAlertFilterCount(
                      query: _search.text,
                      severity: _severity,
                      state: _selectedState,
                      status: _status,
                    ),
                    footer: TextButton(
                      onPressed: _clearFilters,
                      child: const Text('Clear'),
                    ),
                    child: _filters(
                      allStates,
                      unresolvedAll,
                      resolvedAll,
                      query,
                      chromeless: true,
                    ),
                  )
                : null,
          ),
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.workerPrimary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.workerPrimary,
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
                        const Text('Unresolved'),
                        const SizedBox(width: 6),
                        CountBadge(unresolvedAll.length),
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
                        const Text('Resolved'),
                        const SizedBox(width: 6),
                        CountBadge(resolvedAll.length),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!landscape)
            _filters(allStates, unresolvedAll, resolvedAll, query),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _list(app, unresolved, 'No unresolved alerts.'),
                _list(app, resolved, 'No resolved alerts yet.'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const _queueStatuses = [
    AlertStatus.pending,
    AlertStatus.investigating,
    AlertStatus.notFixed,
  ];

  Widget _filters(List<String> states, List<Alert> unresolvedAll,
      List<Alert> resolvedAll, String query,
      {bool chromeless = false}) {
    final showStatus = _tabController.index == 0;
    final tabBase = showStatus ? unresolvedAll : resolvedAll;

    bool matchesQuery(Alert a) =>
        query.isEmpty ||
        a.state.toLowerCase().contains(query) ||
        (a.householdId ?? '').toLowerCase().contains(query);

    // Each dropdown's counts reflect every OTHER active filter but not its
    // own selection — so picking "High" doesn't collapse Severity's own list
    // down to just itself.
    List<Alert> excluding(
        {bool state = true, bool severity = true, bool status = true}) {
      return tabBase.where((a) {
        if (!matchesQuery(a)) return false;
        if (state && _selectedState != 'all' && a.state != _selectedState) {
          return false;
        }
        if (severity && _severity != 'all' && a.severity != _severity) {
          return false;
        }
        if (status && showStatus && _status != 'all' && a.status != _status) {
          return false;
        }
        return true;
      }).toList();
    }

    final stateCounts = countBy(excluding(state: false), (a) => a.state);
    final severityCounts =
        countBy(excluding(severity: false), (a) => a.severity);
    final statusCounts = showStatus
        ? countBy(excluding(status: false), (a) => a.status)
        : const <String, int>{};

    final bar = AlertFilterBar(
      searchController: _search,
      onSearchChanged: (_) => setState(() {}),
      onSearchClear: _clearFilters,
      accent: AppColors.workerPrimary,
      selectedState: _selectedState == 'all' ? null : _selectedState,
      states: states,
      stateCounts: stateCounts,
      onStateChanged: (v) => setState(() => _selectedState = v ?? 'all'),
      selectedSeverity: _severity == 'all' ? null : _severity,
      severityCounts: severityCounts,
      onSeverityChanged: (v) => setState(() => _severity = v ?? 'all'),
      selectedStatus: showStatus ? (_status == 'all' ? null : _status) : null,
      statusOptions: showStatus ? _queueStatuses : null,
      statusCounts: showStatus ? statusCounts : null,
      onStatusChanged:
          showStatus ? (v) => setState(() => _status = v ?? 'all') : null,
    );

    if (chromeless) return bar;

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          bar,
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _clearFilters,
              child: const Text('Clear filters'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _list(AppState app, List<Alert> alerts, String empty) {
    if (alerts.isEmpty) {
      return Center(
        child:
            Text(empty, style: const TextStyle(color: AppColors.textSecondary)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemCount: alerts.length,
      itemBuilder: (context, index) {
        final alert = alerts[index];
        return AlertCard(
          alert: alert,
          utility: widget.utility,
          resolvedAt: alert.id == null ? null : app.resolvedAtFor(alert.id!),
          resolvedHandledBy:
              app.workerNames[alert.handledById] ?? alert.handledBy,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => AlertDetailScreen(alertId: alert.id!))),
        );
      },
    );
  }
}
