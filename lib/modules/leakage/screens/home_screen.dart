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
import '../widgets/adaptive_flow.dart';
import 'alert_detail_screen.dart';
import 'alert_queue_screen.dart';
import 'network_error.dart';
import 'report_history_screen.dart';
import 'style.dart';

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

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          _header(context),
          Expanded(
            child: AdaptiveFlow(
              builder: (full, half) => [
                SizedBox(
                  width: full,
                  child: _nextActionCard(
                    context,
                    summary.priorityAlert,
                    unresolved.length,
                    highCount,
                    mediumCount,
                    lowCount,
                  ),
                ),
                SizedBox(width: half, child: _workStatusCard(summary)),
                SizedBox(
                  width: half,
                  child: _reportHistoryCard(context, reports.length),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    // Short viewports (a phone held horizontally) get the same header with
    // tighter spacing rather than a second hand-written header tree.
    final compact = MediaQuery.sizeOf(context).height < 500;
    // Phone landscape swaps in WorkerCompactRail, which has its own Logout
    // destination — showing the header's Logout too would duplicate it.
    final showsLogoutInHeader =
        !usesWorkerPhoneLandscape(MediaQuery.sizeOf(context));

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _utilityPrimary,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.fromLTRB(20, compact ? 10 : 20, 20, compact ? 12 : 24),
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
                if (showsLogoutInHeader)
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
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 20 : 24,
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

  /// The single work card: what to do next, with the rest of the queue
  /// summarised underneath it.
  Widget _nextActionCard(
    BuildContext context,
    Alert? alert,
    int total,
    int high,
    int medium,
    int low,
  ) {
    final accent =
        alert == null ? AppColors.success : _severityColor(alert.severity);
    final surface = alert == null
        ? AppColors.successSurface
        : _severitySurface(alert.severity);

    return AppCard(
      background: surface,
      onTap: alert == null ? null : () => _openAlert(context, alert),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                alert == null
                    ? Icons.check_circle_outline
                    : Icons.assignment_late_outlined,
                color: accent,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SectionLabel('NEXT ACTION',
                    color: alert == null ? AppColors.success : null),
              ),
              if (alert != null)
                Pill(Severity.label(alert.severity), color: accent),
            ],
          ),
          const SizedBox(height: 10),
          if (alert == null)
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'All active alerts are clear',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'No field investigation is waiting for you.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            )
          else
            _nextActionDetails(context, alert, accent),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 10),
          _queueSummaryRow(context, total, high, medium, low),
        ],
      ),
    );
  }

  Widget _nextActionDetails(BuildContext context, Alert alert, Color accent) {
    final actionLabel = alert.status == AlertStatus.pending
        ? 'Start investigation'
        : alert.status == AlertStatus.notFixed
            ? 'Re-investigate'
            : 'Open alert';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _placeLabel(alert),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Row(
          children: [
            Pill(AlertStatus.label(alert.status),
                color: statusColor(alert.status)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                alertReasonLabel(alert),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
          ],
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
                backgroundColor: accent,
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
    );
  }

  Widget _queueSummaryRow(
    BuildContext context,
    int total,
    int high,
    int medium,
    int low,
  ) {
    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                total == 0 ? 'No unresolved alerts' : '$total unresolved',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
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
        ),
        const SizedBox(width: 8),
        TextButton.icon(
          onPressed: () => _openAlertQueue(context),
          icon: const Text('View all',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          label: const Icon(Icons.chevron_right, size: 18),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.workerPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
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
                  label: 'Not Fixed',
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
