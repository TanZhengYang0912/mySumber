import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mysumber/core/local_database/cache_status.dart';
import 'package:mysumber/core/local_database/local_database.dart';
import 'package:mysumber/modules/admin/data/worker_repository.dart';
import 'package:mysumber/modules/admin/models/worker_account.dart';
import 'package:mysumber/modules/admin/screens/abnormal_production_screen.dart';
import 'package:mysumber/modules/admin/screens/worker_accounts_screen.dart';
import 'package:mysumber/modules/auth/state/auth_state.dart';
import 'package:mysumber/modules/dataset/data/dataset_repository.dart';
import 'package:mysumber/modules/dataset/models/models.dart';
import 'package:mysumber/modules/dataset/screens/inventory_screen.dart';
import 'package:mysumber/modules/dataset/state/dataset_state.dart';
import 'package:mysumber/modules/leakage/data/leakage_repository.dart';
import 'package:mysumber/modules/leakage/models/alert.dart';
import 'package:mysumber/modules/leakage/services/baseline_service.dart';
import 'package:mysumber/modules/leakage/services/nrw_service.dart';
import 'package:mysumber/modules/leakage/services/simulation_service.dart';
import 'package:mysumber/modules/leakage/state/app_state.dart';
import 'package:mysumber/theme/filter_controls.dart';
import 'package:mysumber/theme/page_header.dart';
import 'package:mysumber/theme/responsive_filter_bar.dart';
import 'package:mysumber/theme/tokens.dart';

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

  testWidgets('Anomalies moves filters into its landscape menu',
      (tester) async {
    tester.view.physicalSize = const Size(914, 411);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: _ReadyAppState(repository),
        child: const MaterialApp(home: AbnormalProductionScreen()),
      ),
    );

    expect(find.byTooltip('Filter anomalies'), findsOneWidget);
    expect(find.byType(ResponsiveFilterBar), findsOneWidget);

    await tester.tap(find.byTooltip('Filter anomalies'));
    await tester.pumpAndSettle();
    expect(find.byType(FilterDropdown), findsNWidgets(4));
  });

  testWidgets('Anomalies keeps its filters inline in portrait', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: _ReadyAppState(repository),
        child: const MaterialApp(home: AbnormalProductionScreen()),
      ),
    );

    expect(find.byTooltip('Filter anomalies'), findsNothing);
    expect(find.byType(ResponsiveFilterBar), findsOneWidget);
    expect(find.byType(FilterDropdown), findsNWidgets(4));
  });

  testWidgets('Anomaly utility counts survive selecting Water', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: _ReadyAppState(
          repository,
          alerts: [
            _filterAlert(1, utilityType: 'water'),
            _filterAlert(
              2,
              utilityType: 'electricity',
              alertType: AlertType.electricityHotspot,
            ),
          ],
        ),
        child: const MaterialApp(home: AbnormalProductionScreen()),
      ),
    );

    var utility = tester.widget<UtilityFilterDropdown>(
      find.byType(UtilityFilterDropdown).first,
    );
    expect(utility.counts, {'water': 1, 'electricity': 1});

    utility.onChanged(Utility.water);
    await tester.pump();

    utility = tester.widget<UtilityFilterDropdown>(
      find.byType(UtilityFilterDropdown).first,
    );
    expect(utility.value, Utility.water);
    expect(utility.counts, {'water': 1, 'electricity': 1});
  });

  testWidgets('Mall opens its state filter from the landscape menu',
      (tester) async {
    tester.view.physicalSize = const Size(914, 411);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final datasetState = _StaticDatasetState()
      ..nodes = const [
        EquipmentNode(
          nodeName: 'Main Water Pump A1',
          utilityType: 'Water',
          zoneId: 'Selangor',
          facilityName: '1 Utama Shopping Centre',
          status: 'Active',
        ),
      ];

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<DatasetState>.value(
          value: datasetState,
          child: const InventoryScreen(),
        ),
      ),
    );

    expect(find.byTooltip('Filter malls'), findsOneWidget);
    expect(find.text('Status'), findsNothing);

    await tester.tap(find.byTooltip('Filter malls'));
    await tester.pumpAndSettle();
    expect(find.text('Status'), findsOneWidget);
    expect(find.text('Type anything to search'), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    final headerBottom = tester.getBottomLeft(find.byType(PageHeader)).dy;
    final firstCardTop = tester.getTopLeft(find.byType(AppCard).first).dy;
    expect(firstCardTop - headerBottom, 16);
  });

  testWidgets('Mall keeps only State and Status filters with mall counts',
      (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final datasetState = _StaticDatasetState()
      ..nodes = const [
        EquipmentNode(
          nodeName: 'Pump A',
          utilityType: 'Water',
          zoneId: 'Selangor',
          facilityName: 'Mall A',
          status: 'Active',
        ),
        EquipmentNode(
          nodeName: 'Pump B',
          utilityType: 'Water',
          zoneId: 'Selangor',
          facilityName: 'Mall B',
          status: 'Critical',
        ),
        EquipmentNode(
          nodeName: 'Pump C',
          utilityType: 'Water',
          zoneId: 'Johor',
          facilityName: 'Mall C',
          status: 'Maintenance',
        ),
      ];

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<DatasetState>.value(
          value: datasetState,
          child: const InventoryScreen(),
        ),
      ),
    );

    final dropdowns = tester.widgetList<FilterDropdown>(
      find.byType(FilterDropdown),
    );
    expect(dropdowns.map((dropdown) => dropdown.caption), ['State', 'Status']);
    expect(dropdowns.first.counts, {'Selangor': 2, 'Johor': 1});
    expect(dropdowns.last.counts, {
      'Active': 1,
      'Critical': 1,
      'Maintenance': 1,
    });
  });

  testWidgets('Worker Accounts searches with the shared filter field',
      (tester) async {
    tester.view.physicalSize = const Size(411, 914);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<RoleState>(
          create: (_) => RoleState(),
          child: WorkerAccountsScreen(repository: _EmptyWorkerRepository()),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(FilterSearchField), findsOneWidget);
    expect(find.text('Type anything to search'), findsOneWidget);
  });
}

class _EmptyWorkerRepository extends WorkerRepository {
  _EmptyWorkerRepository()
      : super(
          client: SupabaseClient(
            'https://example.supabase.co',
            'test-key',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          ),
        );

  @override
  Future<List<WorkerAccount>> listWorkers() async => const [];
}

class _ReadyAppState extends AppState {
  _ReadyAppState(LeakageRepository repository, {this.alerts = const []})
      : super(
          baseline: BaselineService(),
          nrw: NrwService(),
          repository: repository,
          simulation: SimulationService(
            baseline: BaselineService(),
            repository: repository,
          ),
        );

  @override
  bool get loading => false;

  @override
  final List<Alert> alerts;

  @override
  List<Alert> reviewQueue({String? sourceScope}) => alerts
      .where((alert) => sourceScope == null || alert.sourceScope == sourceScope)
      .toList();
}

Alert _filterAlert(
  int id, {
  required String utilityType,
  String alertType = AlertType.nrwHotspot,
}) =>
    Alert(
      id: id,
      alertType: alertType,
      sourceScope: AlertSourceScope.state,
      utilityType: utilityType,
      state: 'Selangor',
      detectedAt: DateTime(2026, 8, 28),
      signature: 'Test anomaly',
      severity: Severity.high,
      explanation: 'Test anomaly',
      status: AlertStatus.pendingReview,
      aiGeneratedAt: DateTime(2026, 8, 28),
    );

class _StaticDatasetState extends DatasetState {
  _StaticDatasetState() : super(repository: DatasetRepository());

  @override
  Future<void> loadNodes() async {}
}

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
