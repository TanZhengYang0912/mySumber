import 'package:flutter_test/flutter_test.dart';

import 'package:mysumber/modules/leakage/models/alert.dart';
import 'package:mysumber/modules/leakage/screens/alert_detail_screen.dart';

Alert _alert({
  String? aiSummary,
  String? aiPossibleCause,
  String? aiSeverityAssessment,
  String? aiRecommendation,
  double? aiConfidence,
  DateTime? aiGeneratedAt,
}) =>
    Alert(
      alertType: AlertType.household,
      sourceScope: AlertSourceScope.household,
      state: 'Perlis',
      householdId: 'H-305',
      detectedAt: DateTime(2026, 8, 20),
      signature: LeakSignature.suddenBurst,
      severity: Severity.medium,
      explanation: 'Resident reported a leak',
      status: AlertStatus.pending,
      aiSummary: aiSummary,
      aiPossibleCause: aiPossibleCause,
      aiSeverityAssessment: aiSeverityAssessment,
      aiRecommendation: aiRecommendation,
      aiConfidence: aiConfidence,
      aiGeneratedAt: aiGeneratedAt,
    );

void main() {
  // Household alerts only summarise the resident's message — the edge
  // function deliberately writes no cause, severity or confidence for them,
  // while hasAiAnalysis only requires summary + recommendation + timestamp.
  // Anything rendering those three fields must treat them as optional.
  test('a household alert renders only the rows it actually has', () {
    final alert = _alert(
      aiSummary: 'Resident reports water pooling under the kitchen sink.',
      aiRecommendation: 'Send a worker to inspect the sink trap.',
      aiGeneratedAt: DateTime(2026, 8, 20, 9),
    );

    expect(alert.hasAiAnalysis, isTrue);

    final rows = workerAiRows(alert);

    expect(rows.map((r) => r.label), ['Summary', 'Recommendation']);
    expect(rows.first.value,
        'Resident reports water pooling under the kitchen sink.');
  });

  test('a fully analysed alert still renders every row', () {
    final alert = _alert(
      aiSummary: 'Night flow stays high after midnight.',
      aiPossibleCause: 'Continuous leak on the distribution main.',
      aiSeverityAssessment: 'High',
      aiRecommendation: 'Dispatch a leak detection crew.',
      aiConfidence: 0.82,
      aiGeneratedAt: DateTime(2026, 8, 20, 9),
    );

    final rows = workerAiRows(alert);

    expect(
      rows.map((r) => r.label),
      ['Summary', 'Possible cause', 'Recommendation', 'Confidence'],
    );
    expect(rows.last.value, '82%');
  });

  test('a severity assessment without a confidence is not rendered', () {
    final alert = _alert(
      aiSummary: 'Night flow stays high after midnight.',
      aiRecommendation: 'Dispatch a leak detection crew.',
      aiSeverityAssessment: 'High',
      aiGeneratedAt: DateTime(2026, 8, 20, 9),
    );

    final rows = workerAiRows(alert);

    expect(rows.map((r) => r.label), ['Summary', 'Recommendation']);
  });
}
