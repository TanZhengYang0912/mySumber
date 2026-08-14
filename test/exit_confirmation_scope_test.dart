import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mysumber/modules/auth/widgets/exit_confirmation_scope.dart';

void main() {
  testWidgets('asks before leaving the app from the root route',
      (tester) async {
    var exitCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: ExitConfirmationScope(
          onExit: () async => exitCount++,
          child: const Scaffold(body: Text('App home')),
        ),
      ),
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Exit mySumber?'), findsOneWidget);
    expect(find.text('Are you sure you want to exit the app?'), findsOneWidget);
    expect(exitCount, 0);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Exit mySumber?'), findsNothing);
    expect(find.text('App home'), findsOneWidget);
    expect(exitCount, 0);
  });

  testWidgets('exits only after confirmation', (tester) async {
    var exitCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: ExitConfirmationScope(
          onExit: () async => exitCount++,
          child: const Scaffold(body: Text('App home')),
        ),
      ),
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exit'));
    await tester.pumpAndSettle();

    expect(exitCount, 1);
  });
}
