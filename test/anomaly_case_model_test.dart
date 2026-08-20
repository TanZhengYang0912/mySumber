import 'package:flutter_test/flutter_test.dart';
import 'package:mysumber/modules/leakage/models/alert.dart';
import 'package:mysumber/modules/leakage/models/anomaly_case.dart';

void main() {
  test('household case preserves its source, utility, and saved AI result', () {
    final anomalyCase = AnomalyCase.fromMap({
      'id': '7199ec20-cb82-4ea8-aecc-c78adc7e00d1',
      'source_scope': 'household',
      'source_key': 'household:demo:H-305',
      'utility': 'electricity',
      'state': 'Selangor',
      'household_id': 'H-305',
      'severity': 'medium',
      'explanation': 'Kitchen lights repeatedly flicker.',
      'evidence': {'actual_l': 280, 'baseline_l': 150},
      'status': 'pending_review',
      'ai_summary': 'The pattern may be caused by an unstable circuit.',
      'ai_possible_cause': 'Loose connection',
      'ai_severity_assessment': 'Medium',
      'ai_recommendation': 'Inspect the consumer unit.',
      'ai_confidence': 0.8,
      'ai_generated_at': '2026-08-20T12:00:00.000Z',
      'created_at': '2026-08-20T11:59:00.000Z',
      'updated_at': '2026-08-20T12:00:00.000Z',
    });

    expect(anomalyCase.title, 'Selangor · H-305');
    expect(anomalyCase.utility, Utility.electricity);
    expect(anomalyCase.sourceLabel, 'Household');
    expect(anomalyCase.hasAiAnalysis, isTrue);
  });

  test('persisted utility type keeps a household electricity alert electric',
      () {
    final alert = Alert.fromMap({
      'id': 99,
      'alert_type': AlertType.household,
      'source_scope': AlertSourceScope.household,
      'utility_type': 'electricity',
      'household_id': 'H-305',
      'state': 'Selangor',
      'detected_at': '2026-08-20T12:00:00.000Z',
      'signature': 'Household utility problem',
      'severity': Severity.medium,
      'baseline_l': 150,
      'actual_l': 280,
      'explanation': 'Kitchen lights repeatedly flicker.',
      'status': AlertStatus.pending,
      'is_deleted': false,
    });

    expect(alert.utility, Utility.electricity);
    expect(alert.toMap()['utility_type'], 'electricity');
  });
}
