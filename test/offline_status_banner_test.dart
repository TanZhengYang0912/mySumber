import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysumber/core/local_database/cache_status.dart';
import 'package:mysumber/core/local_database/offline_status_banner.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('does not show a banner while data is online', (tester) async {
    final status = CacheStatus();

    await tester.pumpWidget(_app(status));

    expect(find.text('Offline data'), findsNothing);
    expect(find.text('Content'), findsOneWidget);
  });

  testWidgets('shows last sync without exposing an error while offline',
      (tester) async {
    final status = CacheStatus()..markOffline(DateTime.utc(2026, 8, 18, 4, 30));

    await tester.pumpWidget(_app(status));

    expect(find.text('Offline data'), findsOneWidget);
    expect(find.textContaining('Last synced'), findsOneWidget);
    expect(find.text('Content'), findsOneWidget);
  });
}

Widget _app(CacheStatus status) => ChangeNotifierProvider.value(
      value: status,
      child: const MaterialApp(
        home: OfflineStatusBanner(
          child: Scaffold(body: Text('Content')),
        ),
      ),
    );
