import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/tokens.dart';
import '../../auth/state/auth_state.dart';
import '../models/utility_entry.dart';
import '../services/customer_compact_layout.dart';
import '../state/usage_state.dart';
import '../widgets/add_consumption_sheet.dart';
import '../widgets/logout_confirmation_dialog.dart';

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
          _greetingHeader(context, displayName),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
            child: _statusBanner(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: GestureDetector(
              onTap: onUsageTap,
              child: _myUsageCard(usage),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: _stateSelector(context, usage),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            child: _trendCardFor(usage, UtilityType.water),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            child: _trendCardFor(usage, UtilityType.electricity),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: _savingTipCard(),
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
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          child: Column(
            key: const PageStorageKey('customer-phone-landscape-home'),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'GOOD MORNING',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _notificationButton(),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => showAddConsumptionFlow(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.customerPrimary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add reading'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _landscapeStatusBanner(),
              const SizedBox(height: 12),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _landscapeUsageOverview(usage)),
                    const SizedBox(width: 12),
                    SizedBox(width: 238, child: _landscapeSidePanel(usage)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _notificationButton() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.divider),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.notifications_outlined,
            color: AppColors.textSecondary,
            size: 21,
          ),
        ),
        Positioned(
          top: -4,
          right: -4,
          child: Container(
            width: 17,
            height: 17,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.critical,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.canvas, width: 2),
            ),
            child: const Text(
              '2',
              style: TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _landscapeStatusBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.successSurface,
        border: Border.all(color: AppColors.success.withValues(alpha: 0.28)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle_outline, color: AppColors.success, size: 20),
          SizedBox(width: 8),
          Text(
            'All systems normal',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              'No anomalies detected this month',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _landscapeUsageOverview(UsageState usage) {
    final monthLabel = _monthLabel(DateTime.now()).toUpperCase();
    return GestureDetector(
      onTap: onUsageTap,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SectionLabel('MY USAGE · $monthLabel'),
                const Spacer(),
                const Icon(
                  Icons.arrow_forward,
                  size: 17,
                  color: AppColors.customerPrimary,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _landscapeUsageCell(usage, UtilityType.water),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _landscapeUsageCell(usage, UtilityType.electricity),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _landscapeUsageCell(UsageState usage, UtilityType utility) {
    final color = utility == UtilityType.water
        ? AppColors.waterAccent
        : AppColors.electricityAccent;
    final background = utility == UtilityType.water
        ? AppColors.waterSurface
        : AppColors.electricitySurface;
    final icon = utility == UtilityType.water
        ? Icons.water_drop_outlined
        : Icons.electric_bolt_outlined;
    final current = usage.currentMonthEntry(utility);
    final percent = usage.percentVsLastMonth(utility);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(height: 6),
          Text(
            utility.label.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
          const Spacer(),
          Text(
            current == null ? 'N/A' : current.value.toStringAsFixed(1),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            current == null ? 'No reading yet' : '${utility.unit} this month',
            overflow: TextOverflow.ellipsis,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 10),
          ),
          const SizedBox(height: 8),
          Text(
            percent == null
                ? 'No prior month'
                : '${percent.toStringAsFixed(1)}% vs last month',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: percent != null && percent <= 0
                  ? AppColors.success
                  : AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _landscapeSidePanel(UsageState usage) {
    return Column(
      children: [
        Expanded(
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('QUICK ACTIONS'),
                const SizedBox(height: 10),
                _landscapeAction(
                  icon: Icons.bar_chart_outlined,
                  title: 'Compare usage',
                  subtitle: 'View your household trend',
                  onTap: onUsageTap,
                ),
                const Divider(height: 20),
                _landscapeAction(
                  icon: Icons.account_balance_outlined,
                  title: usage.selectedState,
                  subtitle: 'Government comparison area',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lightbulb_outline, size: 18, color: Color(0xFFC2410C)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Turn off the tap while brushing to save up to 12 L per day.',
                  style: TextStyle(color: Color(0xFF9A3412), fontSize: 10),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _landscapeAction({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.customerSurface,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: AppColors.customerPrimary, size: 18),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: AppColors.textTertiary,
              ),
          ],
        ),
      ),
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

  Widget _greetingHeader(BuildContext context, String name) {
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
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_outline,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Good morning,',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Stack(
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
                      top: -2,
                      right: -2,
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
                IconButton(
                  icon:
                      const Icon(Icons.logout, color: Colors.white70, size: 20),
                  onPressed: () => showLogoutConfirmation(
                    context,
                    onConfirm: () => context.read<RoleState>().logout(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Material(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => showAddConsumptionFlow(context),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 18, color: Colors.white),
                      SizedBox(width: 6),
                      Text('Add +',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.successSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Icon(Icons.check_circle_outline,
                color: AppColors.success, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'All systems normal',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                Text(
                  'No anomalies detected this month',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _myUsageCard(UsageState usage) {
    final monthLabel = _monthLabel(DateTime.now());
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

  Widget _stateSelector(BuildContext context, UsageState usage) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.account_balance_outlined,
              size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Compared against government average for',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (!usage.hasProfileState)
                  const Text(
                    'Set your service address in Profile to personalize this',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textTertiary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            usage.selectedState,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _trendCardFor(UsageState usage, UtilityType utility) {
    final accent = utility == UtilityType.water
        ? AppColors.waterAccent
        : AppColors.electricityAccent;
    final months = _lastSixMonths();
    final labels = months.map(_monthLabel).toList();
    final userSeries = _monthlySeries(usage, utility, months);

    // Only show a government point for months the user actually logged.
    final govSeries = List<double?>.generate(months.length, (i) {
      if (userSeries[i] == null) return null;
      return usage.governmentMonthlyValue(utility, months[i]);
    });

    final baselineYear = utility == UtilityType.water
        ? usage.waterBaselineYear
        : usage.electricityBaselineYear;
    final hasGovData = govSeries.any((v) => v != null);

    final allValues =
        [...userSeries, ...govSeries].whereType<double>().toList();
    final minY = allValues.isEmpty
        ? 0.0
        : (allValues.reduce((a, b) => a < b ? a : b) * 0.85);
    final maxY = allValues.isEmpty
        ? 10.0
        : (allValues.reduce((a, b) => a > b ? a : b) * 1.15);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SectionLabel('${utility.label.toUpperCase()} · 6-MONTH TREND'),
              Wrap(
                spacing: 12,
                children: [
                  _legendDot(accent, 'You'),
                  if (hasGovData)
                    _legendDot(AppColors.textTertiary, 'Govt · $baselineYear'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 2),
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
                  'No readings yet — tap "Add +" to log your first month.',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
            )
          else
            SizedBox(
              height: 150,
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
                        reservedSize: 22,
                        interval: 1,
                        getTitlesWidget: (v, meta) {
                          final i = v.round();
                          if (i < 0 || i >= labels.length || i != v) {
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
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: false),
                  lineBarsData: [
                    _lineSeries(userSeries, accent),
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

  LineChartBarData _lineSeries(List<double?> values, Color color,
      {bool dashed = false}) {
    final spots = <FlSpot>[];
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      if (v != null) spots.add(FlSpot(i.toDouble(), v));
    }
    return LineChartBarData(
      isCurved: true,
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

  List<double?> _monthlySeries(
      UsageState usage, UtilityType utility, List<DateTime> months) {
    return months
        .map((month) => usage.entryForMonth(utility, month)?.value)
        .toList();
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
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return names[d.month - 1];
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

  Widget _savingTipCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline,
              color: const Color(0xFFC2410C), size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Saving Tip',
                    style: TextStyle(
                      color: Color(0xFFC2410C),
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    )),
                SizedBox(height: 2),
                Text(
                  'Turn off the tap while brushing — save up to 12 L per day.',
                  style: TextStyle(
                    color: Color(0xFF9A3412),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
