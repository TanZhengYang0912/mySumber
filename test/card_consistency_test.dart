import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mysumber/modules/leakage/models/alert.dart';
import 'package:mysumber/modules/leakage/models/report.dart';
import 'package:mysumber/modules/leakage/screens/style.dart';
import 'package:mysumber/theme/tokens.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1000, 500);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    ),
  );
}

final _alert = Alert(
  id: 1,
  alertType: AlertType.electricityHotspot,
  state: 'Selangor',
  detectedAt: DateTime(2026, 8, 20),
  signature: LeakSignature.electricityHotspot,
  severity: Severity.high,
  explanation: 'Test alert',
  status: AlertStatus.pending,
);

final _fixedReport = Report(
  id: 7,
  alertId: 1,
  workerName: 'Worker X',
  findings: 'Cable repaired',
  actionTaken: 'Replaced cable joint',
  outcome: ReportOutcome.fixed,
  createdAt: DateTime(2026, 8, 20, 10),
  updatedAt: DateTime(2026, 8, 20, 11),
);

void main() {
  testWidgets('alert pills are status then severity then text-only utility',
      (tester) async {
    await _pump(
      tester,
      AlertCard(
        alert: _alert,
        utility: Utility.electricity,
        onTap: () {},
      ),
    );

    final statusX = tester.getCenter(find.text('Pending')).dx;
    final severityX = tester.getCenter(find.text('High')).dx;
    final utilityX = tester.getCenter(find.text('Electricity')).dx;
    expect(statusX, lessThan(severityX));
    expect(severityX, lessThan(utilityX));

    final utilityPillFinder = find.ancestor(
      of: find.text('Electricity'),
      matching: find.byType(Pill),
    );
    expect(
      find.descendant(of: utilityPillFinder, matching: find.byType(Icon)),
      findsNothing,
    );
  });

  testWidgets(
      'report card uses neutral outcome, rightmost utility, and green edge',
      (tester) async {
    await _pump(
      tester,
      ReportCard(
        report: _fixedReport,
        locationLabel: 'Kelantan',
        utility: Utility.electricity,
        resolvedWorkerName: 'Worker X',
        onTap: () {},
      ),
    );

    expect(
      tester.getCenter(find.text('Fixed')).dx,
      lessThan(tester.getCenter(find.text('Electricity')).dx),
    );
    expect(find.byIcon(Icons.check_circle_outline), findsNothing);
    expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);

    final accent = tester.widget<Container>(
      find.byKey(const ValueKey('report-outcome-accent')),
    );
    expect((accent.decoration! as BoxDecoration).color, AppColors.success);
  });
}
