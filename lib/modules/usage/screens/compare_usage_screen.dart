import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/tokens.dart';
import '../../auth/state/auth_state.dart';
import '../models/utility_entry.dart';
import '../services/customer_compact_layout.dart';
import '../state/usage_state.dart';
import '../widgets/add_consumption_sheet.dart';
import 'notifications_screen.dart';
import 'report_problem_screen.dart';

const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _monthYearLabel(DateTime d) => '${_monthNames[d.month - 1]} ${d.year}';

class CompareUsageScreen extends StatefulWidget {
  const CompareUsageScreen({super.key});

  @override
  State<CompareUsageScreen> createState() => _CompareUsageScreenState();
}

class _CompareUsageScreenState extends State<CompareUsageScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  UtilityType get _utility =>
      _tab.index == 0 ? UtilityType.water : UtilityType.electricity;

  @override
  Widget build(BuildContext context) {
    final usage = context.watch<UsageState>();
    final utility = _utility;
    final accent = utility == UtilityType.water
        ? AppColors.waterAccent
        : AppColors.electricityAccent;
    final surface = utility == UtilityType.water
        ? AppColors.waterSurface
        : AppColors.electricitySurface;

    if (usesCustomerPhoneLandscape(MediaQuery.sizeOf(context))) {
      return _phoneLandscapeUsage(
        context,
        usage,
        utility,
        accent,
        surface,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.canvas,
      floatingActionButton: AddConsumptionFab(utility: utility),
      body: usage.loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.zero,
              children: [
                _header(context),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: _utilityTabs(accent),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                  child: _summaryCard(usage, utility, accent, surface),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                  child: _monthlyChart(usage, utility, accent, surface),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 96),
                  child: _recordLog(usage, utility, accent),
                ),
              ],
            ),
    );
  }

  Widget _phoneLandscapeUsage(
    BuildContext context,
    UsageState usage,
    UtilityType utility,
    Color accent,
    Color surface,
  ) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            key: const PageStorageKey('customer-phone-landscape-usage'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionLabel('MY USAGE'),
                        SizedBox(height: 2),
                        Text(
                          'Household usage',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () =>
                        showAddConsumptionFlow(context, utility: utility),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add reading'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.customerPrimary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: _landscapeUtilityToggle(),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: constraints.maxWidth >= 760 ? 3 : 2,
                        child: _landscapeUsageSummary(
                          usage,
                          utility,
                          accent,
                          surface,
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: constraints.maxWidth >= 760 ? 242 : 210,
                        child: _landscapeQuickActions(context, utility),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _landscapeUtilityToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _landscapeToggleButton(
            label: 'Water',
            icon: Icons.water_drop_outlined,
            selected: _tab.index == 0,
            color: AppColors.waterAccent,
            onTap: () => _tab.animateTo(0),
          ),
          _landscapeToggleButton(
            label: 'Electricity',
            icon: Icons.electric_bolt_outlined,
            selected: _tab.index == 1,
            color: AppColors.electricityAccent,
            onTap: () => _tab.animateTo(1),
          ),
        ],
      ),
    );
  }

  Widget _landscapeToggleButton({
    required String label,
    required IconData icon,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selected ? color : AppColors.textTertiary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? color : AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _landscapeUsageSummary(
    UsageState usage,
    UtilityType utility,
    Color accent,
    Color surface,
  ) {
    final current = usage.currentMonthEntry(utility);
    final vsLastMonth = usage.percentVsLastMonth(utility);
    final average = usage.average(utility);
    final months = _lastSixMonths();
    final values = months.map((month) => usage.entryForMonth(utility, month)).toList();
    final maxValue = values
        .whereType<UtilityEntry>()
        .map((entry) => entry.value)
        .fold<double>(0, (max, value) => max > value ? max : value);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_monthLabel(DateTime.now())} ${DateTime.now().year} · ${utility.label}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Text(
                'Updated today',
                style: TextStyle(color: AppColors.textTertiary, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                current == null ? 'N/A' : current.value.toStringAsFixed(1),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              if (current != null) ...[
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${utility.unit} used',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _landscapeMetric(
                'vs last month',
                vsLastMonth == null
                    ? 'No data'
                    : '${vsLastMonth <= 0 ? '↓' : '↑'} ${vsLastMonth.abs().toStringAsFixed(1)}%',
                vsLastMonth == null
                    ? AppColors.textTertiary
                    : vsLastMonth <= 0
                        ? AppColors.success
                        : AppColors.critical,
              ),
              const SizedBox(width: 8),
              _landscapeMetric(
                'your average',
                average == null ? 'N/A' : '${average.toStringAsFixed(1)} ${utility.unit}',
                AppColors.textPrimary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Monthly consumption',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
              Text('Last 6 months',
                  style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: maxValue <= 0
                ? const Center(
                    child: Text(
                      'No readings yet — add your first month.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  )
                : BarChart(
                    BarChartData(
                      maxY: maxValue * 1.2,
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      barTouchData: BarTouchData(enabled: true),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 20,
                            getTitlesWidget: (value, meta) {
                              final index = value.round();
                              if (index < 0 || index >= months.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  _monthLabel(months[index]),
                                  style: const TextStyle(
                                    color: AppColors.textTertiary,
                                    fontSize: 10,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: List.generate(months.length, (index) {
                        final entry = values[index];
                        return BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: entry?.value ?? 0,
                              width: 18,
                              color: entry == null ? surface : accent,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _landscapeMetric(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.canvas,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AppColors.textTertiary, fontSize: 10)),
            const SizedBox(height: 2),
            Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _landscapeQuickActions(BuildContext context, UtilityType utility) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLowHeight = constraints.maxHeight < 270;
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Quick actions',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: isLowHeight ? 6 : 10),
              _landscapeAction(
                context,
                compact: isLowHeight,
                icon: Icons.add,
                label: 'Add a reading',
                onTap: () => showAddConsumptionFlow(context, utility: utility),
              ),
              SizedBox(height: isLowHeight ? 6 : 8),
              _landscapeAction(
                context,
                compact: isLowHeight,
            icon: Icons.report_problem_outlined,
            label: 'Report a problem',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ReportFlowScreen()),
            ),
              ),
              const Spacer(),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(isLowHeight ? 8 : 10),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_outline,
                        color: AppColors.success, size: 17),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'All systems normal',
                        style: TextStyle(
                          color: AppColors.success,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLowHeight) ...[
                const SizedBox(height: 10),
                const Text(
                  'Tip: record readings monthly for more accurate comparisons.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _landscapeAction(
    BuildContext context, {
    required bool compact,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.customerSurface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: compact ? 7 : 10),
          child: Row(
            children: [
              Icon(icon, color: AppColors.customerPrimary, size: 17),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _recordLog(UsageState usage, UtilityType utility, Color accent) {
    final records = usage.entries(utility).toList()
      ..sort((a, b) => b.periodMonth.compareTo(a.periodMonth));

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SectionLabel('RECORD LOG'),
                Text('${records.length} entr${records.length == 1 ? 'y' : 'ies'}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    )),
              ],
            ),
          ),
          if (records.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Center(
                child: Text(
                  'No entries logged yet.',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
            )
          else
            for (var i = 0; i < records.length; i++) ...[
              if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
              _RecordLogRow(
                entry: records[i],
                utility: utility,
                accent: accent,
              ),
            ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    final displayName = context.watch<RoleState>().displayName;

    return Container(
      width: double.infinity,
      color: AppColors.adminPrimary,
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 14,
        20,
        18,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_outline,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Good morning,',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    )),
                const SizedBox(height: 2),
                Text(displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    )),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const NotificationsScreen(),
                ),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.notifications_outlined,
                        color: Colors.white, size: 20),
                  ),
                  Positioned(
                    top: -3,
                    right: -3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.critical,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                            color: AppColors.adminPrimary, width: 1.5),
                      ),
                      child: const Text(
                        '2',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _utilityTabs(Color accent) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _sideAddButton(UtilityType.water),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _tabButton(
                    label: 'Water',
                    icon: Icons.water_drop_outlined,
                    selected: _tab.index == 0,
                    onTap: () => _tab.animateTo(0),
                    color: AppColors.waterAccent,
                  ),
                ),
                Expanded(
                  child: _tabButton(
                    label: 'Electricity',
                    icon: Icons.electric_bolt_outlined,
                    selected: _tab.index == 1,
                    onTap: () => _tab.animateTo(1),
                    color: AppColors.electricityAccent,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        _sideAddButton(UtilityType.electricity),
      ],
    );
  }

  Widget _sideAddButton(UtilityType utility) {
    final accent = utility == UtilityType.water
        ? AppColors.waterAccent
        : AppColors.electricityAccent;
    final icon = utility == UtilityType.water
        ? Icons.water_drop_outlined
        : Icons.electric_bolt_outlined;
    return Material(
      color: accent.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => showAddConsumptionFlow(context, utility: utility),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: accent),
              const SizedBox(width: 4),
              Icon(Icons.add, size: 14, color: accent),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabButton({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 16,
                color: selected ? color : AppColors.textTertiary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: selected ? color : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(UsageState usage, UtilityType utility, Color accent,
      Color surface) {
    final current = usage.currentMonthEntry(utility);
    final vsLastMonth = usage.percentVsLastMonth(utility);
    final vsAverage = usage.percentVsAverage(utility);
    final avg = usage.average(utility);
    final monthLabel = _monthLabel(DateTime.now());

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$monthLabel ${DateTime.now().year} · ${utility.label} Usage',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                current == null ? 'N/A' : current.value.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  height: 1.1,
                ),
              ),
              if (current != null) ...[
                const SizedBox(width: 4),
                Text(utility.unit,
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    )),
              ],
            ],
          ),
          const SizedBox(height: 8),
          _percentRow(
            icon: Icons.calendar_today_outlined,
            label: 'vs last month',
            percent: vsLastMonth,
          ),
          const SizedBox(height: 4),
          _percentRow(
            icon: Icons.trending_flat,
            label: 'vs your average',
            percent: vsAverage,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Text('Your average',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  )),
              const Spacer(),
              Text(
                avg == null
                    ? 'N/A'
                    : '${avg.toStringAsFixed(1)} ${utility.unit}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (current == null || avg == null || avg == 0)
                  ? 0.0
                  : (current.value / avg).clamp(0.0, 1.5) / 1.5,
              minHeight: 8,
              backgroundColor: surface,
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _percentRow({
    required IconData icon,
    required String label,
    required double? percent,
  }) {
    final hasValue = percent != null;
    final improving = hasValue && percent <= 0;
    final color = hasValue
        ? (improving ? AppColors.success : AppColors.critical)
        : AppColors.textTertiary;
    return Row(
      children: [
        Icon(
          hasValue
              ? (improving ? Icons.trending_down : Icons.trending_up)
              : Icons.remove,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          hasValue
              ? '${percent.toStringAsFixed(1)}% $label'
              : 'No data $label',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _monthlyChart(UsageState usage, UtilityType utility, Color accent,
      Color surface) {
    final months = _lastSixMonths();
    final values =
        months.map((m) => usage.entryForMonth(utility, m)).toList();
    final labels = months.map(_monthLabel).toList();
    final maxV = values
        .whereType<UtilityEntry>()
        .map((e) => e.value)
        .fold<double>(0, (a, b) => a > b ? a : b);
    final chartMax = maxV <= 0 ? 10.0 : maxV * 1.2;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SectionLabel('MONTHLY CONSUMPTION'),
              Text('last 6 months · ${utility.unit}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  )),
            ],
          ),
          const SizedBox(height: 12),
          if (maxV <= 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'No readings yet — tap "Add +" to log your first month.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
            )
          else
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  maxY: chartMax,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => AppColors.textPrimary,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final entry = values[group.x];
                        if (entry == null) return null;
                        return BarTooltipItem(
                          '${entry.value.toStringAsFixed(1)} ${utility.unit}',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        getTitlesWidget: (v, meta) {
                          final i = v.round();
                          if (i < 0 || i >= labels.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              labels[i],
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: List.generate(months.length, (i) {
                    final entry = values[i];
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: entry?.value ?? 0,
                          width: 22,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4),
                          ),
                          color: entry == null
                              ? surface
                              : accent.withValues(alpha: 0.75),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<DateTime> _lastSixMonths() {
    final now = DateTime.now();
    return List.generate(6, (i) {
      final monthsAgo = 5 - i;
      return DateTime(now.year, now.month - monthsAgo, 1);
    });
  }

  String _monthLabel(DateTime d) {
    const names = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return names[d.month - 1];
  }
}

class _RecordLogRow extends StatefulWidget {
  final UtilityEntry entry;
  final UtilityType utility;
  final Color accent;

  const _RecordLogRow({
    required this.entry,
    required this.utility,
    required this.accent,
  });

  @override
  State<_RecordLogRow> createState() => _RecordLogRowState();
}

class _RecordLogRowState extends State<_RecordLogRow> {
  bool _editing = false;
  bool _saving = false;
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        TextEditingController(text: widget.entry.value.toStringAsFixed(1));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = double.tryParse(_controller.text.trim());
    if (value == null || value < 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Enter a valid number'),
        backgroundColor: AppColors.critical,
      ));
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<UsageState>().addEntry(
            utility: widget.utility,
            value: value,
            month: widget.entry.periodMonth,
          );
      if (mounted) setState(() => _editing = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not save: $e'),
          backgroundColor: AppColors.critical,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _cancel() {
    _controller.text = widget.entry.value.toStringAsFixed(1);
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              _monthYearLabel(widget.entry.periodMonth),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: _editing
                ? TextField(
                    controller: _controller,
                    autofocus: true,
                    enabled: !_saving,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      suffixText: widget.utility.unit,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  )
                : Text(
                    '${widget.entry.value.toStringAsFixed(1)} ${widget.utility.unit}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          if (_saving)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (_editing) ...[
            IconButton(
              icon: const Icon(Icons.check, size: 18),
              color: AppColors.success,
              visualDensity: VisualDensity.compact,
              onPressed: _save,
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              color: AppColors.textTertiary,
              visualDensity: VisualDensity.compact,
              onPressed: _cancel,
            ),
          ] else
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              color: widget.accent,
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(() => _editing = true),
            ),
        ],
      ),
    );
  }
}
