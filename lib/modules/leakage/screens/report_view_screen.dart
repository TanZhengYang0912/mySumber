import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../theme/tokens.dart';
import '../models/report.dart';
import '../services/worker_compact_layout.dart';

class ReportViewScreen extends StatelessWidget {
  final Report report;
  const ReportViewScreen({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d MMM y, HH:mm');
    final isFixed = report.isFixed;
    final outcomeColor = isFixed ? AppColors.success : AppColors.critical;
    final isPhoneLandscape =
        usesWorkerPhoneLandscape(MediaQuery.sizeOf(context));

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Text(
            isPhoneLandscape ? 'Investigation report' : 'Investigation Report'),
        backgroundColor: AppColors.workerPrimary,
        foregroundColor: Colors.white,
      ),
      body: isPhoneLandscape
          ? _phoneLandscapeBody(report, dateFormat, isFixed, outcomeColor)
          : ListView(
              padding: const EdgeInsets.all(14),
              children: [
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
                          isFixed
                              ? Icons.check_circle_outline
                              : Icons.build_outlined,
                          color: outcomeColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Report by ${report.workerName}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary)),
                            const SizedBox(height: 2),
                            Text(dateFormat.format(report.createdAt),
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      Pill(ReportOutcome.label(report.outcome),
                          color: outcomeColor),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _section(
                    'FINDINGS',
                    report.findings.isEmpty
                        ? 'No findings recorded'
                        : report.findings),
                const SizedBox(height: 10),
                _section(
                    'ACTION TAKEN',
                    report.actionTaken.isEmpty
                        ? 'No action recorded'
                        : report.actionTaken),
                const SizedBox(height: 10),
                AppCard(
                  background: outcomeColor.withValues(alpha: 0.07),
                  child: Row(
                    children: [
                      Icon(isFixed ? Icons.check_circle : Icons.warning_amber,
                          color: outcomeColor, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        isFixed
                            ? 'Issue resolved'
                            : 'Issue not resolved — follow-up needed',
                        style: TextStyle(
                            color: outcomeColor, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'Last updated ${dateFormat.format(report.updatedAt)}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textTertiary),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _phoneLandscapeBody(
    Report report,
    DateFormat dateFormat,
    bool isFixed,
    Color outcomeColor,
  ) {
    final findings =
        report.findings.isEmpty ? 'No findings recorded' : report.findings;
    final action =
        report.actionTaken.isEmpty ? 'No action recorded' : report.actionTaken;
    final resolution = isFixed ? 'Resolved' : 'Follow-up needed';

    return Semantics(
      key: const Key('worker-report-landscape-workspace'),
      label: 'Landscape report workspace',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: outcomeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isFixed
                          ? Icons.check_circle_outline
                          : Icons.build_outlined,
                      color: outcomeColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Report by ${report.workerName}',
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
                  Pill(ReportOutcome.label(report.outcome),
                      color: outcomeColor),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.divider),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _landscapeSection('FINDINGS', findings)),
                  const VerticalDivider(
                      width: 28, thickness: 1, color: AppColors.divider),
                  Expanded(child: _landscapeSection('ACTION TAKEN', action)),
                ],
              ),
              const Divider(height: 1, color: AppColors.divider),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(isFixed ? Icons.check_circle : Icons.warning_amber,
                      color: outcomeColor, size: 18),
                  const SizedBox(width: 8),
                  Text(resolution,
                      style: TextStyle(
                          color: outcomeColor, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text(
                    'Updated ${dateFormat.format(report.updatedAt)}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textTertiary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _landscapeSection(String label, String content) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(label),
          const SizedBox(height: 10),
          Text(content,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textPrimary, height: 1.5)),
        ],
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
