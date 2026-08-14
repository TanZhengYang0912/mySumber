import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../theme/tokens.dart';
import '../../auth/state/auth_state.dart';
import '../models/alert.dart';
import '../services/worker_compact_layout.dart';
import '../services/worker_dashboard_summary.dart';
import '../services/worker_investigation_flow.dart';
import '../services/worker_utility_colors.dart';
import '../state/app_state.dart';
import 'alert_detail_screen.dart';
import 'alert_queue_screen.dart';
import 'network_error.dart';
import 'report_history_screen.dart';

class HomeScreen extends StatelessWidget {
  final Utility utility;
  const HomeScreen({super.key, this.utility = Utility.water});

  bool get _isWater => utility == Utility.water;

  Color get _utilityPrimary => workerUtilityPrimary(utility);

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

    final summary = summarizeWorkerDashboard(
      alerts: app.alerts,
      utility: utility,
    );

    if (usesWorkerPhoneLandscape(MediaQuery.sizeOf(context))) {
      return _phoneLandscapeHome(
        context,
        summary,
        unresolved.length,
        highCount,
        mediumCount,
        lowCount,
        reports.length,
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
            child: _priorityActionCard(context, summary.priorityAlert),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: _workStatusCard(summary),
          ),
          if (summary.impactAlert != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: _impactSnapshotCard(summary.impactAlert!),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _phoneLandscapeHome(
    BuildContext context,
    WorkerDashboardSummary summary,
    int total,
    int high,
    int medium,
    int low,
    int reportCount,
  ) {
    return Scaffold(
      backgroundColor: _utilityPrimary,
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
                      _priorityActionCard(context, summary.priorityAlert),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _workStatusCard(summary)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: summary.impactAlert == null
                                ? _landscapeEntryCard(
                                    context,
                                    icon: Icons.insights_outlined,
                                    iconColor: _utilityPrimary,
                                    title: 'Impact Snapshot',
                                    description: 'No active impact data',
                                    actionLabel: 'View queue',
                                    actionColor: _utilityPrimary,
                                    onTap: () => _openAlertQueue(context),
                                  )
                                : _impactSnapshotCard(summary.impactAlert!),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
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
                              iconColor: _utilityPrimary,
                              title: 'Report History',
                              description: reportCount == 0
                                  ? 'No reports submitted yet'
                                  : '$reportCount reports submitted',
                              actionLabel: 'View history',
                              actionColor: _utilityPrimary,
                              onTap: () => _openReportHistory(context),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _landscapeEntryCard(
                              context,
                              icon: Icons.refresh_outlined,
                              iconColor: AppColors.critical,
                              title: 'Follow-up Work',
                              description: summary.followUpCount == 0
                                  ? 'No unresolved follow-ups'
                                  : '${summary.followUpCount} alerts need another visit',
                              actionLabel: 'View queue',
                              onTap: () => _openAlertQueue(context),
                            ),
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
        color: _utilityPrimary,
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

  void _openAlert(BuildContext context, Alert alert) {
    if (alert.id == null) {
      _openAlertQueue(context);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AlertDetailScreen(alertId: alert.id!),
      ),
    );
  }

  Future<void> _startInvestigation(BuildContext context, Alert alert) async {
    if (alert.id == null) {
      _openAlert(context, alert);
      return;
    }
    try {
      await context
          .read<AppState>()
          .updateAlertStatus(alert.id!, AlertStatus.investigating);
      if (context.mounted) {
        if (shouldOpenAlertDetailsAfterInvestigationStart(alert.status)) {
          _openAlert(context, alert);
        }
      }
    } catch (_) {
      if (context.mounted) showNetworkErrorSnackBar(context);
    }
  }

  Widget _priorityActionCard(BuildContext context, Alert? alert) {
    if (alert == null) {
      return AppCard(
        background: AppColors.successSurface,
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: AppColors.success,
              child: Icon(Icons.check, color: Colors.white),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionLabel('NEXT ACTION', color: AppColors.success),
                  SizedBox(height: 4),
                  Text(
                    'All active alerts are clear',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'No field investigation is waiting for you.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.check_circle_outline, color: AppColors.success),
          ],
        ),
      );
    }

    final severityColor = _severityColor(alert.severity);
    final severitySurface = _severitySurface(alert.severity);
    final place = _placeLabel(alert);
    final equipment = alert.equipmentName ?? alert.signature;
    final actionLabel = alert.status == AlertStatus.pending
        ? 'Start investigation'
        : alert.status == AlertStatus.notFixed
            ? 'Re-investigate'
            : 'Open alert';

    return AppCard(
      background: severitySurface,
      onTap: () => _openAlert(context, alert),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.assignment_late_outlined,
                  color: severityColor, size: 22),
              const SizedBox(width: 8),
              const Expanded(child: SectionLabel('NEXT ACTION')),
              Pill(Severity.label(alert.severity), color: severityColor),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            place,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '$equipment · ${_alertTypeLabel(alert)}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Flagged ${DateFormat('d MMM y').format(alert.detectedAt)}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: () => alert.status == AlertStatus.pending
                    ? _startInvestigation(context, alert)
                    : _openAlert(context, alert),
                icon: Icon(
                  alert.status == AlertStatus.pending
                      ? Icons.play_arrow
                      : Icons.chevron_right,
                  size: 17,
                ),
                label: Text(actionLabel),
                style: FilledButton.styleFrom(
                  backgroundColor: severityColor,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _workStatusCard(WorkerDashboardSummary summary) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('WORK STATUS'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: StatCell(
                  compact: true,
                  icon: Icons.inbox_outlined,
                  iconColor: AppColors.warning,
                  value: '${summary.pendingCount}',
                  label: 'Pending',
                  background: AppColors.warningSurface,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatCell(
                  compact: true,
                  icon: Icons.engineering_outlined,
                  iconColor: AppColors.workerPrimary,
                  value: '${summary.investigatingCount}',
                  label: 'Investigating',
                  background: AppColors.workerSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: StatCell(
                  compact: true,
                  icon: Icons.refresh_outlined,
                  iconColor: AppColors.critical,
                  value: '${summary.followUpCount}',
                  label: 'Follow-up',
                  background: AppColors.criticalSurface,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatCell(
                  compact: true,
                  icon: Icons.check_circle_outline,
                  iconColor: AppColors.success,
                  value: '${summary.resolvedCount}',
                  label: 'Resolved',
                  background: AppColors.successSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _impactSnapshotCard(Alert alert) {
    final isHousehold = alert.alertType == AlertType.household;
    final unit = alert.isNrw ? 'MLD' : 'GWh';
    final place = _placeLabel(alert);
    final title = isHousehold
        ? '${alert.actualL.round()} L/day actual'
        : '${(alert.lossMld ?? 0).round()} $unit lost';
    final detail = isHousehold
        ? '${alert.ratio.toStringAsFixed(1)}× expected usage'
        : '${(alert.lossPct ?? 0).toStringAsFixed(1)}% of supply';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_outlined, color: _utilityPrimary, size: 20),
              const SizedBox(width: 8),
              const SectionLabel('IMPACT SNAPSHOT'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            place,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '$title · $detail',
            style: const TextStyle(
              color: AppColors.critical,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (alert.facilityName != null || alert.equipmentName != null) ...[
            const SizedBox(height: 3),
            Text(
              [alert.facilityName, alert.equipmentName]
                  .whereType<String>()
                  .join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _severityColor(String severity) {
    switch (severity) {
      case Severity.high:
        return AppColors.critical;
      case Severity.medium:
        return const Color(0xFFB45309);
      default:
        return AppColors.workerPrimary;
    }
  }

  Color _severitySurface(String severity) {
    switch (severity) {
      case Severity.high:
        return AppColors.criticalSurface;
      case Severity.medium:
        return AppColors.warningSurface;
      default:
        return AppColors.workerSurface;
    }
  }

  String _placeLabel(Alert alert) {
    if (alert.alertType == AlertType.household) {
      return '${alert.state} · ${alert.householdId ?? 'Household'}';
    }
    return [alert.state, alert.facilityCity].whereType<String>().join(' · ');
  }

  String _alertTypeLabel(Alert alert) {
    switch (alert.alertType) {
      case AlertType.nrwHotspot:
        return 'NRW hotspot';
      case AlertType.electricityHotspot:
        return 'Electricity loss';
      case AlertType.electricityTampering:
        return 'Potential tampering';
      default:
        return alert.signature;
    }
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
    Color? actionColor,
    required String title,
    required String description,
    required String actionLabel,
    required VoidCallback onTap,
  }) {
    final resolvedActionColor = actionColor ?? AppColors.workerPrimary;
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
                  style: TextStyle(
                    color: resolvedActionColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(Icons.chevron_right, color: resolvedActionColor, size: 18),
              ],
            ),
          ],
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
}
