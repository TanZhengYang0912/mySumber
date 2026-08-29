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

String _monthAbbr(int month) => _monthNames[month - 1];

class CustomerHomeScreen extends StatelessWidget {
  final VoidCallback? onUsageTap;
  const CustomerHomeScreen({super.key, this.onUsageTap});

  @override
  Widget build(BuildContext context) {
    final role = context.watch<RoleState>();
    final usage = context.watch<UsageState>();
    final displayName = role.displayName;

    if (usesCustomerPhoneLandscape(MediaQuery.sizeOf(context))) {
      return _phoneLandscapeHome(context, displayName, usage);
    }

    return Scaffold(
      backgroundColor: AppColors.canvas,
      floatingActionButton: const AddConsumptionFab(),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          CustomerHeader(
            subtitle: 'Good morning,',
            title: displayName,
            notificationCount: usage.notifications.length,
          ),
          const Padding(
            padding: EdgeInsets.only(top: 16, bottom: 6),
            child: _PromoCarousel(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: _usageVsStateHeading(usage),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            child: _TrendCard(usage: usage, utility: UtilityType.water),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            child: _TrendCard(usage: usage, utility: UtilityType.electricity),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: GestureDetector(
              onTap: onUsageTap,
              child: _myUsageCard(usage),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: SectionLabel('HOME EQUIPMENT'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _equipmentCard(
              icon: Icons.water_drop_outlined,
              color: AppColors.waterAccent,
              bg: AppColors.waterSurface,
              name: 'Water Meter',
              serial: 'WM-20482',
              active: usage.hasCurrentMonthEntry(UtilityType.water),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _equipmentCard(
              icon: Icons.electric_bolt_outlined,
              color: AppColors.electricityAccent,
              bg: AppColors.electricitySurface,
              name: 'Smart Meter',
              serial: 'SM-10921',
              active: usage.hasCurrentMonthEntry(UtilityType.electricity),
            ),
          ),
          const SizedBox(height: 88),
        ],
      ),
    );
  }

  Widget _phoneLandscapeHome(
    BuildContext context,
    String displayName,
    UsageState usage,
  ) {
    return CustomerLandscapeScaffold(
      floatingActionButton: const AddConsumptionFab(),
      header: CustomerHeader(
        subtitle: 'Good morning,',
        title: displayName,
        notificationCount: usage.notifications.length,
      ),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: const _PromoCarousel(),
        ),
        _usageVsStateHeading(usage),
        _TrendCard(usage: usage, utility: UtilityType.water),
        _TrendCard(usage: usage, utility: UtilityType.electricity),
        GestureDetector(onTap: onUsageTap, child: _myUsageCard(usage)),
        const SectionLabel('HOME EQUIPMENT'),
        _equipmentCard(
          icon: Icons.water_drop_outlined,
          color: AppColors.waterAccent,
          bg: AppColors.waterSurface,
          name: 'Water Meter',
          serial: 'WM-20482',
          active: usage.hasCurrentMonthEntry(UtilityType.water),
        ),
        _equipmentCard(
          icon: Icons.electric_bolt_outlined,
          color: AppColors.electricityAccent,
          bg: AppColors.electricitySurface,
          name: 'Smart Meter',
          serial: 'SM-10921',
          active: usage.hasCurrentMonthEntry(UtilityType.electricity),
        ),
      ],
    );
  }

  Widget _equipmentCard({
    required IconData icon,
    required Color color,
    required Color bg,
    required String name,
    required String serial,
    required bool active,
  }) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  serial,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            active ? 'Active' : 'Pending',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: active ? AppColors.success : AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _myUsageCard(UsageState usage) {
    final monthLabel = _monthAbbr(DateTime.now().month);
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SectionLabel('MY USAGE · ${monthLabel.toUpperCase()}'),
                const Icon(Icons.chevron_right,
                    color: AppColors.textTertiary, size: 20),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            child: Row(
              children: [
                Expanded(
                  child: _usageCell(usage, UtilityType.water),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _usageCell(usage, UtilityType.electricity),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _usageCell(UsageState usage, UtilityType utility) {
    final color = utility == UtilityType.water
        ? AppColors.waterAccent
        : AppColors.electricityAccent;
    final bg = utility == UtilityType.water
        ? AppColors.waterSurface
        : AppColors.electricitySurface;
    final icon = utility == UtilityType.water
        ? Icons.water_drop_outlined
        : Icons.electric_bolt_outlined;

    final current = usage.currentMonthEntry(utility);
    final percent = usage.percentVsLastMonth(utility);
    final hasTrend = percent != null;
    final trendPositive = hasTrend && percent <= 0;
    final trendColor = hasTrend
        ? (trendPositive ? AppColors.success : AppColors.critical)
        : AppColors.textTertiary;

    return Container(
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
              Text(
                utility.label.toUpperCase(),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            current == null ? 'N/A' : current.value.toStringAsFixed(1),
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            current == null ? 'no reading yet' : '${utility.unit} this month',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                hasTrend
                    ? (trendPositive ? Icons.trending_down : Icons.trending_up)
                    : Icons.remove,
                size: 14,
                color: trendColor,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  hasTrend
                      ? '${percent.toStringAsFixed(1)}% vs last month'
                      : 'No prior month',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: trendColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _usageVsStateHeading(UsageState usage) {
    const headingStyle = TextStyle(
      fontSize: 26,
      fontWeight: FontWeight.w900,
      height: 1.1,
    );
    return RichText(
      text: TextSpan(
        style: headingStyle.copyWith(color: AppColors.textPrimary),
        children: [
          TextSpan(
            text: 'My Usage',
            style: headingStyle.copyWith(color: AppColors.adminPrimary),
          ),
          const TextSpan(text: ' '),
          TextSpan(
            text: 'vs ',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          TextSpan(
            text: usage.selectedState,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const TextSpan(
            text: ' Trend:',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Sliding promo banner deck with small dot navigation. Full-bleed (no
/// side insets) in portrait; inset like the other cards in landscape, where
/// the phone-landscape scaffold applies a uniform side padding to every
/// list item.
class _PromoCarousel extends StatefulWidget {
  const _PromoCarousel();

  @override
  State<_PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<_PromoCarousel> {
  static const _images = [
    'assets/promo/banner_1.jpg',
    'assets/promo/banner_2.jpg',
    'assets/promo/banner_3.jpg',
  ];

  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: PageView.builder(
            controller: _controller,
            itemCount: _images.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) => Image.asset(
              _images[i],
              fit: BoxFit.cover,
              width: double.infinity,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_images.length, (i) {
            final selected = i == _page;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: selected ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: selected ? AppColors.customerPrimary : AppColors.divider,
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }
}

enum _TrendRange {
  monthly('Monthly', 6),
  yearly('Yearly', 12),
  fiveYear('5Y', 60),
  max('Max', null);

  final String label;
  final int? windowMonths;
  const _TrendRange(this.label, this.windowMonths);
}

/// Line-chart card for a single utility's usage trend, with a selectable
/// time range (Monthly/Yearly/5Y/Max) capped by however much history the
/// user actually has. Shows a friendly blank state when there are no
/// readings for this utility at all.
class _TrendCard extends StatefulWidget {
  const _TrendCard({required this.usage, required this.utility});

  final UsageState usage;
  final UtilityType utility;

  @override
  State<_TrendCard> createState() => _TrendCardState();
}

class _TrendCardState extends State<_TrendCard> {
  _TrendRange _range = _TrendRange.monthly;

  Color get _accent => widget.utility == UtilityType.water
      ? AppColors.waterAccent
      : AppColors.electricityAccent;

  int _monthDiff(DateTime a, DateTime b) =>
      (b.year - a.year) * 12 + (b.month - a.month);

  List<DateTime> _monthsForRange(List<UtilityEntry> utilityEntries) {
    if (utilityEntries.isEmpty) return const [];
    final sorted = [...utilityEntries]
      ..sort((a, b) => a.periodMonth.compareTo(b.periodMonth));
    final earliest = DateTime(
        sorted.first.periodMonth.year, sorted.first.periodMonth.month, 1);
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month, 1);
    final totalSpan = _monthDiff(earliest, currentMonth) + 1;
    final requested = _range.windowMonths ?? totalSpan;
    final window = requested > totalSpan ? totalSpan : requested;
    return List.generate(window, (i) {
      final monthsAgo = window - 1 - i;
      return DateTime(currentMonth.year, currentMonth.month - monthsAgo, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final utility = widget.utility;
    final usage = widget.usage;
    final utilityEntries = usage.entries(utility).toList();

    if (utilityEntries.isEmpty) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel('${utility.label.toUpperCase()} · TREND'),
            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  const Text('👋', style: TextStyle(fontSize: 28)),
                  const SizedBox(height: 8),
                  const Text(
                    "Hi! Let's start adding!",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Log your first ${utility.label.toLowerCase()} reading to see your trend here.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      );
    }

    final months = _monthsForRange(utilityEntries);
    final labels = months.map((d) => _monthAbbr(d.month)).toList();
    final userSeries =
        months.map((m) => usage.entryForMonth(utility, m)?.value).toList();

    // Only show a government point for months the user actually logged.
    final govSeries = List<double?>.generate(months.length, (i) {
      if (userSeries[i] == null) return null;
      return usage.governmentMonthlyValue(utility, months[i]);
    });

    final hasGovData = govSeries.any((v) => v != null);

    final allValues =
        [...userSeries, ...govSeries].whereType<double>().toList();
    final minY = allValues.isEmpty
        ? 0.0
        : (allValues.reduce((a, b) => a < b ? a : b) * 0.85);
    final maxY = allValues.isEmpty
        ? 10.0
        : (allValues.reduce((a, b) => a > b ? a : b) * 1.15);

    // Thin out x-axis labels once the range spans more than a year so
    // labels don't collide.
    final labelEvery = (months.length / 6).ceil().clamp(1, months.length);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SectionLabel('${utility.label.toUpperCase()} · TREND'),
              Wrap(
                spacing: 12,
                children: [
                  _legendDot(_accent, 'Me'),
                  if (hasGovData)
                    _legendDot(AppColors.textTertiary, 'Govt'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          _rangeToggle(),
          const SizedBox(height: 8),
          Text(
            'measured in ${utility.unit}',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textTertiary,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 12),
          if (allValues.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'No readings in this range yet.',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
            )
          else
            SizedBox(
              height: 162,
              child: LineChart(
                LineChartData(
                  minY: minY,
                  maxY: maxY,
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (v, meta) {
                          if (v == meta.min || v == meta.max) {
                            return const SizedBox.shrink();
                          }
                          return Text(
                            v.toStringAsFixed(0),
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textTertiary,
                            ),
                          );
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 1,
                        getTitlesWidget: (v, meta) {
                          final i = v.round();
                          if (i < 0 || i >= labels.length || i != v) {
                            return const SizedBox.shrink();
                          }
                          if (i % labelEvery != 0 && i != labels.length - 1) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${labels[i]}\n${months[i].year}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 10,
                                height: 1.15,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: false),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => AppColors.textPrimary,
                      getTooltipItems: (touchedSpots) {
                        final sorted = [...touchedSpots]
                          ..sort((a, b) => b.barIndex.compareTo(a.barIndex));
                        return sorted.map((spot) {
                          final isGov = spot.barIndex == 1;
                          final label = isGov ? usage.selectedState : 'Me';
                          return LineTooltipItem(
                            '$label: ${spot.y.round()}${utility.unit}',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  lineBarsData: [
                    _lineSeries(userSeries, _accent),
                    if (hasGovData)
                      _lineSeries(govSeries, AppColors.textTertiary,
                          dashed: true),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _rangeToggle() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: _TrendRange.values.map((range) {
          final selected = range == _range;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _range = range),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 7),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? _accent.withValues(alpha: 0.14) : null,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  range.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: selected ? _accent : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  LineChartBarData _lineSeries(List<double?> values, Color color,
      {bool dashed = false}) {
    final spots = <FlSpot>[];
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      if (v != null) spots.add(FlSpot(i.toDouble(), v));
    }
    return LineChartBarData(
      isCurved: false,
      color: color,
      barWidth: dashed ? 2 : 3,
      dashArray: dashed ? [6, 4] : null,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
          radius: dashed ? 3 : 4,
          color: color,
          strokeWidth: 0,
        ),
      ),
      belowBarData: BarAreaData(
        show: !dashed,
        color: color.withValues(alpha: 0.12),
      ),
      spots: spots,
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            )),
      ],
    );
  }
}
