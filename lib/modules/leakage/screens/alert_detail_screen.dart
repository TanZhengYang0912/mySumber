import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../theme/tokens.dart';
import '../../auth/state/auth_state.dart';
import '../models/alert.dart';
import '../models/report.dart';
import '../state/app_state.dart';
import '../widgets/adaptive_flow.dart';
import 'alert_evidence.dart';
import 'network_error.dart';
import 'report_form_screen.dart';
import 'report_view_screen.dart';
import 'style.dart';

class AlertDetailScreen extends StatelessWidget {
  final int alertId;
  const AlertDetailScreen({super.key, required this.alertId});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final match = app.alerts.where((a) => a.id == alertId);
    if (match.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Alert'),
          backgroundColor: AppColors.workerPrimary,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('This alert is no longer available.')),
      );
    }
    final alert = match.first;
    final reports = _reportsFor(app, alertId);
    final date = DateFormat('d MMM y').format(alert.detectedAt);
    final subtitle = alertSubtitle(alert, date);
    const primary = AppColors.workerPrimary;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Text(alert.title),
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      body: AdaptiveFlow(
        builder: (full, half) => [
          SizedBox(width: full, child: _summaryCard(alert, subtitle)),
          SizedBox(
            width: half,
            child: AppCard(child: alertEvidence(context, app, alert)),
          ),
          SizedBox(width: half, child: _detectionContextCard(alert)),
          SizedBox(
            width: full,
            child: _actions(context, app, alert, reports, primary),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(Alert alert, String subtitle) => AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              severityPill(alert.severity),
              const SizedBox(width: 8),
              statusPill(alert.status),
            ]),
            const SizedBox(height: 8),
            Text(alert.title,
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text(subtitle,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      );

  Widget _detectionContextCard(Alert alert) => AppCard(
        background: const Color(0xFFF0F9FF),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lightbulb_outline,
                    size: 18, color: AppColors.workerPrimary),
                const SizedBox(width: 8),
                const Text(
                  'System Detection Context',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(alert.explanation,
                style: const TextStyle(
                    fontSize: 13, height: 1.5, color: AppColors.textPrimary)),
            if (alert.hasAiAnalysis) ...[
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.divider),
              Material(
                color: Colors.transparent,
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.fromLTRB(0, 0, 0, 4),
                  leading: const Icon(Icons.auto_awesome_outlined,
                      size: 18, color: AppColors.workerPrimary),
                  title: const Text(
                    'AI Assessment',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  children: [_aiAssessmentDetails(alert)],
                ),
              ),
            ],
          ],
        ),
      );

  Widget _aiValue(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontSize: 12, height: 1.35, color: AppColors.textPrimary)),
        ],
      );

  Widget _aiAssessmentDetails(Alert alert) => SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'AI-generated. Verify on site.',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            _aiValue('Summary', alert.aiSummary!),
            const SizedBox(height: 8),
            _aiValue('Possible cause', alert.aiPossibleCause!),
            const SizedBox(height: 8),
            _aiValue('Recommendation', alert.aiRecommendation!),
            const SizedBox(height: 8),
            _aiValue(
              'Confidence',
              '${(alert.aiConfidence! * 100).round()}%',
            ),
          ],
        ),
      );

  Future<void> _updateStatus(
      BuildContext context, AppState app, int alertId, String status) async {
    final role = context.read<RoleState>();
    try {
      await app.updateAlertStatus(alertId, status,
          handledBy: role.displayName, handledById: role.userId);
    } catch (_) {
      if (context.mounted) showNetworkErrorSnackBar(context);
    }
  }

  List<Report> _reportsFor(AppState app, int alertId) =>
      app.reports.where((r) => r.alertId == alertId).toList();

  Widget _actions(BuildContext context, AppState app, Alert alert,
      List<Report> reports, Color primary) {
    final children = <Widget>[];

    for (final report in reports) {
      children.add(AppCard(
        padding: EdgeInsets.zero,
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: (report.isFixed ? AppColors.success : AppColors.warning)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              report.isFixed
                  ? Icons.check_circle_outline
                  : Icons.build_outlined,
              color: report.isFixed ? AppColors.success : AppColors.warning,
              size: 18,
            ),
          ),
          title: Text('Report · ${ReportOutcome.label(report.outcome)}',
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          subtitle: Text(
              report.findings.isEmpty
                  ? 'No findings recorded'
                  : report.findings,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
          trailing:
              const Icon(Icons.chevron_right, color: AppColors.textTertiary),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ReportViewScreen(report: report))),
        ),
      ));
      children.add(const SizedBox(height: 10));
    }

    if (alert.status == AlertStatus.pending) {
      children.add(_primaryBtn(
          context,
          'Start Investigation',
          Icons.play_arrow,
          primary,
          () => _updateStatus(
              context, app, alert.id!, AlertStatus.investigating)));
    } else if (alert.status == AlertStatus.investigating) {
      final currentUserId = context.read<RoleState>().userId;
      if (alertLockedForUser(alert, currentUserId)) {
        children.add(AppCard(
          child: Row(
            children: [
              const Icon(Icons.lock_outline,
                  size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Being investigated by '
                  '${app.workerNames[alert.handledById] ?? alert.handledBy} — '
                  'only they can '
                  'submit a report.',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ));
      } else {
        children.add(
            _primaryBtn(context, 'Write Report', Icons.edit_note, primary, () {
          Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ReportFormScreen(alert: alert)));
        }));
      }
    } else if (alert.status == AlertStatus.notFixed) {
      children.add(_primaryBtn(
          context,
          'Re-Investigate',
          Icons.refresh,
          primary,
          () => _updateStatus(
              context, app, alert.id!, AlertStatus.investigating)));
    }

    if (children.isEmpty) return const SizedBox.shrink();
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }

  Widget _primaryBtn(BuildContext context, String label, IconData icon,
      Color color, VoidCallback onTap) {
    return FilledButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: color,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
