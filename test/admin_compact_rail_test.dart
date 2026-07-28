import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysumber/modules/admin/widgets/admin_compact_rail.dart';

void main() {
  testWidgets('keeps secondary destinations in the anchored More menu',
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
    expect(find.text('Inventory'), findsNothing);

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    expect(find.text('Inventory'), findsOneWidget);
    expect(find.text('Oversight'), findsOneWidget);

    await tester.tap(find.text('Inventory'));
    await tester.pump();
    expect(selectedIndex, 1);
  });
}
