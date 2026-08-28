import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mysumber/core/local_database/cache_status.dart';
import 'package:mysumber/core/local_database/local_database.dart';
import 'package:mysumber/modules/admin/screens/oversight_screen.dart';
import 'package:mysumber/theme/app_tab_bar.dart';
import 'package:mysumber/modules/auth/state/auth_state.dart';
import 'package:mysumber/modules/leakage/data/leakage_repository.dart';
import 'package:mysumber/modules/leakage/services/baseline_service.dart';
import 'package:mysumber/modules/leakage/services/nrw_service.dart';
import 'package:mysumber/modules/leakage/services/simulation_service.dart';
import 'package:mysumber/modules/leakage/state/app_state.dart';
import 'package:mysumber/theme/filter_controls.dart';
import 'package:mysumber/theme/responsive_filter_bar.dart';

// Oversight used to keep two independent filter models: portrait's
// a landscape-only set of
// ChoiceChips and a "High severity only" toggle with no portrait
// equivalent. Rotating the phone silently discarded whatever was filtered.
// These tests pin landscape to render the exact same shared widgets
// portrait does, with no chip-only capability surviving alongside them.
void main() {
  late LocalDatabase database;
  late LeakageRepository repository;

  setUpAll(() {
    database = LocalDatabase.forTesting(NativeDatabase.memory());
    repository = LeakageRepository.withRemote(
      remote: _UnusedLeakageRemote(),
      database: database,
      cacheStatus: CacheStatus(),
    );
  });
  tearDownAll(() => database.close());

  testWidgets('landscape Oversight filters with the portrait controls',
      (tester) async {
    tester.view.physicalSize = const Size(914, 411);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider<AppState>.value(
              value: _stubAppState(repository),
            ),
            ChangeNotifierProvider<RoleState>(create: (_) => RoleState()),
          ],
          child: const OversightScreen(),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();

    // The burger must contain the exact same shared shell portrait renders.
    expect(find.byType(ResponsiveFilterBar), findsOneWidget);
    expect(find.byType(FilterDropdown), findsNWidgets(4));
    expect(find.byType(FilterSearchField), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.text('High severity'), findsNothing);
  });

  testWidgets('landscape Reports filters with the portrait controls',
      (tester) async {
    tester.view.physicalSize = const Size(914, 411);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider<AppState>.value(
              value: _stubAppState(repository),
            ),
            ChangeNotifierProvider<RoleState>(create: (_) => RoleState()),
          ],
          child:
              const OversightScreen(initialSection: OversightSection.reports),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();

    expect(find.byType(ResponsiveFilterBar), findsOneWidget);
    expect(find.byType(FilterDropdown), findsNWidgets(3));
    expect(find.byType(FilterSearchField), findsOneWidget);
  });

  testWidgets('landscape Oversight drops its landscape-only chrome',
      (tester) async {
    tester.view.physicalSize = const Size(914, 411);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider<AppState>.value(
              value: _stubAppState(repository),
            ),
            ChangeNotifierProvider<RoleState>(create: (_) => RoleState()),
          ],
          child: const OversightScreen(),
        ),
      ),
    );
    await tester.pump();

    // The pending badge and the Report State bell existed only in landscape.
    expect(find.textContaining('pending'), findsNothing);
    expect(find.byIcon(Icons.add_alert_outlined), findsNothing);
    // Tabs, not a segmented pill, and the same card portrait renders.
    expect(find.byType(SegmentedButton<int>), findsNothing);
    expect(find.byType(AppTabBar), findsOneWidget);
  });
}

AppState _stubAppState(LeakageRepository repository) => AppState(
      baseline: BaselineService(),
      nrw: NrwService(),
      repository: repository,
      simulation: SimulationService(
        baseline: BaselineService(),
        repository: repository,
      ),
    );

class _UnusedLeakageRemote implements LeakageRemoteStore {
  Never _unsupported() =>
      throw UnimplementedError('Not used by this widget test.');

  @override
  Future<Map<String, Object?>> insertAlert(Map<String, Object?> row) async =>
      _unsupported();

  @override
  Future<Map<String, Object?>> insertReading(Map<String, Object?> row) async =>
      _unsupported();

  @override
  Future<Map<String, Object?>> insertReport(Map<String, Object?> row) async =>
      _unsupported();

  @override
  Future<Map<String, Object?>?> alertById(int id) async => _unsupported();

  @override
  Future<List<Map<String, Object?>>> alerts({
    required bool includeDismissed,
  }) async =>
      _unsupported();

  @override
  Future<List<Map<String, Object?>>> readings() async => _unsupported();

  @override
  Future<List<Map<String, Object?>>> reports({
    required bool includeDeleted,
  }) async =>
      _unsupported();

  @override
  Future<Map<String, Object?>> setReportDeleted(int id, bool isDeleted) async =>
      _unsupported();

  @override
  Future<Map<String, Object?>> updateAlertLocation({
    required int id,
    String? equipmentNodeId,
    String? facilityName,
    String? facilityCity,
    String? equipmentName,
  }) async =>
      _unsupported();

  @override
  Future<Map<String, Object?>> updateAlertStatus(
    int id,
    String status, {
    String? handledBy,
    String? handledById,
  }) async =>
      _unsupported();
}
