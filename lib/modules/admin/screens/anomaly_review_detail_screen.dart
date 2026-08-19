import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../theme/tokens.dart';
import '../services/admin_tablet_layout.dart';
import 'admin_alert_detail_screen.dart';
import '../../leakage/models/ai_anomaly_analysis.dart';
import '../../leakage/models/alert.dart';
import '../../leakage/state/app_state.dart';
import '../../leakage/screens/style.dart';
import '../../leakage/services/anomaly_ai_service.dart';

class AnomalyReviewDetailScreen extends StatelessWidget {
  final int alertId;

  const AnomalyReviewDetailScreen({
    super.key,
    required this.alertId,
  });

  @override
  Widget build(BuildContext context) {
    final isPhoneLandscape =
        adminLayoutModeFor(MediaQuery.sizeOf(context)) ==
            AdminLayoutMode.phoneLandscape;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: isPhoneLandscape
          ? null
          : AppBar(
              title: const Text('AI Anomaly Review'),
              backgroundColor: AppColors.adminPrimary,
              foregroundColor: Colors.white,
            ),
      body: AnomalyReviewDetailContent(
        alertId: alertId,
        phoneLandscape: isPhoneLandscape,
      ),
    );
  }
}

class AnomalyReviewDetailContent extends StatefulWidget {
  final int alertId;
  final bool pane;
  final bool phoneLandscape;

  const AnomalyReviewDetailContent({
    super.key,
    required this.alertId,
    this.pane = false,
    this.phoneLandscape = false,
  });

  @override
  State<AnomalyReviewDetailContent> createState() =>
      _AnomalyReviewDetailContentState();
}

class _AnomalyReviewDetailContentState
    extends State<AnomalyReviewDetailContent> {
  AiAnomalyAnalysis? _sessionAnalysis;
  String? _errorMessage;
  bool _generating = false;
  bool? _sessionAnalysisPersisted;

  @override
  void didUpdateWidget(covariant AnomalyReviewDetailContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.alertId != widget.alertId) {
      _sessionAnalysis = null;
      _errorMessage = null;
      _generating = false;
      _sessionAnalysisPersisted = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final matches = app.alerts.where((alert) => alert.id == widget.alertId);
    if (matches.isEmpty) {
      return const Center(child: Text('Alert unavailable.'));
    }

    final alert = matches.first;
    final city = alert.facilityCity;
    final facility = alert.facilityName ?? 'Facility not linked';
    final equipment = alert.equipmentName ?? 'Equipment not linked';
    final explanation = _reviewExplanation(alert.explanation);

    if (widget.phoneLandscape) {
      return _phoneLandscapeLayout(
        context,
        app,
        alert,
        facility,
        equipment,
        city,
        explanation,
      );
    }

    return ListView(
      key: const Key('anomaly-review-detail-content'),
      padding: widget.pane ? EdgeInsets.zero : const EdgeInsets.all(14),
      children: [
        _headerCard(alert, facility, equipment, city),
        const SizedBox(height: 10),
        _evidenceCard(alert),
        const SizedBox(height: 10),
        _analysisSection(context, app, alert, explanation),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: alert.id == null
              ? null
              : () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => AdminAlertDetailScreen(alertId: alert.id!),
                  )),
          icon: const Icon(Icons.open_in_new),
          label: const Text('Open in Oversight'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.adminPrimary,
            minimumSize: const Size.fromHeight(50),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _phoneLandscapeLayout(
    BuildContext context,
    AppState app,
    Alert alert,
    String facility,
    String equipment,
    String? city,
    String explanation,
  ) {
    return SafeArea(
      child: Column(
        key: const Key('anomaly-review-landscape-layout'),
        children: [
          SizedBox(
            height: 60,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back to AI Review',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'AI Review detail',
                      style: TextStyle(
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
                        _analysisSection(
                          context,
                          app,
                          alert,
                          explanation,
                          showAction: false,
                        ),
                        const SizedBox(height: 10),
                        _headerCard(alert, facility, equipment, city),
                        const SizedBox(height: 10),
                        _evidenceCard(alert),
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
                          'NEXT ACTION',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _generateAction(context, app, alert),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: alert.id == null
                              ? null
                              : () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => AdminAlertDetailScreen(
                                          alertId: alert.id!),
                                    ),
                                  ),
                          icon: const Icon(Icons.open_in_new, size: 18),
                          label: const Text('Open in Oversight'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            foregroundColor: AppColors.adminPrimary,
                            side: const BorderSide(
                                color: AppColors.adminPrimary),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.warningSurface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Actions stay visible while you review the evidence.',
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
    );
  }

  Widget _analysisSection(
    BuildContext context,
    AppState app,
    Alert alert,
    String explanation,
    {bool showAction = true}
  ) {
    final savedAnalysis = _savedAnalysis(alert);
    final persistenceFailed =
        _sessionAnalysisPersisted == false && _sessionAnalysis != null;
    final analysis = persistenceFailed
        ? _sessionAnalysis
        : savedAnalysis ?? _sessionAnalysis;
    final hasError = _errorMessage != null;

    return _card(
      background: AppColors.adminSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('AI ANALYSIS', color: AppColors.adminPrimary),
          const SizedBox(height: 10),
          if (analysis == null) ...[
            const Text(
              'AI analysis has not been generated for this anomaly.',
              style: TextStyle(height: 1.45),
            ),
            const SizedBox(height: 12),
          ] else ...[
            _analysisValue('Summary', analysis.summary),
            const SizedBox(height: 12),
            _analysisValue('Possible Cause', analysis.possibleCause),
            const SizedBox(height: 12),
            _analysisValue(
              'AI Severity Assessment',
              '${analysis.severityAssessment} · ${(analysis.confidence * 100).round()}% confidence',
            ),
            const SizedBox(height: 12),
            _analysisValue('System Recommendation', analysis.recommendation),
            const SizedBox(height: 12),
            Text(
              'Generated ${DateFormat('d MMM y, h:mm a').format(analysis.generatedAt)}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            if (persistenceFailed) ...[
              const SizedBox(height: 10),
              const Text(
                'This result was generated but could not be saved. Retry to persist it.',
                style: TextStyle(color: Colors.deepOrange, height: 1.35),
              ),
            ],
            const SizedBox(height: 14),
          ],
          if (hasError) ...[
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.deepOrange, height: 1.35),
            ),
            const SizedBox(height: 12),
          ],
          if (explanation.trim().isNotEmpty) ...[
            const Text(
              'System Detection Context',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(explanation, style: const TextStyle(height: 1.45)),
            const SizedBox(height: 14),
          ],
          if (showAction) _generateAction(context, app, alert),
        ],
      ),
    );
  }

  Widget _generateAction(BuildContext context, AppState app, Alert alert) {
    final savedAnalysis = _savedAnalysis(alert);
    final analysis = savedAnalysis ?? _sessionAnalysis;
    final isRunning = _generating ||
        (alert.id != null && app.isGeneratingAnomalyAnalysis(alert.id!));
    final hasError = _errorMessage != null;

    return FilledButton.icon(
      onPressed: isRunning ? null : () => _generate(context, alert),
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

  AiAnomalyAnalysis? _savedAnalysis(Alert alert) {
    if (!alert.hasAiAnalysis) return null;
    return AiAnomalyAnalysis(
      summary: alert.aiSummary!,
      possibleCause: alert.aiPossibleCause!,
      severityAssessment: alert.aiSeverityAssessment!,
      confidence: alert.aiConfidence!,
      recommendation: alert.aiRecommendation!,
      generatedAt: alert.aiGeneratedAt!,
    );
  }

  Future<void> _generate(BuildContext context, Alert alert) async {
    setState(() {
      _errorMessage = null;
      _generating = true;
      _sessionAnalysisPersisted = null;
    });

    try {
      final result =
          await context.read<AppState>().generateAnomalyAnalysis(alert);
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
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to generate AI analysis: $error';
        _generating = false;
      });
    }
  }

  Widget _headerCard(
    Alert alert,
    String facility,
    String equipment,
    String? city,
  ) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              statusPill(alert.status),
              const SizedBox(width: 8),
              severityPill(alert.severity),
            ],
          ),
          const SizedBox(height: 14),
          const SectionLabel('LOCATION'),
          const SizedBox(height: 6),
          Text(
            '${alert.state} → $facility → $equipment',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          if (city != null && city.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(city, style: const TextStyle(color: AppColors.textSecondary)),
          ],
          const SizedBox(height: 8),
          Text(
            '${alert.utility == Utility.water ? 'Water' : 'Electricity'} · ${DateFormat('d MMM y, h:mm a').format(alert.detectedAt)}',
            style:
                const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _evidenceCard(Alert alert) {
    final metrics = <Widget>[];
    if (alert.producedMld != null) {
      metrics
          .add(_metric('Produced/Supplied', '${alert.producedMld!.round()}'));
    }
    if (alert.billedMld != null) {
      metrics.add(_metric('Billed/Consumed', '${alert.billedMld!.round()}'));
    }
    if (alert.lossMld != null) {
      metrics.add(_metric('Loss', '${alert.lossMld!.round()}'));
    }
    if (alert.lossPct != null) {
      metrics
          .add(_metric('Loss rate', '${alert.lossPct!.toStringAsFixed(1)}%'));
    }
    if (alert.actualL != 0 || alert.baselineL != 0) {
      metrics.add(_metric('Actual', '${alert.actualL.round()} L'));
      metrics.add(_metric('Baseline', '${alert.baselineL.round()} L'));
    }

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('DETECTED EVIDENCE'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: metrics.isEmpty
                ? [
                    const Text(
                      'No numeric evidence recorded for this alert.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ]
                : metrics,
          ),
          const SizedBox(height: 12),
          Text(
            'Detected ${DateFormat('d MMM y').format(alert.detectedAt)}',
            style:
                const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value) {
    return Container(
      width: 145,
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
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _card({required Widget child, Color? background}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background ?? AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }

  String _reviewExplanation(String explanation) {
    final recommendationStart = RegExp(
      r'\s+Recommend\b.*$',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(explanation);
    if (recommendationStart == null) return explanation.trim();
    return explanation.substring(0, recommendationStart.start).trim();
  }
}
