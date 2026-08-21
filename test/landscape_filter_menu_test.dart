import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysumber/theme/landscape_filter_menu.dart';

void main() {
  testWidgets('opens filter controls from an anchored menu', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LandscapeFilterMenu(
            child: Text('High severity'),
          ),
        ),
      ),
    );

    expect(find.text('High severity'), findsNothing);

    await tester.tap(find.byTooltip('Filter anomalies'));
    await tester.pumpAndSettle();

    expect(find.text('High severity'), findsOneWidget);
  });
}
