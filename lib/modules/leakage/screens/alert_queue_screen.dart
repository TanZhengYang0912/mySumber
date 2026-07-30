import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../theme/tokens.dart';
import '../../auth/state/auth_state.dart';
import '../models/alert.dart';
import '../services/worker_compact_layout.dart';
import '../state/app_state.dart';
import '../widgets/worker_landscape_filter_menu.dart';
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
    setState(() {
      _search.clear();
      _severity = 'all';
      _selectedState = 'all';
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _search.dispose();
    super.dispose();
  }

  bool get _isWater => widget.utility == Utility.water;

  int get _activeFilterCount =>
      (_search.text.trim().isNotEmpty ? 1 : 0) +
      (_severity != 'all' ? 1 : 0) +
      (_selectedState != 'all' ? 1 : 0);

  void _clearFilters() {
    setState(() {
      _search.clear();
      _severity = 'all';
      _selectedState = 'all';
    });
  }

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

    final unresolved = filter(unresolvedAll);
    final resolved = filter(resolvedAll);

    final title = _isWater ? 'Water Alerts' : 'Electricity Alerts';
    final isPhoneLandscape =
        usesWorkerPhoneLandscape(MediaQuery.sizeOf(context));

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
          preferredSize: Size.fromHeight(isPhoneLandscape ? 84 : 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (isPhoneLandscape)
                      WorkerLandscapeFilterMenu(
                        activeCount: _activeFilterCount,
                        child: _landscapeFilterControls(allStates),
                      ),
                  ],
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
          if (!isPhoneLandscape) _filters(allStates),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _list(unresolved, 'No unresolved alerts.'),
                _list(resolved, 'No resolved alerts yet.'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _landscapeFilterControls(List<String> states) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: SectionLabel('Filter alerts')),
            TextButton(onPressed: _clearFilters, child: const Text('Clear')),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Search by location or code',
            hintStyle: const TextStyle(color: AppColors.textTertiary),
            prefixIcon: const Icon(Icons.search,
                color: AppColors.textTertiary, size: 20),
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.workerPrimary),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const SectionLabel('Severity'),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: {
            'all': 'All',
            Severity.high: 'High',
            Severity.medium: 'Medium',
            Severity.low: 'Low',
          }.entries.map((option) {
            return ChoiceChip(
              label: Text(option.value),
              selected: _severity == option.key,
              onSelected: (_) => setState(() => _severity = option.key),
              showCheckmark: false,
              selectedColor: AppColors.workerSurface,
              labelStyle: TextStyle(
                color: _severity == option.key
                    ? AppColors.workerPrimary
                    : AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        const SectionLabel('State'),
        const SizedBox(height: 6),
        _dropdown(
          'State',
          _selectedState,
          {
            'all': 'All States',
            for (final state in states) state: state,
          },
          (value) => setState(() => _selectedState = value),
        ),
      ],
    );
  }

  Widget _filters(List<String> states) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        children: [
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search by location or code',
              hintStyle: const TextStyle(color: AppColors.textTertiary),
              prefixIcon: const Icon(Icons.search,
                  color: AppColors.textTertiary, size: 20),
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
          Row(
            children: [
              Expanded(
                child: _dropdown(
                    'Severity',
                    _severity,
                    {
                      'all': 'All Severity',
                      Severity.high: 'High',
                      Severity.medium: 'Medium',
                      Severity.low: 'Low',
                    },
                    (v) => setState(() => _severity = v)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _dropdown(
                  'State',
                  _selectedState,
                  {
                    'all': 'All States',
                    for (final s in states) s: s,
                  },
                  (v) => setState(() => _selectedState = v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dropdown(String hint, String value, Map<String, String> options,
      ValueChanged<String> onChanged) {
    return DropdownButtonFormField<String>(
      key: ValueKey(value),
      initialValue: value,
      isDense: true,
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

  Widget _list(List<Alert> alerts, String empty) {
    if (alerts.isEmpty) {
      return Center(
        child:
            Text(empty, style: const TextStyle(color: AppColors.textSecondary)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemCount: alerts.length,
      itemBuilder: (context, index) => _AlertCard(alert: alerts[index]),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final Alert alert;
  const _AlertCard({required this.alert});

  @override
  Widget build(BuildContext context) {
    final sev = alert.severity;
    final sevColor = severityColor(sev);
    final sevLabel = Severity.label(sev);

    Color sevBg;
    if (sev == Severity.high) {
      sevBg = AppColors.criticalSurface;
    } else if (sev == Severity.medium) {
      sevBg = AppColors.warningSurface;
    } else {
      sevBg = AppColors.workerSurface;
    }

    final typeLabel = _typeLabel();
    final date = DateFormat('d MMM').format(alert.detectedAt);

    final usesLossPct = alert.lossPct != null;
    final metricText = usesLossPct
        ? '${alert.lossPct!.toStringAsFixed(1)}% of supply unaccounted'
        : '${alert.ratio.toStringAsFixed(1)}x of state avg';

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
                        sevLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: sevColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$typeLabel · Flagged $date',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  metricText,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: sevColor,
                  ),
                ),
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

  String _typeLabel() {
    switch (alert.alertType) {
      case AlertType.nrwHotspot:
        return 'NRW Hotspot';
      case AlertType.electricityHotspot:
        return 'Electricity Loss';
      case AlertType.electricityTampering:
        return 'Tampering Spike';
      default:
        return 'Household';
    }
  }
}
