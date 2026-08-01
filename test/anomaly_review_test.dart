import 'package:flutter_test/flutter_test.dart';

import 'package:mysumber/modules/admin/services/anomaly_review_filter.dart';
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

  final alerts = _fixtureAlerts();

  test('default query opens the pending review queue', () {
    final result = AnomalyReviewFilter.apply(
      alerts,
      const AnomalyReviewQuery(),
    );

    expect(result.map((a) => a.status), everyElement(AlertStatus.pending));
    expect(result.map((a) => a.status), isNot(contains(AlertStatus.resolved)));
    expect(result.map((a) => a.status), isNot(contains(AlertStatus.faults)));
  });

  test('Oversight default keeps every pending severity and ranks high first', () {
    final result = AnomalyReviewFilter.apply(
      [
        ...alerts,
        Alert(
          id: 6,
          alertType: AlertType.nrwHotspot,
          state: 'Selangor',
          detectedAt: DateTime.utc(2026, 7, 30),
          signature: 'new_medium_pending',
          severity: Severity.medium,
          explanation: 'Medium priority pending alert.',
          status: AlertStatus.pending,
        ),
      ],
      const AnomalyReviewQuery(statuses: {AlertStatus.pending}),
    );

    expect(result.map((alert) => alert.status), everyElement(AlertStatus.pending));
    expect(result.take(2).map((alert) => alert.id), [1, 6]);
  });

  test('Ongoing high-severity query retains investigating and not-fixed alerts',
      () {
    final ongoingHigh = AnomalyReviewFilter.apply(
      alerts,
      const AnomalyReviewQuery(
        statuses: {AlertStatus.investigating, AlertStatus.notFixed},
        highSeverityOnly: true,
      ),
    );

    expect(ongoingHigh.map((alert) => alert.id), [5]);
  });

  test('filters by utility, state, facility, and equipment', () {
    final result = AnomalyReviewFilter.apply(
      alerts,
      const AnomalyReviewQuery(
        statuses: {AlertStatus.pending},
        utility: Utility.water,
        state: 'Selangor',
        facilityName: '1 Utama Shopping Centre',
        equipmentName: 'Main Water Pump A1',
      ),
    );

    expect(result, hasLength(1));
    expect(result.single.facilityName, '1 Utama Shopping Centre');
  });

  test('normalizes a removed live filter option to all', () {
    expect(
      AnomalyReviewFilter.normalizeOption(
        '1 Utama Shopping Centre',
        const ['Aman Central'],
      ),
      isNull,
    );
    expect(
      AnomalyReviewFilter.normalizeOption(
        'Main Water Pump A1',
        const ['Main Water Pump A1'],
      ),
      'Main Water Pump A1',
    );
  });

  test('combines ongoing status with the high-severity filter', () {
    final result = AnomalyReviewFilter.apply(
      alerts,
      const AnomalyReviewQuery(
        statuses: {AlertStatus.investigating, AlertStatus.notFixed},
        highSeverityOnly: true,
      ),
    );

    expect(result.map((alert) => alert.id), [5]);
  });

  test('orders review results by severity, pending status, then recency', () {
    final result = AnomalyReviewFilter.apply(
      alerts,
      AnomalyReviewQuery(statuses: AlertStatus.all.toSet()),
    );

    expect(result.take(3).map((alert) => alert.id), [1, 5, 2]);
  });

  test('option lists are unique, sorted, and state-aware', () {
    expect(AnomalyReviewFilter.states(alerts), ['Kedah', 'Selangor']);
    expect(
      AnomalyReviewFilter.facilities(alerts, state: 'Selangor'),
      ['1 Utama Shopping Centre'],
    );
    expect(
      AnomalyReviewFilter.equipment(
        alerts,
        state: 'Selangor',
        facilityName: '1 Utama Shopping Centre',
      ),
      ['Main Water Pump A1', 'Sub-Transformer B2'],
    );
  });
}

List<Alert> _fixtureAlerts() => [
      Alert(
        id: 1,
        alertType: AlertType.nrwHotspot,
        state: 'Selangor',
        detectedAt: DateTime.utc(2026, 7, 23),
        signature: 'nrw_hotspot',
        severity: Severity.high,
        explanation: 'Water usage exceeded the baseline.',
        status: AlertStatus.pending,
        facilityName: '1 Utama Shopping Centre',
        facilityCity: 'Petaling Jaya',
        equipmentName: 'Main Water Pump A1',
      ),
      Alert(
        id: 2,
        alertType: AlertType.nrwHotspot,
        state: 'Kedah',
        detectedAt: DateTime.utc(2026, 7, 22),
        signature: 'nrw_hotspot',
        severity: Severity.medium,
        explanation: 'Water usage is still above baseline.',
        status: AlertStatus.investigating,
        facilityName: 'Aman Central',
        facilityCity: 'Alor Setar',
        equipmentName: 'Cooling Tower Valve',
      ),
      Alert(
        id: 3,
        alertType: AlertType.electricityHotspot,
        state: 'Selangor',
        detectedAt: DateTime.utc(2026, 7, 21),
        signature: 'electricity_hotspot',
        severity: Severity.low,
        explanation: 'Electricity loss returned to baseline.',
        status: AlertStatus.resolved,
        facilityName: '1 Utama Shopping Centre',
        facilityCity: 'Petaling Jaya',
        equipmentName: 'Sub-Transformer B2',
      ),
      Alert(
        id: 4,
        alertType: AlertType.electricityHotspot,
        state: 'Selangor',
        detectedAt: DateTime.utc(2026, 7, 20),
        signature: 'electricity_hotspot',
        severity: Severity.low,
        explanation: 'The pattern was classified as a fault.',
        status: AlertStatus.faults,
        facilityName: '1 Utama Shopping Centre',
        facilityCity: 'Petaling Jaya',
        equipmentName: 'Sub-Transformer B2',
      ),
      Alert(
        id: 5,
        alertType: AlertType.electricityHotspot,
        state: 'Selangor',
        detectedAt: DateTime.utc(2026, 7, 24),
        signature: 'electricity_hotspot',
        severity: Severity.high,
        explanation: 'Electricity loss remains above baseline.',
        status: AlertStatus.investigating,
        facilityName: '1 Utama Shopping Centre',
        facilityCity: 'Petaling Jaya',
        equipmentName: 'Sub-Transformer B2',
      ),
    ];
