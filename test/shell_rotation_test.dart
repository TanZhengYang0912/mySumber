import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mysumber/main.dart';

class _FilterProbe extends StatefulWidget {
  const _FilterProbe();

  @override
  State<_FilterProbe> createState() => _FilterProbeState();
}

class _FilterProbeState extends State<_FilterProbe> {
  String _severity = 'all';

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: GestureDetector(
        onTap: () => setState(() => _severity = 'high'),
        child: Text(_severity),
      ),
    );
  }
}

void main() {
  testWidgets('rotating into the rail layout keeps screen filters',
      (tester) async {
    const probe = _FilterProbe();

    Widget shell({required bool landscape}) => MaterialApp(
          home: Scaffold(
            body: RoleShellBody(
              rail: landscape ? const SizedBox(width: 88) : null,
              child: probe,
            ),
          ),
        );

    await tester.pumpWidget(shell(landscape: false));
    expect(find.text('all'), findsOneWidget);

    await tester.tap(find.byType(_FilterProbe));
    await tester.pump();
    expect(find.text('high'), findsOneWidget);

    await tester.pumpWidget(shell(landscape: true));
    await tester.pump();

    expect(find.text('high'), findsOneWidget,
        reason: 'rotation must re-parent the screen stack, not rebuild it');
  });
}
