import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../theme/tokens.dart';
import '../models/alert.dart';
import '../models/report.dart';

Color severityColor(String severity) {
  switch (severity) {
    case Severity.high:
      return Colors.red.shade600;
    case Severity.medium:
      return Colors.orange.shade700;
    case Severity.low:
      return Colors.teal.shade600;
    default:
      return Colors.blueGrey;
  }
}

/// Alert status is deliberately monochrome. Severity already carries colour
/// on the same card, so colouring status too made every list read as noise —
/// the pill still labels the status, it just no longer competes for attention.
Color statusColor(String status) => Colors.black;

/// What kind of anomaly this is, in worker-facing words. Household alerts show
/// their detection signature (Sudden burst, Creeping leak, ...) because the
/// H-### code in the title already says it is a household.
String alertReasonLabel(Alert alert) {
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

/// Who moved the alert to its current status, and when the move is dated —
/// "Investigating by Aisyah", "Resolved by Aisyah · 3 Aug 2026, 14:20". The
/// date only shows for resolved/not-fixed, where [closedAt] (the filed
/// report's timestamp) is available; investigating has no report to date it.
/// Null while an alert is still pending or when nobody has touched it (older
/// rows predate the `handled_by` column).
String? handledLabel(Alert alert, String? resolvedName, [DateTime? closedAt]) {
  final who = resolvedName?.trim();
  if (who == null || who.isEmpty) return null;
  if (alert.status == AlertStatus.pending) return null;
  final label = '${AlertStatus.label(alert.status)} by $who';
  if (closedAt == null) return label;
  return '$label · ${DateFormat('d MMM y, HH:mm').format(closedAt)}';
}

/// True only while a DIFFERENT worker is mid-investigation — the one
/// transition where two workers could otherwise race. Not Fixed resets
/// ownership (re-investigating is open to anyone), so it is deliberately
/// excluded here even though it also carries a [handledBy].
bool alertLockedForUser(Alert alert, String? currentUserId) {
  if (alert.status != AlertStatus.investigating) return false;
  final owner = alert.handledById;
  if (owner == null) return false;
  return owner != currentUserId;
}

/// Who filed a report and when, as one line: "By Aisyah · 3 Aug 2026, 14:20".
String reportByline(Report report, String resolvedName) =>
    'By $resolvedName · ${DateFormat('d MMM y, HH:mm').format(report.updatedAt)}';

/// The one place severity is rendered as a tag. Outlined so it does not fight
/// the status pill sitting beside it on the same card.
Widget severityPill(String severity) => Pill(
      Severity.label(severity),
      color: severityColor(severity),
      outlined: true,
    );

/// The one place alert status is rendered as a tag. See [statusColor] for why
/// the colour is deliberately monochrome.
Widget statusPill(String status) => Pill(
      AlertStatus.label(status),
      color: statusColor(status),
      outlined: true,
    );

/// A report outcome as a tag. Same outlined treatment as [severityPill] so
/// Fixed / Not Fixed read as siblings of High / Medium, not as a second
/// species of badge.
Widget outcomePill(String outcome) => Pill(
      ReportOutcome.label(outcome),
      color: outcome == ReportOutcome.fixed
          ? AppColors.success
          : AppColors.critical,
      outlined: true,
    );

/// A filed report, as a tappable card. Used by both the Worker's Report
/// History and the Admin's Oversight Reports tab — one look for both, so
/// tapping into a report from either role lands on a card you've already
/// seen. Pass [utility] to show the Water/Electricity pill (Oversight mixes
/// utilities); leave it null to hide it (Report History is already scoped
/// to one utility via its header).
class ReportCard extends StatelessWidget {
  final Report report;
  final String locationLabel;
  final Utility? utility;
  final String resolvedWorkerName;
  final VoidCallback onTap;

  const ReportCard({
    super.key,
    required this.report,
    required this.locationLabel,
    required this.onTap,
    required this.resolvedWorkerName,
    this.utility,
  });

  @override
  Widget build(BuildContext context) {
    final isFixed = report.isFixed;
    final outcomColor = isFixed ? AppColors.success : AppColors.critical;
    final isWater = utility == Utility.water;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: outcomColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isFixed
                    ? Icons.check_circle_outline
                    : Icons.warning_amber_rounded,
                color: outcomColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(locationLabel,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary)),
                      ),
                      const SizedBox(width: 6),
                      outcomePill(report.outcome),
                      if (utility != null) ...[
                        const SizedBox(width: 6),
                        Pill(
                          isWater ? 'Water' : 'Electricity',
                          color: isWater
                              ? AppColors.waterAccent
                              : AppColors.electricityAccent,
                          icon: isWater
                              ? Icons.water_drop
                              : Icons.electric_bolt,
                          outlined: true,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    report.findings.isEmpty ? 'No findings' : report.findings,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    reportByline(report, resolvedWorkerName),
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textTertiary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

/// A queued alert, as a tappable card. Used by both the Worker's Alert
/// Queue and the Admin's Oversight Alert Queue — one look for both. Pass
/// [utility] to show the Water/Electricity pill (Oversight mixes
/// utilities); leave it null to hide it (Worker's queues are already
/// scoped to one utility via their header).
class AlertCard extends StatelessWidget {
  final Alert alert;
  final DateTime? resolvedAt;
  final Utility? utility;
  final String? resolvedHandledBy;
  final VoidCallback onTap;

  const AlertCard({
    super.key,
    required this.alert,
    required this.onTap,
    this.resolvedAt,
    this.utility,
    this.resolvedHandledBy,
  });

  @override
  Widget build(BuildContext context) {
    final sev = alert.severity;
    final sevColor = severityColor(sev);
    final isWater = utility == Utility.water;

    final date = DateFormat('d MMM').format(alert.detectedAt);
    final metricText = alert.lossPct != null
        ? '${alert.lossPct!.toStringAsFixed(1)}% of supply unaccounted'
        : '${alert.ratio.toStringAsFixed(1)}x of state avg';
    final handled = handledLabel(alert, resolvedHandledBy, resolvedAt);
    final handledColor = alert.status == AlertStatus.resolved
        ? AppColors.success
        : AppColors.textSecondary;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0F000000),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        alert.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      alignment: WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (utility != null)
                          Pill(
                            isWater ? 'Water' : 'Electricity',
                            color: isWater
                                ? AppColors.waterAccent
                                : AppColors.electricityAccent,
                            icon: isWater
                                ? Icons.water_drop
                                : Icons.electric_bolt,
                            outlined: true,
                          ),
                        statusPill(alert.status),
                        severityPill(sev),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${alertReasonLabel(alert)} · Flagged $date',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 6),
                Text(
                  metricText,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: sevColor,
                  ),
                ),
                if (handled != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        alert.status == AlertStatus.resolved
                            ? Icons.check_circle_outline
                            : Icons.person_outline,
                        size: 14,
                        color: handledColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        handled,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: handledColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 10,
            child: Container(
              width: 4,
              decoration: BoxDecoration(
                color: sevColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget pill(String text, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
    ),
  );
}
