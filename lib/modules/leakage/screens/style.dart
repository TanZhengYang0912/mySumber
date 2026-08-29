import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../theme/tokens.dart';
import '../models/ai_anomaly_analysis.dart';
import '../models/alert.dart';
import '../models/report.dart';
import '../services/anomaly_ai_service.dart';
import '../state/app_state.dart';
import 'network_error.dart';

Color severityColor(String severity) {
  switch (severity) {
    case Severity.high:
      return AppColors.critical;
    case Severity.medium:
      return AppColors.warning;
    case Severity.low:
      return AppColors.success;
    default:
      return Colors.blueGrey;
  }
}

/// Alert status is deliberately monochrome. Severity already carries colour
/// on the same card, so colouring status too made every list read as noise —
/// the pill still labels the status, it just no longer competes for attention.
Color statusColor(String status) => const Color(0xFF6B7280);

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

/// A report outcome as a tag. It deliberately reuses alert status styling so
/// Fixed and Not Fixed do not compete with the report card's outcome edge.
Widget outcomePill(String outcome) => Pill(
      ReportOutcome.label(outcome),
      color: statusColor(outcome),
      outlined: true,
    );

/// Utility remains the only colour-coded pill and is text-only, so its
/// position at the right of a badge group stays compact and easy to scan.
Widget utilityPill(Utility utility) => Pill(
      utility == Utility.water ? 'Water' : 'Electricity',
      color: utility == Utility.water
          ? AppColors.waterAccent
          : AppColors.electricityAccent,
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
    final accentColor = report.isFixed ? AppColors.success : AppColors.critical;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              locationLabel,
                              style: const TextStyle(
                                fontSize: 14,
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
                            children: [
                              outcomePill(report.outcome),
                              if (utility != null) utilityPill(utility!),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        report.findings.isEmpty
                            ? 'No findings'
                            : report.findings,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        reportByline(report, resolvedWorkerName),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: AppColors.textTertiary),
              ],
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 10,
            child: Container(
              key: const ValueKey('report-outcome-accent'),
              width: 4,
              decoration: BoxDecoration(
                color: accentColor,
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

    final date = DateFormat('d MMM').format(alert.detectedAt);
    // Only state loss alerts carry a supply balance. Household and mall alerts
    // compare against their own baseline, never a state average.
    final metricText = alert.lossPct != null
        ? '${alert.lossPct!.toStringAsFixed(1)}% of supply unaccounted'
        : null;
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
                        statusPill(alert.status),
                        severityPill(sev),
                        if (utility != null) utilityPill(utility!),
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
                if (metricText != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    metricText,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: sevColor,
                    ),
                  ),
                ],
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

/// The AI write-up for one alert, plus a Generate/Regenerate button when
/// [canGenerate] is true (Admin only). Relocated from the deleted AI Review
/// page's `anomaly_review_detail_screen.dart` so Admin's Oversight detail
/// screen can show the same AI content Worker's alert detail already shows,
/// instead of nothing.
class AiAnalysisCard extends StatefulWidget {
  final Alert alert;
  final bool canGenerate;
  const AiAnalysisCard(
      {super.key, required this.alert, this.canGenerate = true});

  @override
  State<AiAnalysisCard> createState() => _AiAnalysisCardState();
}

class _AiAnalysisCardState extends State<AiAnalysisCard> {
  AiAnomalyAnalysis? _sessionAnalysis;
  String? _errorMessage;
  bool _generating = false;
  bool? _sessionAnalysisPersisted;

  @override
  void didUpdateWidget(covariant AiAnalysisCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.alert.id != widget.alert.id) {
      _sessionAnalysis = null;
      _errorMessage = null;
      _generating = false;
      _sessionAnalysisPersisted = null;
    }
  }

  AiAnomalyAnalysis? _savedAnalysis(Alert alert) {
    if (!alert.hasAiAnalysis) return null;
    return AiAnomalyAnalysis(
      summary: alert.aiSummary!,
      possibleCause: alert.aiPossibleCause,
      severityAssessment: alert.aiSeverityAssessment,
      confidence: alert.aiConfidence,
      recommendation: alert.aiRecommendation!,
      generatedAt: alert.aiGeneratedAt!,
    );
  }

  Future<void> _generate(BuildContext context) async {
    setState(() {
      _errorMessage = null;
      _generating = true;
      _sessionAnalysisPersisted = null;
    });
    try {
      final result =
          await context.read<AppState>().generateAnomalyAnalysis(widget.alert);
      if (!mounted) return;
      setState(() {
        _sessionAnalysis = result.analysis;
        _sessionAnalysisPersisted = result.persisted;
        _generating = false;
      });
    } on AnomalyAiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _generating = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'AI analysis is unavailable. Please try again.';
        _generating = false;
      });
    }
  }

  Widget _analysisValue(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(height: 1.45)),
      ],
    );
  }

  Widget _generateAction(BuildContext context) {
    final app = context.watch<AppState>();
    final savedAnalysis = _savedAnalysis(widget.alert);
    final analysis = savedAnalysis ?? _sessionAnalysis;
    final isRunning = _generating ||
        (widget.alert.id != null &&
            app.isGeneratingAnomalyAnalysis(widget.alert.id!));
    final hasError = _errorMessage != null;

    return FilledButton.icon(
      onPressed: isRunning ? null : () => _generate(context),
      icon: Icon(isRunning ? Icons.hourglass_top : Icons.auto_awesome),
      label: Text(
        isRunning
            ? 'Generating...'
            : hasError
                ? 'Retry AI Analysis'
                : analysis == null
                    ? 'Generate AI Analysis'
                    : 'Regenerate AI Analysis',
      ),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.adminPrimary,
        minimumSize: const Size.fromHeight(48),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final savedAnalysis = _savedAnalysis(widget.alert);
    final persistenceFailed =
        _sessionAnalysisPersisted == false && _sessionAnalysis != null;
    final analysis = persistenceFailed
        ? _sessionAnalysis
        : savedAnalysis ?? _sessionAnalysis;
    final hasError = _errorMessage != null;

    return AppCard(
      background: AppColors.adminSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('AI ANALYSIS', color: AppColors.adminPrimary),
          const SizedBox(height: 10),
          if (analysis == null) ...[
            const Text('AI analysis has not been generated for this anomaly.',
                style: TextStyle(height: 1.45)),
            const SizedBox(height: 12),
          ] else ...[
            _analysisValue('Summary', analysis.summary),
            const SizedBox(height: 12),
            if (analysis.possibleCause != null) ...[
              _analysisValue('Possible Cause', analysis.possibleCause!),
              const SizedBox(height: 12),
            ],
            if (analysis.severityAssessment != null &&
                analysis.confidence != null) ...[
              _analysisValue('AI Severity Assessment',
                  '${analysis.severityAssessment} · ${(analysis.confidence! * 100).round()}% confidence'),
              const SizedBox(height: 12),
            ],
            _analysisValue('System Recommendation', analysis.recommendation),
            const SizedBox(height: 12),
            Text(
                'Generated ${DateFormat('d MMM y, h:mm a').format(analysis.generatedAt)}',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
            if (persistenceFailed) ...[
              const SizedBox(height: 10),
              const Text(
                  'This result was generated but could not be saved. Retry to persist it.',
                  style: TextStyle(color: Colors.deepOrange, height: 1.35)),
            ],
            const SizedBox(height: 14),
          ],
          if (hasError) ...[
            Text(_errorMessage!,
                style: const TextStyle(color: Colors.deepOrange, height: 1.35)),
            const SizedBox(height: 12),
          ],
          if (widget.canGenerate) _generateAction(context),
        ],
      ),
    );
  }
}

/// Admin's Approve / Fault controls for an alert still awaiting review.
///
/// Renders nothing unless [AppState.awaitingDecision] is true, so the same
/// widget can be mounted unconditionally on any alert surface: Oversight's
/// queue never contains pending-review alerts and therefore never shows it,
/// and a faulted row in Anomalies keeps its place in the list without
/// offering a decision that was already made.
class AlertDecisionBar extends StatefulWidget {
  final Alert alert;

  /// Pop the current route once a decision lands. True for the pushed detail
  /// page, which should return to the list; false for the tablet split panel,
  /// which stays on screen while the row updates in place.
  final bool popOnDecision;

  const AlertDecisionBar({
    super.key,
    required this.alert,
    this.popOnDecision = false,
  });

  @override
  State<AlertDecisionBar> createState() => _AlertDecisionBarState();
}

class _AlertDecisionBarState extends State<AlertDecisionBar> {
  bool _busy = false;

  Future<void> _decide({required bool approve}) async {
    final alertId = widget.alert.id;
    if (alertId == null || _busy) return;
    setState(() => _busy = true);
    final app = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      if (approve) {
        await app.approveAlert(alertId);
      } else {
        await app.rejectAlert(alertId);
      }
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text(approve
            ? 'Approved — sent to the worker queue.'
            : 'Faulted — kept in Anomalies for the record.'),
        backgroundColor: approve ? AppColors.adminPrimary : Colors.blueGrey,
      ));
      if (widget.popOnDecision && navigator.canPop()) navigator.pop();
    } catch (_) {
      if (mounted) showNetworkErrorSnackBar(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!AppState.awaitingDecision(widget.alert)) {
      return const SizedBox.shrink();
    }
    return Column(
      key: const ValueKey('alert-decision-panel'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Review decision',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        const Text(
          'Approve sends this anomaly to the Worker queue.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _decide(approve: false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.critical,
                    side: const BorderSide(color: AppColors.critical),
                  ),
                  icon: const Icon(Icons.warning_amber_outlined, size: 18),
                  label: const Text('Mark as fault'),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 48,
                child: FilledButton.icon(
                  onPressed: _busy ? null : () => _decide(approve: true),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.adminPrimary,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Approve'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
