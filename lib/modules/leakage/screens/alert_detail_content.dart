import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../theme/tokens.dart';
import '../models/alert.dart';
import '../models/report.dart';
import '../state/app_state.dart';
import 'alert_evidence.dart';
import 'report_view_screen.dart';
import 'style.dart';

/// The single, responsive information template shared by Admin and Worker.
/// Roles provide their own fixed actions outside this scrollable content.
class AlertDetailContent extends StatelessWidget {
  const AlertDetailContent({
    super.key,
    required this.app,
    required this.alert,
    required this.reports,
    required this.primary,
    required this.canGenerateAi,
  });

  final AppState app;
  final Alert alert;
  final List<Report> reports;
  final Color primary;
  final bool canGenerateAi;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('d MMM y').format(alert.detectedAt);
    final subtitle = alertSubtitle(alert, date);

    return ListView(
      key: const ValueKey('shared-alert-detail-content'),
      padding: const EdgeInsets.all(14),
      children: [
        AppCard(
          key: const ValueKey('alert-detail-summary-card'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                severityPill(alert.severity),
                const SizedBox(width: 8),
                statusPill(alert.status),
              ]),
              const SizedBox(height: 8),
              Text(
                alert.title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        AppCard(
          key: const ValueKey('alert-detail-evidence-card'),
          child: alertEvidence(context, app, alert),
        ),
        const SizedBox(height: 10),
        AppCard(
          key: const ValueKey('alert-detail-context-card'),
          background: const Color(0xFFF0FDF4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lightbulb_outline, size: 18, color: primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  alert.explanation,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        AiAnalysisCard(alert: alert, canGenerate: canGenerateAi),
        if (reports.isNotEmpty) ...[
          const SizedBox(height: 16),
          const SectionLabel('INVESTIGATION REPORTS'),
          const SizedBox(height: 8),
          _reportsList(context),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _reportsList(BuildContext context) {
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
                title: Text(
                  'Report · ${ReportOutcome.label(report.outcome)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  report.findings.isEmpty
                      ? 'No findings recorded'
                      : report.findings,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: AppColors.textTertiary,
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ReportViewScreen(
                      report: report,
                      barColor: primary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
