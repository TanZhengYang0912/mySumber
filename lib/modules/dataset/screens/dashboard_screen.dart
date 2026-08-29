import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/tokens.dart';
import '../../auth/state/auth_state.dart';
import '../../admin/services/admin_tablet_layout.dart';
import '../../../theme/page_header.dart';
import '../../leakage/state/app_state.dart';
import '../services/dashboard_overview.dart';
import '../services/mall_summary.dart';
import '../services/state_csv_import.dart';
import '../state/dataset_state.dart';
import '../widgets/state_csv_preview_dialog.dart';

typedef _OverviewPillData = ({
  String keyName,
  String text,
  Color color,
  IconData icon,
});

class DashboardScreen extends StatefulWidget {
  final ValueChanged<String>? onStateTap;
  final ValueChanged<int>? onOpenTab;

  const DashboardScreen({super.key, this.onStateTap, this.onOpenTab});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const _comparisonElectricityColor = AppColors.electricityAccent;
  static const _comparisonElectricitySurface = AppColors.electricitySurface;

  String _selectedPeriod = 'Monthly';
  final _stateBarController = ScrollController();
  final _standardDashboardController = ScrollController();
  final _landscapeDashboardController = ScrollController();
  AdminLayoutMode? _lastDashboardMode;
  double _dashboardScrollOffset = 0;

  static const _mallTabIndex = 1;
  static const _anomaliesTabIndex = 2;

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
    final app = context.watch<AppState>();
    final malls = mallStatusCounts(buildMallSummaries(
      state.nodes,
      state.latestUsageByNode,
      state.latestUsageAtByNode,
    ));
    final anomalies = anomalyCounts(app.alerts);
    final mode = adminLayoutModeFor(MediaQuery.sizeOf(context));
    _syncDashboardScrollMode(mode);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : mode == AdminLayoutMode.phoneLandscape
              ? _phoneLandscapeDashboard(
                  state: state,
                  malls: malls,
                  anomalies: anomalies,
                )
              : ListView(
                  controller: _standardDashboardController,
                  key: const PageStorageKey('admin-dashboard-standard-list'),
                  padding: EdgeInsets.zero,
                  children: [
                    _header(context),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: _overviewCard(malls, anomalies),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      child: _usageComparisonCard(state),
                    ),
                  ],
                ),
    );
  }

  Widget _phoneLandscapeDashboard({
    required DatasetState state,
    required MallStatusCounts malls,
    required AnomalyCounts anomalies,
  }) {
    return SingleChildScrollView(
      controller: _landscapeDashboardController,
      key: const PageStorageKey('phone-landscape-dashboard'),
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          PageHeader(
            title: 'Dashboard',
            icon: Icons.grid_view_outlined,
            compact: true,
            onLogout: () => context.read<RoleState>().logout(),
            action: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AdminHeaderAction(
                  icon: Icons.upload_outlined,
                  label: 'Import',
                  secondary: true,
                  onPressed: _importStateCsv,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: adminLandscapeHorizontalInset,
            ),
            child: _overviewCard(malls, anomalies),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: adminLandscapeHorizontalInset,
            ),
            child: _usageComparisonCard(state),
          ),
          const SizedBox(height: 24),
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

  Future<void> _importStateCsv() async {
    final selection = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (!mounted || selection == null) return;

    late final List<int> bytes;
    try {
      bytes = await selection.readAsBytes();
    } catch (error) {
      _showImportError('Could not read ${selection.name}: $error');
      return;
    }

    late final String csv;
    try {
      csv = utf8.decode(bytes);
    } on FormatException {
      _showImportError('The selected file is not valid UTF-8 CSV.');
      return;
    }

    late final StateCsvResult result;
    try {
      result = parseStateCsv(csv);
    } on FormatException catch (error) {
      _showImportError(error.message);
      return;
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StateCsvPreviewDialog(
        fileName: selection.name,
        result: result,
      ),
    );
    if (!mounted || confirmed != true) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        'Read ${result.rows.length} rows across ${result.stateCount} states '
        'from ${result.kind.label}.',
      ),
      backgroundColor: AppColors.success,
    ));
  }

  void _showImportError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: AppColors.critical,
    ));
  }

  Widget _header(BuildContext context) {
    return PageHeader(
      title: 'Dashboard',
      icon: Icons.grid_view_outlined,
      onLogout: () => context.read<RoleState>().logout(),
      action: AdminHeaderAction(
        icon: Icons.upload_outlined,
        label: 'Import',
        secondary: true,
        onPressed: _importStateCsv,
      ),
    );
  }

  Widget _overviewCard(MallStatusCounts malls, AnomalyCounts anomalies) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _overviewSectionCard(
          rowKey: const ValueKey('overview-malls'),
          iconKey: const ValueKey('overview-malls-icon'),
          title: 'Mall health',
          metric: '${malls.total} malls',
          icon: Icons.location_city_outlined,
          iconColor: AppColors.adminPrimary,
          iconBackground: AppColors.adminSurface,
          columns: 2,
          onTap: () => widget.onOpenTab?.call(_mallTabIndex),
          pills: [
            (
              keyName: 'critical',
              text: '${malls.critical} critical',
              color: AppColors.critical,
              icon: Icons.error_outline,
            ),
            if (malls.warning > 0)
              (
                keyName: 'warning',
                text: '${malls.warning} warning',
                color: AppColors.warning,
                icon: Icons.warning_amber_outlined,
              ),
            (
              keyName: 'maintenance',
              text: '${malls.maintenance} maintenance',
              color: AppColors.textSecondary,
              icon: Icons.build_outlined,
            ),
            (
              keyName: 'active',
              text: '${malls.active} active',
              color: AppColors.success,
              icon: Icons.check_circle_outline,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _overviewSectionCard(
          rowKey: const ValueKey('overview-anomalies'),
          iconKey: const ValueKey('overview-anomalies-icon'),
          title: 'Anomaly queue',
          metric: '${anomalies.toReview} to review',
          icon: Icons.notifications_none_outlined,
          iconColor: AppColors.waterAccent,
          iconBackground: AppColors.waterSurface,
          columns: 3,
          onTap: () => widget.onOpenTab?.call(_anomaliesTabIndex),
          pills: [
            (
              keyName: 'ongoing',
              text: '${anomalies.ongoing} ongoing',
              color: AppColors.waterAccent,
              icon: Icons.schedule_outlined,
            ),
            (
              keyName: 'resolved',
              text: '${anomalies.resolved} resolved',
              color: AppColors.success,
              icon: Icons.check_circle_outline,
            ),
            (
              keyName: 'rejected',
              text: '${anomalies.rejected} rejected',
              color: AppColors.textSecondary,
              icon: Icons.block_outlined,
            ),
          ],
        ),
      ],
    );
  }

  Widget _overviewSectionCard({
    required Key rowKey,
    required Key iconKey,
    required String title,
    required String metric,
    required IconData icon,
    required Color iconColor,
    required Color iconBackground,
    required int columns,
    required List<_OverviewPillData> pills,
    required VoidCallback onTap,
  }) {
    return AppCard(
      key: rowKey,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                key: iconKey,
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBackground,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textTertiary,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            metric,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          _overviewPillGrid(pills: pills, columns: columns),
        ],
      ),
    );
  }

  Widget _overviewPillGrid({
    required List<_OverviewPillData> pills,
    required int columns,
  }) {
    const gap = 8.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final pill in pills)
              SizedBox(width: width, child: _overviewStatusPill(pill)),
          ],
        );
      },
    );
  }

  Widget _overviewStatusPill(_OverviewPillData pill) {
    return Container(
      key: ValueKey('overview-pill-${pill.keyName}'),
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: pill.color),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(pill.icon, size: 16, color: pill.color),
            const SizedBox(width: 6),
            Text(
              pill.text,
              style: TextStyle(
                color: pill.color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
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
                  color: _comparisonElectricityColor,
                  bg: _comparisonElectricitySurface,
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
              _legendDot(
                _comparisonElectricityColor,
                'Electricity',
                markerKey:
                    const ValueKey('usage-comparison-electricity-legend'),
              ),
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
                _valueBar(
                  electricity,
                  scale,
                  _comparisonElectricityColor,
                  key: const ValueKey('usage-comparison-electricity-bar'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _valueBar(
    double value,
    double scale,
    Color color, {
    Key? key,
  }) {
    final ratio = scale <= 0 ? 0.0 : (value / scale).clamp(0.0, 1.0);
    return SizedBox(
      key: key,
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

  Widget _legendDot(Color color, String label, {Key? markerKey}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          key: markerKey,
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

  static String _shortNum(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }
}
