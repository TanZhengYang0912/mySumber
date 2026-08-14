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
          onLogout: () {},
        ),
      ),
    ));

    final dashboard = tester.getRect(find.byTooltip('Dashboard'));
    final inventory = tester.getRect(find.byTooltip('Inventory'));
    final alerts = tester.getRect(find.byTooltip('Alerts'));
    final oversight = tester.getRect(find.byTooltip('Oversight'));

    expect(dashboard.top, lessThan(inventory.top));
    expect(inventory.top, lessThan(alerts.top));
    expect(alerts.top, lessThan(oversight.top));

    await tester.tap(find.byTooltip('Inventory'));
    expect(selectedIndex, 1);
    await tester.tap(find.byTooltip('Alerts'));
    expect(selectedIndex, 2);
  });

  testWidgets('keeps low-frequency destinations inside the more menu',
      (tester) async {
    int? selectedIndex;
    var loggedOut = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AdminCompactRail(
          currentIndex: 0,
          onDestinationSelected: (index) => selectedIndex = index,
          onLogout: () => loggedOut = true,
        ),
      ),
    ));

    expect(find.byTooltip('Dashboard'), findsOneWidget);
    expect(find.byTooltip('Alerts'), findsOneWidget);
    expect(find.byTooltip('Inventory'), findsOneWidget);
    expect(find.byTooltip('Oversight'), findsOneWidget);
    expect(find.byTooltip('More'), findsOneWidget);
    expect(find.byTooltip('Logout'), findsNothing);
    expect(find.byTooltip('AI Review'), findsNothing);
    expect(find.byTooltip('Workers'), findsNothing);

    await tester.tap(find.byTooltip('Inventory'));
    await tester.pump();
    expect(selectedIndex, 1);

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    expect(find.text('AI Review'), findsOneWidget);
    expect(find.text('Workers'), findsOneWidget);
    expect(find.text('Logout'), findsOneWidget);

    await tester.tap(find.text('Workers'));
    await tester.pumpAndSettle();
    expect(selectedIndex, 5);

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AI Review'));
    await tester.pumpAndSettle();
    expect(selectedIndex, 4);

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();
    expect(loggedOut, isTrue);
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
          onLogout: () {},
        ),
      ),
    ));

    const cameraCutout = Rect.fromLTWH(0, 173, 56, 56);
    final dashboard = tester.getRect(find.byTooltip('Dashboard'));
    final alerts = tester.getRect(find.byTooltip('Alerts'));
    final inventory = tester.getRect(find.byTooltip('Inventory'));
    final oversight = tester.getRect(find.byTooltip('Oversight'));
    final more = tester.getRect(find.byTooltip('More'));

    // The camera occupies the middle of the rail. Destinations should be
    // evenly distributed in the available segments above and below it,
    // with Inventory above the camera and Alerts below it.
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
      closeTo(alerts.top - inventory.bottom, 1),
    );
    expect(
      more.top - oversight.bottom,
      greaterThanOrEqualTo(10),
    );
    expect(
      tester.getRect(find.byTooltip('More')).bottom,
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
          onLogout: () {},
        ),
      ),
    ));

    expect(tester.takeException(), isNull);
  });
}
