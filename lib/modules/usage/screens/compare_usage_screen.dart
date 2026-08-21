import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/tokens.dart';
import '../../auth/state/auth_state.dart';
import '../models/utility_entry.dart';
import '../services/customer_compact_layout.dart';
import '../state/usage_state.dart';
import '../widgets/add_consumption_sheet.dart';
import '../widgets/customer_header.dart';
import '../widgets/customer_landscape_scaffold.dart';

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
                CustomerHeader(
                  subtitle: 'Good morning,',
                  title: context.watch<RoleState>().displayName,
                  notificationCount: usage.notifications.length,
                ),
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
    return CustomerLandscapeScaffold(
      floatingActionButton: AddConsumptionFab(utility: utility),
      header: CustomerHeader(
        subtitle: 'Good morning,',
        title: context.watch<RoleState>().displayName,
        notificationCount: usage.notifications.length,
      ),
      children: [
        _utilityTabs(accent),
        _summaryCard(usage, utility, accent, surface),
        _monthlyChart(usage, utility, accent, surface),
        _recordLog(usage, utility, accent),
      ],
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

  Widget _utilityTabs(Color accent) {
    return Container(
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
