import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../theme/tokens.dart';
import '../../auth/state/auth_state.dart';
import '../services/admin_tablet_layout.dart';
import '../../leakage/models/alert.dart';
import '../../leakage/models/report.dart';
import '../../leakage/screens/alert_evidence.dart';
import '../../leakage/screens/network_error.dart';
import '../../leakage/screens/report_view_screen.dart';
import '../../leakage/screens/style.dart';
import '../../leakage/state/app_state.dart';

/// Admin's read-only view of an alert: full evidence + linked investigation
/// reports, plus the false-positive gate (pending ↔ faults) when applicable.
/// Admin cannot investigate, write a report, or resolve an alert.
class AdminAlertDetailScreen extends StatefulWidget {
  final int alertId;
  const AdminAlertDetailScreen({super.key, required this.alertId});

  @override
  State<AdminAlertDetailScreen> createState() =>
      _AdminAlertDetailScreenState();
}

class _AdminAlertDetailScreenState extends State<AdminAlertDetailScreen> {
  bool _busy = false;

  Future<void> _toggleGate(AppState app, Alert alert) async {
    setState(() => _busy = true);
    final next = alert.status == AlertStatus.pending
        ? AlertStatus.faults
        : AlertStatus.pending;
    try {
      await app.updateAlertStatus(alert.id!, next,
          handledBy: context.read<RoleState>().displayName);
    } catch (_) {
      if (mounted) showNetworkErrorSnackBar(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final match = app.alerts.where((a) => a.id == widget.alertId);
    if (match.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Alert'),
          backgroundColor: AppColors.adminPrimary,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('This alert is no longer available.')),
      );
    }
    final alert = match.first;
    final reports =
        app.reports.where((r) => r.alertId == widget.alertId).toList();
    final date = DateFormat('d MMM y').format(alert.detectedAt);
    final subtitle = alertSubtitle(alert, date);
    final isPhoneLandscape =
        adminLayoutModeFor(MediaQuery.sizeOf(context)) ==
            AdminLayoutMode.phoneLandscape;

    if (isPhoneLandscape) {
      return _phoneLandscapeLayout(
        context,
        app,
        alert,
        reports,
        subtitle,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Text(alert.title),
        backgroundColor: AppColors.adminPrimary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          AppCard(
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
          ),
          const SizedBox(height: 10),
          AppCard(
            child: alertEvidence(context, app, alert),
          ),
          const SizedBox(height: 10),
          AppCard(
            background: const Color(0xFFF0FDF4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline,
                    size: 18, color: AppColors.adminPrimary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(alert.explanation,
                      style: const TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: AppColors.textPrimary)),
                ),
              ],
            ),
          ),
          if (reports.isNotEmpty) ...[
            const SizedBox(height: 16),
            const SectionLabel('INVESTIGATION REPORTS'),
            const SizedBox(height: 8),
            _reportsList(context, reports),
          ],
          const SizedBox(height: 10),
          _gateButton(app, alert),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _phoneLandscapeLayout(
    BuildContext context,
    AppState app,
    Alert alert,
    List<Report> reports,
    String subtitle,
  ) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Column(
          key: const Key('admin-alert-landscape-layout'),
          children: [
            SizedBox(
              height: 60,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Back to Oversight',
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        alert.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    statusPill(alert.status),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: ListView(
                        children: [
                          _landscapeOverview(alert, subtitle),
                          const SizedBox(height: 10),
                          _landscapeMetrics(alert),
                          const SizedBox(height: 10),
                          _landscapeContext(alert),
                          if (reports.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            const SectionLabel('INVESTIGATION REPORTS'),
                            const SizedBox(height: 8),
                            _reportsList(context, reports),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 210,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'STATUS ACTION',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _landscapeGateButton(app, alert),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.warningSurface,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Mark as fault only after confirming the detection is invalid.',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _landscapeOverview(Alert alert, String subtitle) => AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel('ANOMALY'),
            const SizedBox(height: 6),
            Text(
              alert.title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(subtitle,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      );

  Widget _landscapeMetrics(Alert alert) => AppCard(
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _landscapeMetric('Expected', '${alert.baselineL.round()} L/day'),
            _landscapeMetric('Actual', '${alert.actualL.round()} L/day'),
            _landscapeMetric(
              'Ratio',
              '${alert.ratio.toStringAsFixed(1)}× average',
            ),
          ],
        ),
      );

  Widget _landscapeMetric(String label, String value) => Container(
        width: 150,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.canvas,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
          ],
        ),
      );

  Widget _landscapeContext(Alert alert) => AppCard(
        background: const Color(0xFFF0FDF4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lightbulb_outline,
                size: 18, color: AppColors.adminPrimary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'System detection context',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(alert.explanation,
                      style: const TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: AppColors.textPrimary)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _reportsList(BuildContext context, List<Report> reports) {
    return Column(
      children: [
        for (final report in reports) ...[
          AppCard(
            padding: EdgeInsets.zero,
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color:
                        (report.isFixed ? AppColors.success : AppColors.warning)
                            .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    report.isFixed
                        ? Icons.check_circle_outline
                        : Icons.build_outlined,
                    color: report.isFixed
                        ? AppColors.success
                        : AppColors.warning,
                    size: 18,
                  ),
                ),
                title: Text('Report · ${ReportOutcome.label(report.outcome)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text(
                    report.findings.isEmpty
                        ? 'No findings recorded'
                        : report.findings,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                trailing: const Icon(Icons.chevron_right,
                    color: AppColors.textTertiary),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ReportViewScreen(
                        report: report, barColor: AppColors.adminPrimary))),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _gateButton(AppState app, Alert alert) {
    if (alert.status != AlertStatus.pending &&
        alert.status != AlertStatus.faults) {
      return const SizedBox.shrink();
    }
    final isFaults = alert.status == AlertStatus.faults;
    return OutlinedButton.icon(
      onPressed: _busy ? null : () => _toggleGate(app, alert),
      icon: _busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(isFaults ? Icons.undo : Icons.block,
              color: isFaults ? AppColors.adminPrimary : AppColors.critical),
      label: Text(
        isFaults ? 'Restore to Pending' : 'Mark as Fault',
        style: TextStyle(
            color: isFaults ? AppColors.adminPrimary : AppColors.critical,
            fontWeight: FontWeight.w600),
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        side: BorderSide(
            color: isFaults ? AppColors.adminPrimary : AppColors.critical),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _landscapeGateButton(AppState app, Alert alert) {
    if (alert.status != AlertStatus.pending &&
        alert.status != AlertStatus.faults) {
      return const SizedBox.shrink();
    }
    final isFaults = alert.status == AlertStatus.faults;
    final color = isFaults ? AppColors.adminPrimary : AppColors.critical;
    return FilledButton.icon(
      onPressed: _busy ? null : () => _toggleGate(app, alert),
      icon: _busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(isFaults ? Icons.undo : Icons.block),
      label: Text(isFaults ? 'Restore to Pending' : 'Mark as Fault'),
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
      ),
    );
  }
}
