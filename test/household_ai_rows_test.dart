import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mysumber/modules/leakage/models/alert.dart';
import 'package:mysumber/modules/leakage/screens/style.dart';

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

Future<void> _pumpReadOnlyAi(WidgetTester tester, Alert alert) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: AiAnalysisCard(alert: alert, canGenerate: false),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('household AI renders only saved optional fields, read-only',
      (tester) async {
    final alert = _alert(
      aiSummary: 'Resident reports water pooling under the kitchen sink.',
      aiRecommendation: 'Send a worker to inspect the sink trap.',
      aiGeneratedAt: DateTime(2026, 8, 20, 9),
    );

    await _pumpReadOnlyAi(tester, alert);

    expect(alert.hasAiAnalysis, isTrue);
    expect(find.text('Resident reports water pooling under the kitchen sink.'),
        findsOneWidget);
    expect(
        find.text('Send a worker to inspect the sink trap.'), findsOneWidget);
    expect(find.text('Possible Cause'), findsNothing);
    expect(find.text('AI Severity Assessment'), findsNothing);
    expect(find.text('Generate AI Analysis'), findsNothing);
    expect(find.text('Regenerate AI Analysis'), findsNothing);
    expect(find.text('Retry AI Analysis'), findsNothing);
  });

  testWidgets('fully analysed alert renders every saved AI field',
      (tester) async {
    final alert = _alert(
      aiSummary: 'Night flow stays high after midnight.',
      aiPossibleCause: 'Continuous leak on the distribution main.',
      aiSeverityAssessment: 'High',
      aiRecommendation: 'Dispatch a leak detection crew.',
      aiConfidence: 0.82,
      aiGeneratedAt: DateTime(2026, 8, 20, 9),
    );

    await _pumpReadOnlyAi(tester, alert);

    expect(find.text('Possible Cause'), findsOneWidget);
    expect(
        find.text('Continuous leak on the distribution main.'), findsOneWidget);
    expect(find.text('AI Severity Assessment'), findsOneWidget);
    expect(find.text('High · 82% confidence'), findsOneWidget);
    expect(find.text('System Recommendation'), findsOneWidget);
  });

  testWidgets('severity without confidence is omitted', (tester) async {
    final alert = _alert(
      aiSummary: 'Night flow stays high after midnight.',
      aiRecommendation: 'Dispatch a leak detection crew.',
      aiSeverityAssessment: 'High',
      aiGeneratedAt: DateTime(2026, 8, 20, 9),
    );

    await _pumpReadOnlyAi(tester, alert);

    expect(find.text('AI Severity Assessment'), findsNothing);
    expect(find.text('High · 0% confidence'), findsNothing);
  });
}
