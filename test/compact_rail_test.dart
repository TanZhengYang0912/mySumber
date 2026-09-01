import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysumber/theme/compact_rail.dart';
import 'package:mysumber/theme/tokens.dart';

const _three = [
  RailDestination(icon: Icons.water_drop_outlined, label: 'Water'),
  RailDestination(icon: Icons.electric_bolt_outlined, label: 'Electricity'),
  RailDestination(icon: Icons.description_outlined, label: 'Reports'),
];

/// The rail fills the viewport height, the way it does inside RoleShellBody.
/// Wrapping it in a fixed-height SizedBox would both overflow a 411-tall test
/// viewport and leave the group nowhere to move when dodging a cutout.
Widget _host({
  int currentIndex = 0,
  ValueChanged<int>? onSelected,
  String role = 'worker',
  double width = 88,
  List<RailDestination> destinations = _three,
}) =>
    MaterialApp(
      home: Scaffold(
        body: Row(
          children: [
            CompactRail(
              destinations: destinations,
              currentIndex: currentIndex,
              onDestinationSelected: onSelected ?? (_) {},
              role: role,
              width: width,
            ),
            const Expanded(child: SizedBox()),
          ],
        ),
      ),
    );

void main() {
  testWidgets('destinations are centred as a group', (tester) async {
    tester.view.physicalSize = const Size(914, 411);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host());

    final rail = tester.getRect(find.byType(CompactRail));
    final first = tester.getRect(find.byTooltip('Water'));
    final last = tester.getRect(find.byTooltip('Reports'));

    final gapAbove = first.top - rail.top;
    final gapBelow = rail.bottom - last.bottom;
    expect((gapAbove - gapBelow).abs(), lessThan(1.0));
  });

  testWidgets('destinations keep their declared order', (tester) async {
    tester.view.physicalSize = const Size(914, 411);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host());

    final water = tester.getRect(find.byTooltip('Water'));
    final electricity = tester.getRect(find.byTooltip('Electricity'));
    final reports = tester.getRect(find.byTooltip('Reports'));

    expect(water.top, lessThan(electricity.top));
    expect(electricity.top, lessThan(reports.top));
  });

  testWidgets('tapping a destination reports its index', (tester) async {
    tester.view.physicalSize = const Size(914, 411);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    int? selected;
    await tester.pumpWidget(_host(onSelected: (index) => selected = index));

    await tester.tap(find.byTooltip('Reports'));
    expect(selected, 2);

    await tester.tap(find.byTooltip('Electricity'));
    expect(selected, 1);
  });

  testWidgets('the selected destination wears its role colour',
      (tester) async {
    tester.view.physicalSize = const Size(914, 411);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(currentIndex: 1, role: 'worker'));

    final icon = tester.widget<Icon>(
      find.descendant(
        of: find.byTooltip('Electricity'),
        matching: find.byType(Icon),
      ),
    );
    expect(icon.color, AppColors.workerPrimary);

    final unselected = tester.widget<Icon>(
      find.descendant(
        of: find.byTooltip('Water'),
        matching: find.byType(Icon),
      ),
    );
    expect(unselected.color, AppColors.textTertiary);
  });

  testWidgets('a customer rail uses the customer palette', (tester) async {
    tester.view.physicalSize = const Size(914, 411);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(currentIndex: 0, role: 'user', width: 72));

    final icon = tester.widget<Icon>(
      find.descendant(
        of: find.byTooltip('Water'),
        matching: find.byType(Icon),
      ),
    );
    expect(icon.color, AppColors.customerPrimary);
    expect(tester.getRect(find.byType(CompactRail)).width, 72);
  });

  testWidgets('a camera cutout moves the whole group clear', (tester) async {
    tester.view.physicalSize = const Size(914, 411);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(914, 411),
          displayFeatures: [
            ui.DisplayFeature(
              bounds: Rect.fromLTRB(20, 150, 60, 190),
              type: ui.DisplayFeatureType.cutout,
              state: ui.DisplayFeatureState.unknown,
            ),
          ],
        ),
        child: _host(),
      ),
    );

    for (final label in ['Water', 'Electricity', 'Reports']) {
      final rect = tester.getRect(find.byTooltip(label));
      expect(
        rect.top < 190 && rect.bottom > 150,
        isFalse,
        reason: '$label still sits under the cutout',
      );
    }
  });
}
