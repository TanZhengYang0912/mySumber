import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../theme/tokens.dart';
import '../models/report.dart';
import '../state/app_state.dart';
import '../widgets/adaptive_flow.dart';

/// Shared between the Worker's own report history and the Admin's Oversight
/// reports — [barColor] themes the AppBar to whichever role opened it,
/// instead of always showing the Worker's blue.
class ReportViewScreen extends StatelessWidget {
  final Report report;
  final Color barColor;
  const ReportViewScreen({
    super.key,
    required this.report,
    this.barColor = AppColors.workerPrimary,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedName = context.watch<AppState>().workerNames[report.workerId] ??
        report.workerName;
    final dateFormat = DateFormat('d MMM y, HH:mm');
    final isFixed = report.isFixed;
    final outcomeColor = isFixed ? AppColors.success : AppColors.critical;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Investigation Report'),
        backgroundColor: barColor,
        foregroundColor: Colors.white,
      ),
      body: AdaptiveFlow(
        builder: (full, half) => [
          SizedBox(
            width: full,
            child: _reporterCard(
                report, resolvedName, dateFormat, isFixed, outcomeColor),
          ),
          SizedBox(
            width: half,
            child: _section(
                'FINDINGS',
                report.findings.isEmpty
                    ? 'No findings recorded'
                    : report.findings),
          ),
          SizedBox(
            width: half,
            child: _section(
                'ACTION TAKEN',
                report.actionTaken.isEmpty
                    ? 'No action recorded'
                    : report.actionTaken),
          ),
          SizedBox(
            width: full,
            child: _outcomeCard(report, dateFormat, isFixed, outcomeColor),
          ),
        ],
      ),
    );
  }

  Widget _reporterCard(Report report, String resolvedName,
          DateFormat dateFormat, bool isFixed, Color outcomeColor) =>
      AppCard(
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: outcomeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isFixed ? Icons.check_circle_outline : Icons.build_outlined,
                color: outcomeColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Report by $resolvedName',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(dateFormat.format(report.createdAt),
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Pill(ReportOutcome.label(report.outcome), color: outcomeColor),
          ],
        ),
      );

  Widget _outcomeCard(Report report, DateFormat dateFormat, bool isFixed,
          Color outcomeColor) =>
      AppCard(
        background: outcomeColor.withValues(alpha: 0.07),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(isFixed ? Icons.check_circle : Icons.warning_amber,
                    color: outcomeColor, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isFixed
                        ? 'Issue resolved'
                        : 'Issue not resolved — follow-up needed',
                    style: TextStyle(
                        color: outcomeColor, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Last updated ${dateFormat.format(report.updatedAt)}',
              style:
                  const TextStyle(fontSize: 12, color: AppColors.textTertiary),
            ),
          ],
        ),
      );

  Widget _section(String label, String content) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(label),
          const SizedBox(height: 10),
          Text(content,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textPrimary, height: 1.5)),
        ],
      ),
    );
  }
}
