import 'package:flutter_test/flutter_test.dart';

import 'package:mysumber/modules/dataset/services/dashboard_overview.dart';
import 'package:mysumber/modules/dataset/services/mall_summary.dart';
import 'package:mysumber/modules/leakage/models/alert.dart';

MallSummary _mall(String water, String electricity) => MallSummary(
      name: 'Test Mall',
      state: 'Selangor',
      city: 'Petaling Jaya',
      waterUsage: 0,
      electricityUsage: 0,
      waterStatus: water,
      electricityStatus: electricity,
      attentionCount: 0,
      lastUpdated: null,
      nodes: const [],
    );

Alert _alert(String status) => Alert(
      alertType: 'leak',
      state: 'Selangor',
      detectedAt: DateTime(2026, 8, 28),
      signature: 'sig-$status',
      severity: 'high',
      explanation: 'test',
      status: status,
    );

void main() {
  test('mall counts use the worse of the two utility statuses', () {
    final counts = mallStatusCounts([
      _mall('Critical', 'Active'),
      _mall('Active', 'Maintenance'),
      _mall('Active', 'Active'),
    ]);

    expect(counts.total, 3);
    expect(counts.critical, 1);
    expect(counts.maintenance, 1);
    expect(counts.active, 1);
  });

  test('mall counts never fold Maintenance into Warning', () {
    final counts = mallStatusCounts([
      _mall('Maintenance', 'Active'),
      _mall('Maintenance', 'Active'),
    ]);

    expect(counts.maintenance, 2);
    expect(counts.warning, 0);
  });

  test('mall counts report Warning on its own', () {
    final counts = mallStatusCounts([_mall('Warning', 'Active')]);

    expect(counts.warning, 1);
    expect(counts.maintenance, 0);
    expect(counts.active, 0);
  });

  test('mall counts leave the total independent of the buckets', () {
    final counts = mallStatusCounts([_mall('Unknown', 'Unknown')]);

    expect(counts.total, 1);
    expect(counts.active, 0);
    expect(counts.warning, 0);
    expect(counts.maintenance, 0);
    expect(counts.critical, 0);
  });

  test('anomaly counts group the lifecycle into four buckets', () {
    final counts = anomalyCounts([
      _alert(AlertStatus.pendingReview),
      _alert(AlertStatus.pending),
      _alert(AlertStatus.investigating),
      _alert(AlertStatus.notFixed),
      _alert(AlertStatus.resolved),
      _alert(AlertStatus.faults),
      _alert(AlertStatus.dismissed),
    ]);

    expect(counts.toReview, 1);
    expect(counts.ongoing, 3);
    expect(counts.resolved, 1);
    expect(counts.rejected, 2);
  });

  test('every alert status lands in exactly one bucket', () {
    final alerts = [
      for (final status in [
        AlertStatus.pendingReview,
        AlertStatus.faults,
        ...AlertStatus.all,
      ])
        _alert(status),
    ];
    final counts = anomalyCounts(alerts);

    expect(
      counts.toReview + counts.ongoing + counts.resolved + counts.rejected,
      alerts.length,
    );
  });

  test('anomaly counts are all zero for an empty queue', () {
    final counts = anomalyCounts(const []);

    expect(counts.toReview, 0);
    expect(counts.ongoing, 0);
    expect(counts.resolved, 0);
    expect(counts.rejected, 0);
  });
}
