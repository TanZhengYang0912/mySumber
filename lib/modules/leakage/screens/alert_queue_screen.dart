import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../theme/filter_controls.dart';
import '../../../theme/page_header.dart';
import '../../../theme/tokens.dart';
import '../../auth/state/auth_state.dart';
import '../models/alert.dart';
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

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          PageHeader(
            title: title,
            color: AppColors.workerPrimary,
            brand: 'mySumber · WORKER',
            icon:
                _isWater ? Icons.water_drop_outlined : Icons.electric_bolt_outlined,
            onLogout: () => context.read<RoleState>().logout(),
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
      List<Alert> resolvedAll, String query) {
    final showStatus = _tabController.index == 0;
    final tabBase = showStatus ? unresolvedAll : resolvedAll;

    bool matchesQuery(Alert a) =>
        query.isEmpty ||
        a.state.toLowerCase().contains(query) ||
        (a.householdId ?? '').toLowerCase().contains(query);

    // Each dropdown's counts reflect every OTHER active filter but not its
    // own selection — so picking "High" doesn't collapse Severity's own list
    // down to just itself.
    List<Alert> excluding({bool state = true, bool severity = true,
        bool status = true}) {
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

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilterSearchField(
            controller: _search,
            hint: 'Type anything to search',
            accent: AppColors.workerPrimary,
            onChanged: (_) => setState(() {}),
            onClear: _clearFilters,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilterDropdown(
                  value: _selectedState == 'all' ? null : _selectedState,
                  allLabel: 'All States',
                  options: states,
                  counts: stateCounts,
                  onChanged: (v) => setState(() => _selectedState = v ?? 'all'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilterDropdown(
                  value: _severity == 'all' ? null : _severity,
                  allLabel: 'All Severity',
                  options: const [Severity.high, Severity.medium, Severity.low],
                  labelFor: Severity.label,
                  counts: severityCounts,
                  onChanged: (v) => setState(() => _severity = v ?? 'all'),
                ),
              ),
              if (showStatus) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: FilterDropdown(
                    value: _status == 'all' ? null : _status,
                    allLabel: 'All Status',
                    options: _queueStatuses,
                    labelFor: AlertStatus.label,
                    counts: statusCounts,
                    onChanged: (v) => setState(() => _status = v ?? 'all'),
                  ),
                ),
              ],
            ],
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
        return _AlertCard(
          alert: alert,
          resolvedAt:
              alert.id == null ? null : app.resolvedAtFor(alert.id!),
        );
      },
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

    final date = DateFormat('d MMM').format(alert.detectedAt);
    final metricText = alert.lossPct != null
        ? '${alert.lossPct!.toStringAsFixed(1)}% of supply unaccounted'
        : '${alert.ratio.toStringAsFixed(1)}x of state avg';
    final handled = handledLabel(alert, resolvedAt);
    final handledColor =
        alert.status == AlertStatus.resolved ? AppColors.success : AppColors.textSecondary;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => AlertDetailScreen(alertId: alert.id!))),
      child: Stack(
        children: [
          Container(
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
            padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        alert.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    severityPill(sev),
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
                      '${alertReasonLabel(alert)} · Flagged $date',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  metricText,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: sevColor,
                  ),
                ),
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
          Positioned(
            left: 0,
            top: 0,
            bottom: 10,
            child: Container(
              width: 4,
              decoration: BoxDecoration(
                color: sevColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
