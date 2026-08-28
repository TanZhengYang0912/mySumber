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

  test('Alert round-trips facility and equipment metadata', () {
    final original = Alert(
      id: 7,
      alertType: AlertType.nrwHotspot,
      state: 'Selangor',
      detectedAt: DateTime.utc(2026, 7, 23),
      signature: 'nrw_hotspot',
      severity: Severity.high,
      explanation: 'Water usage exceeded the baseline.',
      equipmentNodeId: 'node-1',
      facilityName: '1 Utama Shopping Centre',
      facilityCity: 'Petaling Jaya',
      equipmentName: 'Main Water Pump A1',
    );

    final restored = Alert.fromMap(original.toMap());

    expect(restored.equipmentNodeId, 'node-1');
    expect(restored.facilityName, '1 Utama Shopping Centre');
    expect(restored.facilityCity, 'Petaling Jaya');
    expect(restored.equipmentName, 'Main Water Pump A1');
  });

  test('Alert reads legacy rows without location columns', () {
    final legacy = Alert.fromMap({
      'id': 8,
      'alert_type': AlertType.nrwHotspot,
      'state': 'Kedah',
      'detected_at': '2026-07-23T00:00:00.000Z',
      'signature': 'nrw_hotspot',
      'severity': Severity.medium,
      'baseline_l': 100,
      'actual_l': 150,
      'explanation': 'Usage exceeded the baseline.',
      'status': AlertStatus.pending,
      'is_deleted': false,
    });

    expect(legacy.facilityName, isNull);
    expect(legacy.equipmentName, isNull);
  });
}
