import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mysumber/modules/leakage/models/alert.dart';
import 'package:mysumber/theme/filter_controls.dart';
import 'package:mysumber/theme/segmented_chips.dart';
import 'package:mysumber/theme/tokens.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(800, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  testWidgets('a centered chip row sits in the middle of its viewport',
      (tester) async {
    await _pump(
      tester,
      SegmentedChipRow(
        centered: true,
        children: [
          SegmentedChip(
              label: 'All',
              selected: true,
              onTap: () {},
              color: AppColors.adminPrimary),
          SegmentedChip(
              label: 'Water',
              selected: false,
              onTap: () {},
              color: AppColors.adminPrimary),
        ],
      ),
    );

    // Measure the chip group itself, not `find.byType(Row).first` — each
    // SegmentedChip contains its own Row, so that finder is ambiguous.
    final first = tester.getRect(find.text('All'));
    final last = tester.getRect(find.text('Water'));
    final groupCentre = (first.left + last.right) / 2;
    expect((groupCentre - 400).abs(), lessThan(2.0));
  });

  testWidgets('a default chip row stays left aligned', (tester) async {
    await _pump(
      tester,
      SegmentedChipRow(
        children: [
          SegmentedChip(
              label: 'All',
              selected: true,
              onTap: () {},
              color: AppColors.adminPrimary),
          SegmentedChip(
              label: 'Water',
              selected: false,
              onTap: () {},
              color: AppColors.adminPrimary),
        ],
      ),
    );

    expect(tester.getRect(find.text('All')).left, lessThan(20));
  });

  testWidgets('utility chips report the tapped utility', (tester) async {
    Utility? picked;
    var changed = 0;
    await _pump(
      tester,
      UtilityChips(
        selected: null,
        onChanged: (u) {
          picked = u;
          changed++;
        },
      ),
    );

    await tester.tap(find.text('Electricity'));
    expect(changed, 1);
    expect(picked, Utility.electricity);
  });

  testWidgets('utility chips show counts when given them', (tester) async {
    await _pump(
      tester,
      UtilityChips(
        selected: Utility.water,
        onChanged: (_) {},
        allCount: 9,
        waterCount: 4,
        electricityCount: 5,
      ),
    );

    expect(find.text('All (9)'), findsOneWidget);
    expect(find.text('Water (4)'), findsOneWidget);
    expect(find.text('Electricity (5)'), findsOneWidget);
  });

  testWidgets('a null dropdown value shows the all label', (tester) async {
    await _pump(
      tester,
      FilterDropdown(
        value: null,
        allLabel: 'All States',
        options: const ['Kedah', 'Selangor'],
        onChanged: (_) {},
      ),
    );

    expect(find.text('All States'), findsOneWidget);
  });

  testWidgets('a dropdown can relabel its options', (tester) async {
    await _pump(
      tester,
      FilterDropdown(
        value: 'pending',
        allLabel: 'All Statuses',
        options: const ['pending'],
        labelFor: (s) => 'Pending (3)',
        onChanged: (_) {},
      ),
    );

    expect(find.text('Pending (3)'), findsOneWidget);
  });

  testWidgets('a counts map appends totals to every option and to All',
      (tester) async {
    await _pump(
      tester,
      FilterDropdown(
        value: null,
        allLabel: 'All States',
        options: const ['Kedah', 'Selangor'],
        counts: const {'Kedah': 2, 'Selangor': 5},
        onChanged: (_) {},
      ),
    );

    expect(find.text('All States (7)'), findsOneWidget);
  });

  testWidgets('alert filter bar can present reporting statuses',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await _pump(
      tester,
      AlertFilterBar(
        searchController: controller,
        onSearchChanged: (_) {},
        selectedState: null,
        states: const ['Selangor'],
        stateCounts: const {'Selangor': 1},
        onStateChanged: (_) {},
        selectedSeverity: null,
        severityCounts: const {Severity.high: 1},
        onSeverityChanged: (_) {},
        selectedStatus: 'reported',
        statusOptions: const ['reported', 'unreported'],
        statusCounts: const {'reported': 1, 'unreported': 2},
        onStatusChanged: (_) {},
        statusCaption: 'Reporting',
        statusLabelFor: (value) =>
            value == 'reported' ? 'Reported' : 'Unreported',
      ),
    );

    expect(find.text('Reporting'), findsOneWidget);
    expect(find.text('Reported (1)'), findsOneWidget);
  });

  test('countBy tallies items per key', () {
    final counts =
        countBy(['a', 'bb', 'cc', 'ddd'], (s) => s.length.toString());
    expect(counts, {'1': 1, '2': 2, '3': 1});
  });
}
