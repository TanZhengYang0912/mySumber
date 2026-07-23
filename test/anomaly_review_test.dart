import 'package:flutter_test/flutter_test.dart';

import 'package:mysumber/modules/leakage/models/alert.dart';

void main() {
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
