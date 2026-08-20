import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mysumber/modules/leakage/models/alert.dart';
import 'package:mysumber/modules/leakage/models/report.dart';
import 'package:mysumber/modules/leakage/screens/style.dart';
import 'package:mysumber/theme/tokens.dart';

BoxDecoration _decorationOf(WidgetTester tester) {
  final container = tester.widget<Container>(
    find.descendant(of: find.byType(Pill), matching: find.byType(Container)),
  );
  return container.decoration! as BoxDecoration;
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: Center(child: child))),
  );
}

void main() {
  test('severity labels drop the word Severity', () {
    expect(Severity.label(Severity.high), 'High');
    expect(Severity.label(Severity.medium), 'Medium');
    expect(Severity.label(Severity.low), 'Low');
  });

  testWidgets('a filled pill keeps a tinted background and no border',
      (tester) async {
    await _pump(tester, const Pill('Water', color: Colors.blue));

    final decoration = _decorationOf(tester);
    expect(decoration.border, isNull);
    expect(decoration.color, isNot(Colors.transparent));
  });

  testWidgets('an outlined pill has a coloured border and no fill',
      (tester) async {
    await _pump(
        tester, const Pill('Water', color: Colors.blue, outlined: true));

    final decoration = _decorationOf(tester);
    expect(decoration.color, Colors.transparent);
    expect((decoration.border! as Border).top.color, Colors.blue);
  });

  testWidgets('severityPill is outlined and uses the severity colour',
      (tester) async {
    await _pump(tester, severityPill(Severity.high));

    expect(find.text('High'), findsOneWidget);
    final decoration = _decorationOf(tester);
    expect(decoration.color, Colors.transparent);
    expect(
        (decoration.border! as Border).top.color, severityColor(Severity.high));
  });

  testWidgets('statusPill is outlined and uses the status colour',
      (tester) async {
    await _pump(tester, statusPill(AlertStatus.notFixed));

    expect(find.text('Not Fixed'), findsOneWidget);
    final decoration = _decorationOf(tester);
    expect(decoration.color, Colors.transparent);
    expect((decoration.border! as Border).top.color,
        statusColor(AlertStatus.notFixed));
  });

  test('status colour is the requested lighter grey', () {
    expect(statusColor(AlertStatus.pending), const Color(0xFF6B7280));
    expect(statusColor(AlertStatus.notFixed), const Color(0xFF6B7280));
  });

  testWidgets('fixed and not-fixed outcomes reuse the status pill treatment',
      (tester) async {
    for (final outcome in [ReportOutcome.fixed, ReportOutcome.notFixed]) {
      await _pump(tester, outcomePill(outcome));
      final decoration = _decorationOf(tester);
      expect(decoration.color, Colors.transparent);
      expect(
        (decoration.border! as Border).top.color,
        const Color(0xFF6B7280),
      );
    }
  });
}
