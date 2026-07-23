import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../theme/tokens.dart';
import 'admin_alert_detail_screen.dart';
import '../../leakage/models/ai_anomaly_analysis.dart';
import '../../leakage/models/alert.dart';
import '../../leakage/state/app_state.dart';
import '../../leakage/screens/style.dart';
import '../../leakage/services/anomaly_ai_service.dart';

class AnomalyReviewDetailScreen extends StatefulWidget {
  final int alertId;

  const AnomalyReviewDetailScreen({
    super.key,
    required this.alertId,
  });

  @override
  State<AnomalyReviewDetailScreen> createState() =>
      _AnomalyReviewDetailScreenState();
}

class _AnomalyReviewDetailScreenState extends State<AnomalyReviewDetailScreen> {
  AiAnomalyAnalysis? _sessionAnalysis;
  String? _errorMessage;
  bool _generating = false;
  bool? _sessionAnalysisPersisted;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final matches = app.alerts.where((alert) => alert.id == widget.alertId);
    if (matches.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('AI Anomaly Review'),
          backgroundColor: AppColors.adminPrimary,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('Alert unavailable.')),
      );
    }

    final alert = matches.first;
    final city = alert.facilityCity;
    final facility = alert.facilityName ?? 'Facility not linked';
    final equipment = alert.equipmentName ?? 'Equipment not linked';
    final explanation = _reviewExplanation(alert.explanation);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('AI Anomaly Review'),
        backgroundColor: AppColors.adminPrimary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
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
                      builder: (_) =>
                          AdminAlertDetailScreen(alertId: alert.id!),
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
      ),
    );
  }

  Widget _analysisSection(
    BuildContext context,
    AppState app,
    Alert alert,
    String explanation,
  ) {
    final savedAnalysis = _savedAnalysis(alert);
    final persistenceFailed =
        _sessionAnalysisPersisted == false && _sessionAnalysis != null;
    final analysis = persistenceFailed
        ? _sessionAnalysis
        : savedAnalysis ?? _sessionAnalysis;
    final isRunning = _generating ||
        (alert.id != null && app.isGeneratingAnomalyAnalysis(alert.id!));
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
          FilledButton.icon(
            onPressed: isRunning ? null : () => _generate(context, alert),
            icon: Icon(
              isRunning ? Icons.hourglass_top : Icons.auto_awesome,
            ),
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
          ),
        ],
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
              Pill(AlertStatus.label(alert.status),
                  color: statusColor(alert.status)),
              const SizedBox(width: 8),
              Pill(Severity.label(alert.severity),
                  color: severityColor(alert.severity)),
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
