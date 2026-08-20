import 'package:flutter_test/flutter_test.dart';

import 'package:mysumber/modules/admin/services/abnormal_production_filter.dart';
import 'package:mysumber/modules/leakage/models/alert.dart';

void main() {
  test('reporting labels are user-facing workflow statuses', () {
    expect(
      AnomalyReportingStatus.label(AnomalyReportingStatus.reported),
      'Reported',
    );
    expect(
      AnomalyReportingStatus.label(AnomalyReportingStatus.unreported),
      'Unreported',
    );
  });

  test('combines search, state, severity, and reporting with AND semantics',
      () {
    expect(
      AbnormalProductionFilter.matches(
        query: 'sel',
        searchableText: 'Selangor 1 Utama Shopping Centre',
        state: 'Selangor',
        severity: Severity.high,
        reported: true,
        selectedState: 'Selangor',
        selectedSeverity: Severity.high,
        selectedReportingStatus: AnomalyReportingStatus.reported,
      ),
      isTrue,
    );

    expect(
      AbnormalProductionFilter.matches(
        query: 'sel',
        searchableText: 'Selangor 1 Utama Shopping Centre',
        state: 'Selangor',
        severity: Severity.high,
        reported: false,
        selectedState: 'Selangor',
        selectedSeverity: Severity.high,
        selectedReportingStatus: AnomalyReportingStatus.reported,
      ),
      isFalse,
    );
  });

  test('null selections represent All', () {
    expect(
      AbnormalProductionFilter.matches(
        query: '',
        searchableText: 'Kedah Aman Central',
        state: 'Kedah',
        severity: Severity.medium,
        reported: false,
      ),
      isTrue,
    );
  });
}
