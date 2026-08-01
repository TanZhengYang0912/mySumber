import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/tokens.dart';
import '../../auth/state/auth_state.dart';
import '../../admin/services/admin_tablet_layout.dart';
import '../state/dataset_state.dart';
import '../models/models.dart';

class DashboardScreen extends StatefulWidget {
  final ValueChanged<String>? onStateTap;

  const DashboardScreen({super.key, this.onStateTap});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _selectedPeriod = 'Monthly';
  final _stateBarController = ScrollController();
  final _standardDashboardController = ScrollController();
  final _landscapeDashboardController = ScrollController();
  final _fullDashboardKey = GlobalKey();
  AdminLayoutMode? _lastDashboardMode;
  double _dashboardScrollOffset = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DatasetState>().loadNodes();
    });
  }

  @override
  void dispose() {
    _stateBarController.dispose();
    _standardDashboardController.dispose();
    _landscapeDashboardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DatasetState>();
    final nodes = state.nodes;
    final total = nodes.length;
    final active = nodes.where((n) => n.status == 'Active').length;
    final critical = nodes.where((n) => n.status == 'Critical').length;
    final warning = total - active - critical;

    final sortedByHealth = [...nodes]
      ..sort((a, b) => a.healthScore.compareTo(b.healthScore));
    final healthPreview = sortedByHealth.take(3).toList();
    final priority = healthPreview.isEmpty ? null : healthPreview.first;
    final mode = adminLayoutModeFor(MediaQuery.sizeOf(context));
    _syncDashboardScrollMode(mode);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : mode == AdminLayoutMode.phoneLandscape
              ? _phoneLandscapeDashboard(
                  state: state,
                  total: total,
                  active: active,
                  warning: warning,
                  critical: critical,
                  priority: priority,
                  healthPreview: healthPreview,
                )
              : ListView(
                  controller: _standardDashboardController,
                  key: const PageStorageKey('admin-dashboard-standard-list'),
                  padding: EdgeInsets.zero,
                  children: [
                    _header(context),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child:
                          _systemOverviewCard(total, active, warning, critical),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: _usageComparisonCard(state),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      child: _equipmentHealthCard(healthPreview),
                    ),
                  ],
                ),
    );
  }

  Widget _phoneLandscapeDashboard({
    required DatasetState state,
    required int total,
    required int active,
    required int warning,
    required int critical,
    required EquipmentNode? priority,
    required List<EquipmentNode> healthPreview,
  }) {
    return SafeArea(
      child: ListView(
        controller: _landscapeDashboardController,
        key: const PageStorageKey('phone-landscape-dashboard'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        children: [
          SizedBox(
            height: 56,
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.adminSurface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.grid_view_outlined,
                    color: AppColors.adminPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dashboard',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Priority system status',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Tooltip(
                  message: 'View full dashboard',
                  child: TextButton(
                    onPressed: _scrollToFullDashboard,
                    child: const Text('View full'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: Row(
              children: [
                Expanded(
                  child: _landscapeStatusPanel(
                    active: active,
                    critical: critical,
                    warning: warning,
                    total: total,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(child: _landscapePriorityPanel(priority)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          KeyedSubtree(
            key: _fullDashboardKey,
            child: _usageComparisonCard(state),
          ),
          const SizedBox(height: 16),
          _equipmentHealthCard(healthPreview),
        ],
      ),
    );
  }

  void _syncDashboardScrollMode(AdminLayoutMode mode) {
    final isLandscape = mode == AdminLayoutMode.phoneLandscape;
    final previousMode = _lastDashboardMode;
    final wasLandscape = previousMode == AdminLayoutMode.phoneLandscape;
    _lastDashboardMode = mode;

    if (previousMode == null || wasLandscape == isLandscape) return;

    final source = wasLandscape
        ? _landscapeDashboardController
        : _standardDashboardController;
    if (source.hasClients) {
      _dashboardScrollOffset = source.offset;
    }
    final target = isLandscape
        ? _landscapeDashboardController
        : _standardDashboardController;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !target.hasClients) return;
      final maxOffset = target.position.maxScrollExtent;
      target.jumpTo(_dashboardScrollOffset.clamp(0, maxOffset));
    });
  }

  void _scrollToFullDashboard() {
    final targetContext = _fullDashboardKey.currentContext;
    if (targetContext == null) return;
    Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      alignment: 0,
    );
  }

  Widget _landscapeStatusPanel({
    required int active,
    required int critical,
    required int warning,
    required int total,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('System health'),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: _landscapeStat(
                  label: 'Active',
                  value: active,
                  color: AppColors.success,
                  background: AppColors.successSurface,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _landscapeStat(
                  label: 'Critical',
                  value: critical,
                  color: AppColors.critical,
                  background: AppColors.criticalSurface,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            '$total monitored · $warning warning${warning == 1 ? '' : 's'}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _landscapeStat({
    required String label,
    required int value,
    required Color color,
    required Color background,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value.toString(),
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _landscapePriorityPanel(EquipmentNode? priority) {
    if (priority == null) {
      return const AppCard(
        child: Center(
          child: Text(
            'No equipment available.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final location = [priority.facilityName, priority.zoneId]
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .join(' · ');
    final scoreColor = priority.healthScore < 70
        ? AppColors.critical
        : priority.healthScore < 85
            ? AppColors.warning
            : AppColors.success;

    return AppCard(
      key: const ValueKey('priority-equipment'),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Priority equipment'),
          const Spacer(),
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: scoreColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.monitor_heart_outlined, color: scoreColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  priority.nodeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${priority.healthScore}%',
                style: TextStyle(
                  color: scoreColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            location.isEmpty
                ? priority.status
                : '$location · ${priority.status}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          const Text(
            'Open Inventory for full equipment health.',
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.adminPrimary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'mySumber · ADMIN',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => context.read<RoleState>().logout(),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.logout, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text('Logout',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Dashboard',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _systemOverviewCard(int total, int active, int warning, int critical) {
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: StatCell(
              icon: Icons.dns_outlined,
              iconColor: AppColors.textPrimary,
              value: total.toString(),
              label: 'Total',
              background: const Color(0xFFF3F4F6),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: StatCell(
              icon: Icons.monitor_heart_outlined,
              iconColor: AppColors.success,
              value: active.toString(),
              label: 'Active',
              background: AppColors.successSurface,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: StatCell(
              icon: Icons.warning_amber_outlined,
              iconColor: AppColors.warning,
              value: warning.toString(),
              label: 'Warning',
              background: AppColors.warningSurface,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: StatCell(
              icon: Icons.dns_outlined,
              iconColor: AppColors.critical,
              value: critical.toString(),
              label: 'Critical',
              background: AppColors.criticalSurface,
            ),
          ),
        ],
      ),
    );
  }

  double get _periodMultiplier {
    switch (_selectedPeriod) {
      case 'Daily':
        return 1 / 365.0;
      case '7D Avg':
        return 7 / 365.0;
      case 'Yearly':
        return 1.0;
      default:
        return 30 / 365.0;
    }
  }

  String get _periodUnit {
    switch (_selectedPeriod) {
      case 'Daily':
        return '/day';
      case '7D Avg':
        return '/week';
      case 'Yearly':
        return '/year';
      default:
        return '/month';
    }
  }

  Widget _usageComparisonCard(DatasetState state) {
    final mult = _periodMultiplier;
    final unit = _periodUnit;

    final waterLoss = <String, double>{};
    final elecLoss = <String, double>{};
    for (final s in state.stateWaterSupply.keys) {
      final loss = ((state.stateWaterSupply[s] ?? 0) -
              (state.stateWaterConsumption[s] ?? 0)) *
          mult;
      if (loss > 0) waterLoss[s] = loss;
    }
    for (final s in state.stateElectricitySupply.keys) {
      final loss = ((state.stateElectricitySupply[s] ?? 0) -
              (state.stateElectricityConsumption[s] ?? 0)) *
          mult;
      if (loss > 0) elecLoss[s] = loss;
    }
    final topWater = waterLoss.entries.isEmpty
        ? null
        : (waterLoss.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .first;
    final topElec = elecLoss.entries.isEmpty
        ? null
        : (elecLoss.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .first;

    final unionStates = {...waterLoss.keys, ...elecLoss.keys}.toList()..sort();

    const periods = ['Daily', '7D Avg', 'Monthly', 'Yearly'];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Usage Comparison',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              PopupMenuButton<String>(
                onSelected: (v) => setState(() => _selectedPeriod = v),
                itemBuilder: (_) => periods
                    .map((p) => PopupMenuItem<String>(
                          value: p,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 2),
                            decoration: p == _selectedPeriod
                                ? BoxDecoration(
                                    color: AppColors.canvas,
                                    borderRadius: BorderRadius.circular(6),
                                  )
                                : null,
                            child: Text(
                              p,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: p == _selectedPeriod
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                color: p == _selectedPeriod
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ))
                    .toList(),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.canvas,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_selectedPeriod,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down,
                          size: 18, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _lossCallout(
                  icon: Icons.water_drop_outlined,
                  color: AppColors.waterAccent,
                  bg: AppColors.waterSurface,
                  label: 'Top Water Loss',
                  state: topWater?.key ?? 'N/A',
                  value: '${_shortNum(topWater?.value ?? 0)} L$unit',
                  onTap: topWater == null
                      ? null
                      : () => widget.onStateTap?.call(topWater.key),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _lossCallout(
                  icon: Icons.electric_bolt_outlined,
                  color: AppColors.electricityAccent,
                  bg: AppColors.electricitySurface,
                  label: 'Top Elec. Loss',
                  state: topElec?.key ?? 'N/A',
                  value: '${_shortNum(topElec?.value ?? 0)} Wh$unit',
                  onTap: topElec == null
                      ? null
                      : () => widget.onStateTap?.call(topElec.key),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _horizontalLossChart(
            unionStates,
            waterLoss,
            elecLoss,
            onStateTap: widget.onStateTap,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendDot(AppColors.waterAccent, 'Water'),
              const SizedBox(width: 24),
              _legendDot(AppColors.electricityAccent, 'Electricity'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _lossCallout({
    required IconData icon,
    required Color color,
    required Color bg,
    required String label,
    required String state,
    required String value,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(state,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
            Text(value,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _horizontalLossChart(
    List<String> states,
    Map<String, double> waterLoss,
    Map<String, double> elecLoss, {
    ValueChanged<String>? onStateTap,
  }) {
    if (states.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text('No data available.',
              style: TextStyle(color: AppColors.textTertiary)),
        ),
      );
    }
    double maxV = 0;
    for (final s in states) {
      maxV = [
        maxV,
        waterLoss[s] ?? 0,
        elecLoss[s] ?? 0,
      ].reduce((a, b) => a > b ? a : b);
    }
    if (maxV == 0) maxV = 100;
    final scale = maxV * 1.05;

    const rowHeight = 42.0;
    final visibleRows = states.length > 4 ? 4 : states.length;
    final scrollHeight = rowHeight * visibleRows;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (states.length > 4)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Icon(Icons.swap_vert,
                    size: 14, color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Text(
                  'Scroll to see all ${states.length} states',
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                      fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        SizedBox(
          height: scrollHeight,
          child: Scrollbar(
            controller: _stateBarController,
            thumbVisibility: true,
            child: ListView.builder(
              controller: _stateBarController,
              padding: const EdgeInsets.only(right: 8),
              physics: const ClampingScrollPhysics(),
              itemCount: states.length,
              itemExtent: rowHeight,
              itemBuilder: (ctx, i) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _stateBarRow(
                  state: states[i],
                  water: waterLoss[states[i]] ?? 0,
                  electricity: elecLoss[states[i]] ?? 0,
                  scale: scale,
                  onTap:
                      onStateTap == null ? null : () => onStateTap(states[i]),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _axisScale(scale),
        const SizedBox(height: 4),
        const Align(
          alignment: Alignment.centerRight,
          child: Text(
            'L / Wh (x1000)',
            style: TextStyle(fontSize: 10, color: AppColors.textTertiary),
          ),
        ),
      ],
    );
  }

  Widget _stateBarRow({
    required String state,
    required double water,
    required double electricity,
    required double scale,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              state,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _valueBar(water, scale, AppColors.waterAccent),
                const SizedBox(height: 4),
                _valueBar(electricity, scale, AppColors.electricityAccent),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _valueBar(double value, double scale, Color color) {
    final ratio = scale <= 0 ? 0.0 : (value / scale).clamp(0.0, 1.0);
    return SizedBox(
      height: 14,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth * ratio;
          return Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 10,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Container(
                width: width,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Positioned(
                left: width + 4,
                child: Text(
                  _shortNum(value),
                  style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _axisScale(double scale) {
    final ticks = List.generate(5, (i) => scale * i / 4);
    return Padding(
      padding: const EdgeInsets.only(left: 72),
      child: Row(
        children: [
          for (int i = 0; i < ticks.length; i++) ...[
            if (i > 0) const Spacer(),
            Text(
              _shortNum(ticks[i]),
              style:
                  const TextStyle(fontSize: 10, color: AppColors.textTertiary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _equipmentHealthCard(List<EquipmentNode> equipment) {
    if (equipment.isEmpty) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            SectionLabel('EQUIPMENT HEALTH'),
            SizedBox(height: 12),
            Text(
              'No equipment deployed yet.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('EQUIPMENT HEALTH'),
          const SizedBox(height: 8),
          for (int i = 0; i < equipment.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: _healthRow(equipment[i]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _healthRow(EquipmentNode node) {
    final color = _healthColor(node.healthScore);
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            node.nodeName,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${node.healthScore}%',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }

  Color _healthColor(int score) {
    if (score >= 80) return AppColors.success;
    if (score >= 50) return AppColors.warning;
    return AppColors.critical;
  }

  static String _shortNum(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }
}
