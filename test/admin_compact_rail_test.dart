import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysumber/modules/admin/widgets/admin_compact_rail.dart';

void main() {
  testWidgets('orders horizontal admin destinations by workflow',
      (tester) async {
    tester.view.physicalSize = const Size(914, 411);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    int? selectedIndex;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AdminCompactRail(
          currentIndex: 0,
          onDestinationSelected: (index) => selectedIndex = index,
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
        body: AdminCompactRail(
          currentIndex: 0,
          onDestinationSelected: (index) => selectedIndex = index,
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

  testWidgets('moves a rail destination clear of a left camera cutout',
      (tester) async {
    tester.view.physicalSize = const Size(914, 411);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 28);
    tester.view.viewPadding = const FakeViewPadding(top: 28);
    tester.view.displayFeatures = const [
      DisplayFeature(
        bounds: Rect.fromLTWH(0, 173, 56, 56),
        type: DisplayFeatureType.cutout,
        state: DisplayFeatureState.unknown,
      ),
    ];
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AdminCompactRail(
          currentIndex: 0,
          onDestinationSelected: (_) {},
        ),
      ),
    ));

    const cameraCutout = Rect.fromLTWH(0, 173, 56, 56);
    final dashboard = tester.getRect(find.byTooltip('Dashboard'));
    final anomalies = tester.getRect(find.byTooltip('Anomalies'));
    final inventory = tester.getRect(find.byTooltip('Mall'));
    final oversight = tester.getRect(find.byTooltip('Oversight'));
    final workers = tester.getRect(find.byTooltip('Workers'));

    // The camera occupies the middle of the rail. Destinations should be
    // evenly distributed in the available segments above and below it,
    // with Inventory above the camera and Anomalies below it.
    expect(
      inventory.bottom,
      lessThanOrEqualTo(cameraCutout.top),
    );
    expect(
      oversight.top,
      greaterThanOrEqualTo(cameraCutout.bottom),
    );
    expect(
      inventory.top - dashboard.bottom,
      closeTo(anomalies.top - inventory.bottom, 1),
    );
    expect(
      workers.top - oversight.bottom,
      greaterThanOrEqualTo(10),
    );
    expect(
      tester.getRect(find.byTooltip('Workers')).bottom,
      lessThan(tester.view.physicalSize.height - 52),
    );
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
        body: AdminCompactRail(
          currentIndex: 0,
          onDestinationSelected: (_) {},
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
        body: AdminCompactRail(
          currentIndex: 0,
          onDestinationSelected: (_) {},
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
