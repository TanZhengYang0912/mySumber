import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mysumber/modules/leakage/models/ai_anomaly_analysis.dart';
import 'package:mysumber/modules/leakage/models/alert.dart';
import 'package:mysumber/modules/leakage/services/anomaly_ai_service.dart';

void main() {
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
      aiRecommendation: 'Continue monitoring.',
      aiConfidence: 0.92,
      aiGeneratedAt: DateTime.utc(2026, 7, 23, 8),
    );

    final restored = Alert.fromMap(alert.toMap());

    expect(restored.aiSummary, 'Water use is above baseline.');
    expect(restored.aiPossibleCause, 'Abnormal pump demand.');
    expect(restored.aiConfidence, 0.92);
    expect(restored.aiGeneratedAt, DateTime.utc(2026, 7, 23, 8));
    expect(restored.hasAiAnalysis, isTrue);
  });

  test('sends anomaly context and parses Groq JSON', () async {
    late Map<String, dynamic> requestBody;
    final client = MockClient((request) async {
      requestBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': jsonEncode({
                    'summary': 'Pump usage is abnormal.',
                    'possible_cause': 'Demand spike around the pump.',
                    'severity_assessment': 'High',
                    'confidence': 0.9,
                    'recommendation': 'Continue monitoring.',
                  }),
                },
              },
            ],
          }),
          200);
    });

    final result = await AnomalyAiService(
      client: client,
      apiKey: 'test-key',
    ).generate(_testAlert());

    expect(result.summary, 'Pump usage is abnormal.');
    expect(requestBody['model'], AnomalyAiService.model);
    expect(requestBody['response_format'], {'type': 'json_object'});
    expect(requestBody.toString(), contains('Main Water Pump A1'));
  });

  test('maps timeout to an anomaly AI exception', () async {
    final timeoutClient = MockClient((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return http.Response('', 200);
    });

    expect(
      () => AnomalyAiService(
        client: timeoutClient,
        apiKey: 'test-key',
        timeout: const Duration(milliseconds: 1),
      ).generate(_testAlert()),
      throwsA(
        isA<AnomalyAiException>().having(
          (error) => error.failure,
          'failure',
          AnomalyAiFailure.timeout,
        ),
      ),
    );
  });

  test('maps non-200 responses to an API error', () async {
    final client = MockClient((_) async => http.Response('Nope', 503));

    expect(
      () => AnomalyAiService(client: client, apiKey: 'test-key')
          .generate(_testAlert()),
      throwsA(
        isA<AnomalyAiException>().having(
          (error) => error.failure,
          'failure',
          AnomalyAiFailure.apiError,
        ),
      ),
    );
  });

  test('rejects an empty API key before making a request', () {
    final client = MockClient((_) async => http.Response('', 500));

    expect(
      () => AnomalyAiService(client: client, apiKey: '').generate(_testAlert()),
      throwsA(
        isA<AnomalyAiException>().having(
          (error) => error.failure,
          'failure',
          AnomalyAiFailure.missingApiKey,
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
