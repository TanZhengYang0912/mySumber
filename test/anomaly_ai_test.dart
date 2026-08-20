import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:mysumber/modules/leakage/models/ai_anomaly_analysis.dart';
import 'package:mysumber/modules/leakage/models/alert.dart';
import 'package:mysumber/modules/leakage/models/anomaly_case.dart';
import 'package:mysumber/modules/leakage/services/anomaly_ai_service.dart';

void main() {
  test('keeps Groq credentials out of the Flutter build', () {
    final appEntryPoint = File('lib/main.dart').readAsStringSync();
    final clientService =
        File('lib/modules/leakage/services/anomaly_ai_service.dart')
            .readAsStringSync();
    const functionPath =
        'supabase/functions/generate-anomaly-analysis/index.ts';

    expect(appEntryPoint, isNot(contains('GroqConfig')));
    expect(clientService, isNot(contains('api.groq.com')));
    expect(File(functionPath).existsSync(), isTrue);

    final functionSource = File(functionPath).readAsStringSync();
    expect(functionSource, contains('GROQ_API_KEY'));
    expect(functionSource, contains('profile.role'));
    expect(functionSource, contains('profile.status'));
  });

  test('parses a valid Groq anomaly response', () {
    final analysis = AiAnomalyAnalysis.fromJson({
      'summary': 'Water use is above the normal baseline.',
      'possible_cause': 'Abnormal demand around the main pump.',
      'severity_assessment': 'High',
      'confidence': 0.92,
      'recommendation': 'Continue monitoring the equipment record.',
    });

    expect(analysis.summary, contains('Water use'));
    expect(analysis.severityAssessment, 'High');
    expect(analysis.confidence, 0.92);
  });

  test('parses confidence when Groq returns it as a numeric string', () {
    final analysis = AiAnomalyAnalysis.fromJson({
      'summary': 'Water use is above the normal baseline.',
      'possible_cause': 'Abnormal demand around the main pump.',
      'severity_assessment': 'High',
      'confidence': '0.85',
      'recommendation': 'Continue monitoring the equipment record.',
    });

    expect(analysis.confidence, 0.85);
  });

  test('parses confidence when Groq returns a percentage string', () {
    final analysis = AiAnomalyAnalysis.fromJson({
      'summary': 'Water use is above the normal baseline.',
      'possible_cause': 'Abnormal demand around the main pump.',
      'severity_assessment': 'High',
      'confidence': '85%',
      'recommendation': 'Continue monitoring the equipment record.',
    });

    expect(analysis.confidence, 0.85);
  });

  test('parses confidence when Groq includes a percentage label', () {
    final analysis = AiAnomalyAnalysis.fromJson({
      'summary': 'Water use is above the normal baseline.',
      'possible_cause': 'Abnormal demand around the main pump.',
      'severity_assessment': 'High',
      'confidence': '85% confidence',
      'recommendation': 'Continue monitoring the equipment record.',
    });

    expect(analysis.confidence, 0.85);
  });

  test('normalizes case-insensitive severity values from Groq', () {
    final analysis = AiAnomalyAnalysis.fromJson({
      'summary': 'Water use is above the normal baseline.',
      'possible_cause': 'Abnormal demand around the main pump.',
      'severity_assessment': 'high',
      'confidence': 0.85,
      'recommendation': 'Continue monitoring the equipment record.',
    });

    expect(analysis.severityAssessment, 'High');
  });

  test('normalizes descriptive severity values from Groq', () {
    final analysis = AiAnomalyAnalysis.fromJson({
      'summary': 'Water use is above the normal baseline.',
      'possible_cause': 'Abnormal demand around the main pump.',
      'severity_assessment': 'High severity due to sustained loss.',
      'confidence': 0.85,
      'recommendation': 'Continue monitoring the equipment record.',
    });

    expect(analysis.severityAssessment, 'High');
  });

  test('reports the invalid AI response fields', () {
    expect(
      () => AiAnomalyAnalysis.fromJson({
        'summary': 'Summary',
        'possible_cause': 'Cause',
        'severity_assessment': 'Unknown',
        'confidence': 'not available',
        'recommendation': 'Monitor',
      }),
      throwsA(
        isA<AiAnomalyFormatException>().having(
          (error) => error.message,
          'message',
          allOf(contains('severity_assessment'), contains('confidence')),
        ),
      ),
    );
  });

  test('rejects invalid confidence and severity', () {
    expect(
      () => AiAnomalyAnalysis.fromJson({
        'summary': 'Summary',
        'possible_cause': 'Cause',
        'severity_assessment': 'Critical',
        'confidence': 1.2,
        'recommendation': 'Monitor',
      }),
      throwsA(isA<AiAnomalyFormatException>()),
    );
  });

  test('Alert round-trips saved AI fields', () {
    final alert = Alert(
      id: 9,
      alertType: AlertType.nrwHotspot,
      state: 'Selangor',
      detectedAt: DateTime.utc(2026, 7, 23),
      signature: LeakSignature.nrwHotspot,
      severity: Severity.high,
      explanation: 'Stored anomaly explanation.',
      aiSummary: 'Water use is above baseline.',
      aiPossibleCause: 'Abnormal pump demand.',
      aiSeverityAssessment: 'High',
      aiRecommendation: 'Continue monitoring.',
      aiConfidence: 0.92,
      aiGeneratedAt: DateTime.utc(2026, 7, 23, 8),
    );

    final restored = Alert.fromMap(alert.toMap());

    expect(restored.aiSummary, 'Water use is above baseline.');
    expect(restored.aiPossibleCause, 'Abnormal pump demand.');
    expect(restored.aiSeverityAssessment, 'High');
    expect(restored.aiConfidence, 0.92);
    expect(restored.aiGeneratedAt, DateTime.utc(2026, 7, 23, 8));
    expect(restored.hasAiAnalysis, isTrue);
  });

  test('serializes every validated AI field using alert column names', () {
    final analysis = AiAnomalyAnalysis(
      summary: 'Summary',
      possibleCause: 'Cause',
      severityAssessment: 'Medium',
      confidence: 0.7,
      recommendation: 'Monitor.',
      generatedAt: DateTime.utc(2026, 7, 23, 8),
    );

    expect(
      analysis.toAlertFields().keys,
      containsAll([
        'ai_summary',
        'ai_possible_cause',
        'ai_severity_assessment',
        'ai_recommendation',
        'ai_confidence',
        'ai_generated_at',
      ]),
    );
  });

  test('sends only the alert ID to the private edge function', () async {
    var requestedAlertId = 0;
    final service = AnomalyAiService.forTesting((alertId) async {
      requestedAlertId = alertId;
      return {
        'analysis': {
          'summary': 'Pump usage is abnormal.',
          'possible_cause': 'Demand spike around the pump.',
          'severity_assessment': 'High',
          'confidence': 0.9,
          'recommendation': 'Continue monitoring.',
        },
      };
    });

    final result = await service.generate(_testAlert());

    expect(requestedAlertId, 9);
    expect(result.summary, 'Pump usage is abnormal.');
  });

  test('sends only the saved case ID to the private edge function', () async {
    String? requestedCaseId;
    final service = AnomalyAiService.forTesting(
      (_) async => throw UnimplementedError('alert analysis is not used here'),
      null,
      (caseId) async {
        requestedCaseId = caseId;
        return {
          'analysis': {
            'summary': 'The household circuit is unstable.',
            'possible_cause': 'Loose connection.',
            'severity_assessment': 'Medium',
            'confidence': 0.8,
            'recommendation': 'Inspect the consumer unit.',
          },
        };
      },
    );

    final result = await service.generateCase(const AnomalyCase(
      id: '7199ec20-cb82-4ea8-aecc-c78adc7e00d1',
      sourceScope: AlertSourceScope.household,
      sourceKey: 'household:demo:H-305',
      utility: Utility.electricity,
      state: 'Selangor',
      householdId: 'H-305',
      severity: Severity.medium,
      explanation: 'Kitchen lights repeatedly flicker.',
    ));

    expect(requestedCaseId, '7199ec20-cb82-4ea8-aecc-c78adc7e00d1');
    expect(result.severityAssessment, 'Medium');
  });

  test('maps edge-function failures to an anomaly AI exception', () async {
    final service = AnomalyAiService.forTesting(
      (_) async => throw StateError('Function unavailable'),
    );

    expect(
      () => service.generate(_testAlert()),
      throwsA(
        isA<AnomalyAiException>().having(
          (error) => error.failure,
          'failure',
          AnomalyAiFailure.apiError,
        ),
      ),
    );
  });

  test('rejects an incomplete edge-function response', () async {
    final service = AnomalyAiService.forTesting(
      (_) async => {
        'analysis': {'summary': 'Incomplete'}
      },
    );

    expect(
      () => service.generate(_testAlert()),
      throwsA(
        isA<AnomalyAiException>().having(
          (error) => error.failure,
          'failure',
          AnomalyAiFailure.invalidResponse,
        ),
      ),
    );
  });

  test('preview sends the raw evidence and returns a validated analysis',
      () async {
    Map<String, Object?>? sentEvidence;
    final service = AnomalyAiService.forTesting(
      (_) async => throw UnimplementedError('generate not used here'),
      (evidence) async {
        sentEvidence = evidence;
        return {
          'analysis': {
            'summary': 'Perlis loss is above the national average.',
            'possible_cause': 'Distribution-network leakage.',
            'severity_assessment': 'High',
            'confidence': 0.86,
            'recommendation': 'Field inspection of the district network.',
          },
        };
      },
    );

    final result = await service.preview({'state': 'Perlis', 'loss_pct': 59.7});

    expect(sentEvidence, {'state': 'Perlis', 'loss_pct': 59.7});
    expect(result.summary, 'Perlis loss is above the national average.');
    expect(result.severityAssessment, 'High');
  });

  test('mall preview always identifies the Mall source', () async {
    Map<String, Object?>? sentEvidence;
    final service = AnomalyAiService.forTesting(
      (_) async => throw UnimplementedError('generate not used here'),
      (evidence) async {
        sentEvidence = evidence;
        return {
          'analysis': {
            'summary': 'Chiller usage needs inspection.',
            'possible_cause': 'A load issue.',
            'severity_assessment': 'Medium',
            'confidence': 0.8,
            'recommendation': 'Review the equipment list.',
          },
        };
      },
    );

    await service.previewMall({'facility_name': 'Sunway Pyramid'});

    expect(sentEvidence, {
      'facility_name': 'Sunway Pyramid',
      'source_scope': 'mall',
    });
  });

  test('preview maps edge-function failures to an anomaly AI exception',
      () async {
    final service = AnomalyAiService.forTesting(
      (_) async => throw UnimplementedError('generate not used here'),
      (_) async => throw StateError('Function unavailable'),
    );

    expect(
      () => service.preview({'state': 'Perlis'}),
      throwsA(
        isA<AnomalyAiException>().having(
          (error) => error.failure,
          'failure',
          AnomalyAiFailure.apiError,
        ),
      ),
    );
  });

  test('preview rejects an incomplete edge-function response', () async {
    final service = AnomalyAiService.forTesting(
      (_) async => throw UnimplementedError('generate not used here'),
      (_) async => {
        'analysis': {'summary': 'Incomplete'}
      },
    );

    expect(
      () => service.preview({'state': 'Perlis'}),
      throwsA(
        isA<AnomalyAiException>().having(
          (error) => error.failure,
          'failure',
          AnomalyAiFailure.invalidResponse,
        ),
      ),
    );
  });
}

Alert _testAlert() => Alert(
      id: 9,
      alertType: AlertType.nrwHotspot,
      state: 'Selangor',
      detectedAt: DateTime.utc(2026, 7, 23),
      signature: LeakSignature.nrwHotspot,
      severity: Severity.high,
      explanation: 'Water usage exceeded the baseline.',
      facilityName: '1 Utama Shopping Centre',
      facilityCity: 'Petaling Jaya',
      equipmentName: 'Main Water Pump A1',
      baselineL: 100,
      actualL: 180,
    );
