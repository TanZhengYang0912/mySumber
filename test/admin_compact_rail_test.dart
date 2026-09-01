import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysumber/theme/compact_rail.dart';

const _adminDestinations = [
  RailDestination(icon: Icons.grid_view_outlined, label: 'Dashboard'),
  RailDestination(icon: Icons.location_city_outlined, label: 'Mall'),
  RailDestination(icon: Icons.notifications_outlined, label: 'Anomalies'),
  RailDestination(icon: Icons.shield_outlined, label: 'Oversight'),
  RailDestination(icon: Icons.manage_accounts_outlined, label: 'Workers'),
];

void main() {
  testWidgets('orders horizontal admin destinations by workflow',
      (tester) async {
    tester.view.physicalSize = const Size(914, 411);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    int? selectedIndex;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CompactRail(
          destinations: _adminDestinations,
          currentIndex: 0,
          onDestinationSelected: (index) => selectedIndex = index,
          role: 'admin',
        ),
      ),
    ));

    final dashboard = tester.getRect(find.byTooltip('Dashboard'));
    final inventory = tester.getRect(find.byTooltip('Mall'));
    final anomalies = tester.getRect(find.byTooltip('Anomalies'));
    final oversight = tester.getRect(find.byTooltip('Oversight'));

    expect(dashboard.top, lessThan(inventory.top));
    expect(inventory.top, lessThan(anomalies.top));
    expect(anomalies.top, lessThan(oversight.top));

    await tester.tap(find.byTooltip('Mall'));
    expect(selectedIndex, 1);
    await tester.tap(find.byTooltip('Anomalies'));
    expect(selectedIndex, 2);
  });

  testWidgets('keeps Workers as a direct rail destination without Logout',
      (tester) async {
    int? selectedIndex;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CompactRail(
          destinations: _adminDestinations,
          currentIndex: 0,
          onDestinationSelected: (index) => selectedIndex = index,
          role: 'admin',
        ),
      ),
    ));

    expect(find.byTooltip('Dashboard'), findsOneWidget);
    expect(find.byTooltip('Anomalies'), findsOneWidget);
    expect(find.byTooltip('Mall'), findsOneWidget);
    expect(find.byTooltip('Oversight'), findsOneWidget);
    expect(find.byTooltip('Workers'), findsOneWidget);
    expect(find.byTooltip('More'), findsNothing);
    expect(find.byTooltip('Logout'), findsNothing);

    await tester.tap(find.byTooltip('Mall'));
    await tester.pump();
    expect(selectedIndex, 1);

    await tester.tap(find.byTooltip('Workers'));
    await tester.pump();
    expect(selectedIndex, 4);
  });

  testWidgets(
      'moves the whole rail group clear of a left camera cutout, as one block',
      (tester) async {
    // A realistic phone-landscape size (shortestSide 500 < 600, width >
    // height) with enough slack for the 5-destination admin group (302
    // logical pixels tall) to actually clear a cutout as one contiguous
    // block — the replacement for the old algorithm's "split above/below
    // the cutout" behaviour, which this refactor deliberately removes.
    tester.view.physicalSize = const Size(914, 500);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 28);
    tester.view.viewPadding = const FakeViewPadding(top: 28);
    tester.view.displayFeatures = const [
      DisplayFeature(
        bounds: Rect.fromLTWH(0, 350, 56, 56),
        type: DisplayFeatureType.cutout,
        state: DisplayFeatureState.unknown,
      ),
    ];
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CompactRail(
          destinations: _adminDestinations,
          currentIndex: 0,
          onDestinationSelected: (_) {},
          role: 'admin',
        ),
      ),
    ));

    const cameraCutout = Rect.fromLTWH(0, 350, 56, 56);
    final dashboard = tester.getRect(find.byTooltip('Dashboard'));
    final mall = tester.getRect(find.byTooltip('Mall'));
    final anomalies = tester.getRect(find.byTooltip('Anomalies'));
    final oversight = tester.getRect(find.byTooltip('Oversight'));
    final workers = tester.getRect(find.byTooltip('Workers'));

    // The whole group sits above the cutout — none of it dips below the
    // cutout's top edge, and Workers (the last destination) ends before it.
    expect(workers.bottom, lessThanOrEqualTo(cameraCutout.top));

    // The group moved as one contiguous block: every gap between
    // consecutive destinations is the same, not widened around the
    // obstacle the way the old split-above/below strategy did.
    final gaps = [
      mall.top - dashboard.bottom,
      anomalies.top - mall.bottom,
      oversight.top - anomalies.bottom,
      workers.top - oversight.bottom,
    ];
    for (final gap in gaps.skip(1)) {
      expect(gap, closeTo(gaps.first, 0.5));
    }
  });

  testWidgets('does not throw when the landscape rail has limited height',
      (tester) async {
    tester.view.physicalSize = const Size(914, 300);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 28);
    tester.view.viewPadding = const FakeViewPadding(top: 28);
    tester.view.displayFeatures = const [
      DisplayFeature(
        bounds: Rect.fromLTWH(0, 96, 56, 56),
        type: DisplayFeatureType.cutout,
        state: DisplayFeatureState.unknown,
      ),
    ];
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CompactRail(
          destinations: _adminDestinations,
          currentIndex: 0,
          onDestinationSelected: (_) {},
          role: 'admin',
        ),
      ),
    ));

    expect(tester.takeException(), isNull);
  });

  testWidgets('names every rail destination the way portrait does',
      (tester) async {
    tester.view.physicalSize = const Size(914, 411);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CompactRail(
          destinations: _adminDestinations,
          currentIndex: 0,
          onDestinationSelected: (_) {},
          role: 'admin',
        ),
      ),
    ));

    for (final label in const [
      'Dashboard',
      'Mall',
      'Anomalies',
      'Oversight',
      'Workers',
    ]) {
      expect(find.text(label), findsOneWidget, reason: '$label is unlabelled');
    }
  });
}
