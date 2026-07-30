import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysumber/modules/admin/widgets/admin_compact_rail.dart';

void main() {
  testWidgets('shows every admin destination directly in the compact rail',
      (tester) async {
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

    expect(find.byTooltip('Dashboard'), findsOneWidget);
    expect(find.byTooltip('Alerts'), findsOneWidget);
    expect(find.byTooltip('AI Review'), findsOneWidget);
    expect(find.byTooltip('Inventory'), findsOneWidget);
    expect(find.byTooltip('Oversight'), findsOneWidget);
    expect(find.byTooltip('More'), findsNothing);

    await tester.tap(find.byTooltip('Inventory'));
    await tester.pump();
    expect(selectedIndex, 1);
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
    expect(
      tester.getRect(find.byTooltip('AI Review')).bottom,
      lessThanOrEqualTo(cameraCutout.top + 12),
    );
    expect(
      tester.getRect(find.byTooltip('Inventory')).top,
      greaterThanOrEqualTo(cameraCutout.bottom + 8),
    );
  });
}
