import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../theme/tokens.dart';
import '../services/admin_tablet_layout.dart';
import '../../leakage/models/alert.dart';
import '../../leakage/models/report.dart';
import '../../leakage/screens/alert_evidence.dart';
import '../../leakage/screens/report_view_screen.dart';
import '../../leakage/screens/style.dart';
import '../../leakage/state/app_state.dart';

/// Admin's read-only view of an alert: full evidence + linked investigation
/// reports. False positives are rejected from the Admin Review case before a
/// Worker alert exists; Admin cannot investigate, write a report, or resolve
/// a Worker alert.
class AdminAlertDetailScreen extends StatefulWidget {
  final int alertId;
  const AdminAlertDetailScreen({super.key, required this.alertId});

  @override
  State<AdminAlertDetailScreen> createState() => _AdminAlertDetailScreenState();
}

class _AdminAlertDetailScreenState extends State<AdminAlertDetailScreen> {
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
    final isPhoneLandscape = adminLayoutModeFor(MediaQuery.sizeOf(context)) ==
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
          const SizedBox(height: 10),
          AiAnalysisCard(alert: alert),
          if (reports.isNotEmpty) ...[
            const SizedBox(height: 16),
            const SectionLabel('INVESTIGATION REPORTS'),
            const SizedBox(height: 8),
            _reportsList(context, reports),
          ],
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
                          const Spacer(),
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
                    color:
                        report.isFixed ? AppColors.success : AppColors.warning,
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
}
