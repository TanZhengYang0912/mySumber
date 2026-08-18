import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../theme/segmented_chips.dart';
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
      appBar: AppBar(
        backgroundColor: AppColors.workerPrimary,
        foregroundColor: Colors.white,
        leading: const BackButton(),
        titleSpacing: 0,
        title: const Text(
          'mySumber · WORKER',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => context.read<RoleState>().logout(),
            icon: const Icon(Icons.logout, color: Colors.white, size: 16),
            label: const Text('Logout',
                style: TextStyle(color: Colors.white, fontSize: 13)),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                tabs: [
                  Tab(text: 'Unresolved  ${unresolvedAll.length}'),
                  Tab(text: 'Resolved  ${resolvedAll.length}'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          _filters(allStates, unresolvedAll),
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

  Widget _filters(List<String> states, List<Alert> unresolvedAll) {
    final showStatus = _tabController.index == 0;

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search by location or code',
              hintStyle: const TextStyle(color: AppColors.textTertiary),
              prefixIcon: const Icon(Icons.search,
                  color: AppColors.textTertiary, size: 20),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close,
                          size: 18, color: AppColors.textTertiary),
                      onPressed: _clearFilters,
                    ),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.divider)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.divider)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.workerPrimary)),
            ),
          ),
          const SizedBox(height: 8),
          // Side by side when there is room, stacked when there isn't.
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth >= 360
                  ? (constraints.maxWidth - 8) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: width,
                    child: _dropdown(
                        _severity,
                        {
                          'all': 'All Severity',
                          Severity.high: 'High',
                          Severity.medium: 'Medium',
                          Severity.low: 'Low',
                        },
                        (v) => setState(() => _severity = v)),
                  ),
                  SizedBox(
                    width: width,
                    child: _dropdown(
                      _selectedState,
                      {
                        'all': 'All States',
                        for (final s in states) s: s,
                      },
                      (v) => setState(() => _selectedState = v),
                    ),
                  ),
                ],
              );
            },
          ),
          if (showStatus) ...[
            const SizedBox(height: 10),
            SegmentedChipRow(
              children: [
                SegmentedChip(
                  label: 'All',
                  count: unresolvedAll.length,
                  selected: _status == 'all',
                  onTap: () => setState(() => _status = 'all'),
                  color: AppColors.workerPrimary,
                ),
                SegmentedChip(
                  label: 'Pending',
                  count: unresolvedAll
                      .where((a) => a.status == AlertStatus.pending)
                      .length,
                  selected: _status == AlertStatus.pending,
                  onTap: () => setState(() => _status = AlertStatus.pending),
                  color: statusColor(AlertStatus.pending),
                ),
                SegmentedChip(
                  label: 'Investigating',
                  count: unresolvedAll
                      .where((a) => a.status == AlertStatus.investigating)
                      .length,
                  selected: _status == AlertStatus.investigating,
                  onTap: () =>
                      setState(() => _status = AlertStatus.investigating),
                  color: statusColor(AlertStatus.investigating),
                ),
                SegmentedChip(
                  label: 'Not Fixed',
                  count: unresolvedAll
                      .where((a) => a.status == AlertStatus.notFixed)
                      .length,
                  selected: _status == AlertStatus.notFixed,
                  onTap: () => setState(() => _status = AlertStatus.notFixed),
                  color: statusColor(AlertStatus.notFixed),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _dropdown(String value, Map<String, String> options,
      ValueChanged<String> onChanged) {
    return DropdownButtonFormField<String>(
      key: ValueKey(value),
      initialValue: value,
      isDense: true,
      isExpanded: true,
      decoration: InputDecoration(
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.divider)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.divider)),
      ),
      items: options.entries
          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
          .toList(),
      onChanged: (v) => onChanged(v ?? 'all'),
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

    Color sevBg;
    if (sev == Severity.high) {
      sevBg = AppColors.criticalSurface;
    } else if (sev == Severity.medium) {
      sevBg = AppColors.warningSurface;
    } else {
      sevBg = AppColors.workerSurface;
    }

    final date = DateFormat('d MMM').format(alert.detectedAt);
    final metricText = alert.lossPct != null
        ? '${alert.lossPct!.toStringAsFixed(1)}% of supply unaccounted'
        : '${alert.ratio.toStringAsFixed(1)}x of state avg';
    final resolved = resolvedLabel(alert.status, resolvedAt);

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
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: sevBg,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        Severity.label(sev),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: sevColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Pill(AlertStatus.label(alert.status),
                        color: statusColor(alert.status)),
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
                if (resolved != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.check_circle_outline,
                          size: 14, color: AppColors.success),
                      const SizedBox(width: 4),
                      Text(
                        resolved,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
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
