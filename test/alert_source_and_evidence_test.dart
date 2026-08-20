import 'package:flutter_test/flutter_test.dart';

import 'package:mysumber/modules/leakage/models/alert.dart';
import 'package:mysumber/modules/leakage/screens/alert_evidence.dart';

void main() {
  test('mall alert uses its mall title instead of State balance evidence', () {
    final alert = Alert(
      alertType: AlertType.nrwHotspot,
      sourceScope: AlertSourceScope.mall,
      state: 'Selangor',
      facilityName: '1 Utama Shopping Centre',
      equipmentName: 'Main Water Pump',
      detectedAt: DateTime.utc(2026, 8, 20),
      signature: LeakSignature.nrwHotspot,
      severity: Severity.high,
      explanation: 'Usage exceeded its normal baseline.',
    );

    expect(alert.title, '1 Utama Shopping Centre');
    expect(alert.sourceLabel, 'Mall');
    expect(alertEvidenceKindFor(alert), AlertEvidenceKind.mallUsage);
  });

  test('incomplete State balance alert selects unavailable evidence', () {
    final alert = Alert(
      alertType: AlertType.electricityHotspot,
      sourceScope: AlertSourceScope.state,
      state: 'Sabah',
      detectedAt: DateTime.utc(2026, 8, 20),
      signature: LeakSignature.electricityHotspot,
      severity: Severity.high,
      explanation: 'Electricity loss is above the expected range.',
    );

    expect(alert.canRenderBalanceEvidence, isFalse);
    expect(alertEvidenceKindFor(alert), AlertEvidenceKind.unavailable);
  });

  test('legacy equipment alert is inferred as Mall even without source scope',
      () {
    final alert = Alert.fromMap({
      'id': 83,
      'alert_type': AlertType.electricityHotspot,
      'equipment_node_id': 'node-901',
      'facility_name': 'Trigger Test Mall',
      'equipment_name': 'Test Main Transformer',
      'state': 'Selangor',
      'detected_at': '2026-08-20T13:00:03.11845Z',
      'signature': LeakSignature.electricityHotspot,
      'severity': Severity.high,
      'explanation': 'Equipment usage is above baseline.',
      'status': AlertStatus.pending,
      'is_deleted': false,
    });

    expect(alert.sourceScope, AlertSourceScope.mall);
    expect(alertEvidenceKindFor(alert), AlertEvidenceKind.mallUsage);
  });
}
