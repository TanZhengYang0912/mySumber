import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../theme/tokens.dart';
import '../../auth/state/auth_state.dart';
import '../models/alert.dart';
import '../services/worker_compact_layout.dart';
import '../state/app_state.dart';
import 'alert_detail_screen.dart';
import 'alert_queue_screen.dart';
import 'report_history_screen.dart';

class HomeScreen extends StatelessWidget {
  final Utility utility;
  const HomeScreen({super.key, this.utility = Utility.water});

  bool get _isWater => utility == Utility.water;

  Color get _primary => AppColors.workerPrimary;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (app.loading) {
      return const Scaffold(
        backgroundColor: AppColors.canvas,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final unresolved = app.unresolvedFor(utility);
    final reports = app.reportsFor(utility);
    final highCount =
        unresolved.where((a) => a.severity == Severity.high).length;
    final mediumCount =
        unresolved.where((a) => a.severity == Severity.medium).length;
    final lowCount = unresolved.where((a) => a.severity == Severity.low).length;

    final latestAlert = unresolved.isNotEmpty ? unresolved.first : null;

    if (usesWorkerPhoneLandscape(MediaQuery.sizeOf(context))) {
      return _phoneLandscapeHome(
        context,
        unresolved.length,
        highCount,
        mediumCount,
        lowCount,
        reports.length,
        latestAlert,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _header(context),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: _alertQueueCard(
              context,
              unresolved.length,
              highCount,
              mediumCount,
              lowCount,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: _reportHistoryCard(context, reports.length),
          ),
          if (latestAlert != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: _latestAlertCard(context, latestAlert),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _phoneLandscapeHome(
    BuildContext context,
    int total,
    int high,
    int medium,
    int low,
    int reportCount,
    Alert? latestAlert,
  ) {
    return Scaffold(
      backgroundColor: _primary,
      body: SafeArea(
        left: false,
        right: false,
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 16, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'mySumber · WORKER',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isWater
                              ? 'Water Monitoring'
                              : 'Electricity Monitoring',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.notifications_none_outlined,
                      color: Colors.white, size: 24),
                ],
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: AppColors.canvas,
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(22)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _landscapeAlertQueue(
                        context,
                        total,
                        high,
                        medium,
                        low,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _landscapeEntryCard(
                              context,
                              icon: Icons.description_outlined,
                              iconColor: _primary,
                              title: 'Report History',
                              description: reportCount == 0
                                  ? 'No reports submitted yet'
                                  : '$reportCount reports submitted',
                              actionLabel: 'View history',
                              onTap: () => _openReportHistory(context),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: latestAlert == null
                                ? _landscapeEntryCard(
                                    context,
                                    icon: Icons.check_circle_outline,
                                    iconColor: AppColors.success,
                                    title: 'Latest Alert',
                                    description: 'No unresolved alerts',
                                    actionLabel: 'View queue',
                                    onTap: () => _openAlertQueue(context),
                                  )
                                : _landscapeLatestAlertCard(
                                    context, latestAlert),
                          ),
                        ],
                      ),
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

  Widget _header(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _primary,
        borderRadius: const BorderRadius.only(
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
                    'mySumber · WORKER',
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
            const SizedBox(height: 4),
            Text(
              _isWater ? 'Water Monitoring' : 'Electricity Monitoring',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openAlertQueue(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AlertQueueScreen(utility: utility)),
    );
  }

  void _openReportHistory(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReportHistoryScreen(utility: utility),
      ),
    );
  }

  Widget _landscapeAlertQueue(
    BuildContext context,
    int total,
    int high,
    int medium,
    int low,
  ) {
    final resolved = total == 0;
    final accent = resolved ? AppColors.success : AppColors.critical;
    final background =
        resolved ? AppColors.successSurface : AppColors.criticalSurface;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      background: background,
      onTap: () => _openAlertQueue(context),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            child: const Icon(Icons.notifications_active_outlined,
                color: Colors.white, size: 19),
          ),
          const SizedBox(width: 10),
          Text(
            '$total',
            style: TextStyle(
              color: accent,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'unresolved',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (high > 0) Pill('$high high', color: AppColors.critical),
                  if (medium > 0)
                    Pill(
                      '$medium medium',
                      color: const Color(0xFFB45309),
                      background: AppColors.warningSurface,
                    ),
                  if (low > 0)
                    Pill(
                      '$low low',
                      color: AppColors.workerPrimary,
                      background: AppColors.workerSurface,
                    ),
                ],
              ),
            ),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              minimumSize: const Size(78, 38),
            ),
            onPressed: () => _openAlertQueue(context),
            icon: const Icon(Icons.chevron_right, size: 18),
            label: const Text('View'),
          ),
        ],
      ),
    );
  }

  Widget _landscapeEntryCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required String actionLabel,
    required VoidCallback onTap,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: SizedBox(
        height: 108,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Text(
                  actionLabel,
                  style: const TextStyle(
                    color: AppColors.workerPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(Icons.chevron_right,
                    color: AppColors.workerPrimary, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _landscapeLatestAlertCard(BuildContext context, Alert alert) {
    final sevColor = alert.severity == Severity.high
        ? AppColors.critical
        : alert.severity == Severity.medium
            ? const Color(0xFFB45309)
            : AppColors.workerPrimary;
    final sevLabel = alert.severity == Severity.high
        ? 'High severity'
        : alert.severity == Severity.medium
            ? 'Medium severity'
            : 'Low severity';

    return _landscapeEntryCard(
      context,
      icon: Icons.notifications_active_outlined,
      iconColor: sevColor,
      title: 'Latest Alert',
      description: '${alert.title} · $sevLabel',
      actionLabel: 'Open alert',
      onTap: alert.id == null
          ? () => _openAlertQueue(context)
          : () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AlertDetailScreen(alertId: alert.id!),
                ),
              ),
    );
  }

  Widget _alertQueueCard(
    BuildContext context,
    int total,
    int high,
    int medium,
    int low,
  ) {
    final resolved = total == 0;
    final accent = resolved ? AppColors.success : AppColors.critical;
    final background =
        resolved ? AppColors.successSurface : AppColors.criticalSurface;

    return AppCard(
      background: background,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => AlertQueueScreen(utility: utility)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.notifications_active_outlined,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child:
                    SectionLabel('ALERT QUEUE', color: AppColors.textPrimary),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('View',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                    SizedBox(width: 2),
                    Icon(Icons.chevron_right, color: Colors.white, size: 18),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '$total',
            style: TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w800,
              color: accent,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            resolved
                ? 'All alerts resolved'
                : 'Unresolved alerts need attention',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (total > 0) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (high > 0) Pill('$high high', color: AppColors.critical),
                if (medium > 0)
                  Pill('$medium medium',
                      color: const Color(0xFFB45309),
                      background: AppColors.warningSurface),
                if (low > 0)
                  Pill('$low low',
                      color: AppColors.workerPrimary,
                      background: AppColors.workerSurface),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _reportHistoryCard(BuildContext context, int count) {
    return AppCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ReportHistoryScreen(utility: utility),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.workerSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.description_outlined,
                color: AppColors.workerPrimary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('REPORT HISTORY'),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('$count',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          height: 1,
                          color: AppColors.textPrimary,
                        )),
                    const SizedBox(width: 8),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Text(
                        'Total reports submitted',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textTertiary),
        ],
      ),
    );
  }

  Widget _latestAlertCard(BuildContext context, Alert alert) {
    final sev = alert.severity;
    Color sevColor;
    Color sevBg;
    String sevLabel;
    if (sev == Severity.high) {
      sevColor = AppColors.critical;
      sevBg = AppColors.criticalSurface;
      sevLabel = 'High Severity';
    } else if (sev == Severity.medium) {
      sevColor = const Color(0xFFB45309);
      sevBg = AppColors.warningSurface;
      sevLabel = 'Medium Severity';
    } else {
      sevColor = AppColors.workerPrimary;
      sevBg = AppColors.workerSurface;
      sevLabel = 'Low Severity';
    }

    final typeLabel = alert.alertType == AlertType.household
        ? 'Household'
        : alert.alertType == AlertType.nrwHotspot
            ? 'NRW Hotspot'
            : alert.alertType == AlertType.electricityHotspot
                ? 'Electricity Loss'
                : 'Tampering';

    return AppCard(
      onTap: alert.id == null
          ? null
          : () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AlertDetailScreen(alertId: alert.id!),
                ),
              ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.schedule, color: AppColors.warning, size: 16),
              SizedBox(width: 6),
              SectionLabel('LATEST ALERT'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Flagged ${DateFormat('d MMM').format(alert.detectedAt)} · $typeLabel',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Pill(sevLabel, color: sevColor, background: sevBg),
            ],
          ),
        ],
      ),
    );
  }
}
