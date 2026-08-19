import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mysumber/modules/leakage/models/alert.dart';
import 'package:mysumber/modules/leakage/services/worker_dashboard_summary.dart';
import 'package:mysumber/modules/leakage/services/worker_investigation_flow.dart';
import 'package:mysumber/modules/leakage/services/worker_utility_colors.dart';
import 'package:mysumber/modules/leakage/widgets/worker_compact_rail.dart';
import 'package:mysumber/theme/tokens.dart';

Alert _alert({
  required Utility utility,
  required String severity,
  required String status,
  String? state,
  double? lossPct,
  double baselineL = 0,
  double actualL = 0,
}) {
  final isElectricity = utility == Utility.electricity;
  return Alert(
    alertType:
        isElectricity ? AlertType.electricityHotspot : AlertType.nrwHotspot,
    state: state ?? (isElectricity ? 'Johor' : 'Selangor'),
    detectedAt: DateTime(2026, 8, 1),
    signature: isElectricity
        ? LeakSignature.electricityHotspot
        : LeakSignature.nrwHotspot,
    severity: severity,
    status: status,
    explanation: 'Test alert',
    lossPct: lossPct,
    producedMld: lossPct == null ? null : 1000,
    billedMld: lossPct == null ? null : 1000 - (lossPct * 10),
    lossMld: lossPct == null ? null : lossPct * 10,
    baselineL: baselineL,
    actualL: actualL,
  );
}

void main() {
  test('keeps the existing utility colors for worker identity surfaces', () {
    expect(workerUtilityPrimary(Utility.water), AppColors.workerPrimary);
    expect(
      workerUtilityPrimary(Utility.electricity),
      AppColors.electricityAccent,
    );
    expect(workerUtilitySurface(Utility.water), AppColors.workerSurface);
    expect(
      workerUtilitySurface(Utility.electricity),
      AppColors.electricitySurface,
    );
  });

  test('keeps water and electricity work queues separate', () {
    final summary = summarizeWorkerDashboard(
      alerts: [
        _alert(
          utility: Utility.water,
          severity: Severity.high,
          status: AlertStatus.pending,
        ),
        _alert(
          utility: Utility.electricity,
          severity: Severity.high,
          status: AlertStatus.pending,
        ),
      ],
      utility: Utility.water,
    );

    expect(summary.activeCount, 1);
    expect(summary.pendingCount, 1);
    expect(summary.priorityAlert?.utility, Utility.water);
  });

  test('chooses a high severity alert over a newer low severity alert', () {
    final high = _alert(
      utility: Utility.water,
      severity: Severity.high,
      status: AlertStatus.pending,
      state: 'Selangor',
    );
    final low = _alert(
      utility: Utility.water,
      severity: Severity.low,
      status: AlertStatus.pending,
      state: 'Johor',
    );

    final summary = summarizeWorkerDashboard(
      alerts: [low, high],
      utility: Utility.water,
    );

    expect(summary.priorityAlert, high);
  });

  test('prioritizes follow-up work before a new alert of equal severity', () {
    final pending = _alert(
      utility: Utility.electricity,
      severity: Severity.high,
      status: AlertStatus.pending,
    );
    final followUp = _alert(
      utility: Utility.electricity,
      severity: Severity.high,
      status: AlertStatus.notFixed,
    );

    final summary = summarizeWorkerDashboard(
      alerts: [pending, followUp],
      utility: Utility.electricity,
    );

    expect(summary.priorityAlert, followUp);
    expect(summary.followUpCount, 1);
  });

  test('opens the alert details after a pending alert starts investigation',
      () {
    expect(
      shouldOpenAlertDetailsAfterInvestigationStart(AlertStatus.pending),
      isTrue,
    );
  });

  test('does not treat an already resolved alert as a new investigation', () {
    expect(
      shouldOpenAlertDetailsAfterInvestigationStart(AlertStatus.resolved),
      isFalse,
    );
  });

  testWidgets('keeps Water above Electricity when Electricity is selected',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkerCompactRail(
            currentIndex: 1,
            onDestinationSelected: (_) {},
            onLogout: () {},
          ),
        ),
      ),
    );

    expect(
      tester.getTopLeft(find.text('Water')).dy,
      lessThan(tester.getTopLeft(find.text('Electricity')).dy),
    );
  });
}
