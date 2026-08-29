import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mysumber/core/local_database/cache_status.dart';
import 'package:mysumber/core/local_database/local_database.dart';
import 'package:mysumber/modules/dataset/data/dataset_repository.dart';
import 'package:mysumber/modules/dataset/models/models.dart';
import 'package:mysumber/modules/dataset/screens/dashboard_screen.dart';
import 'package:mysumber/modules/dataset/state/dataset_state.dart';
import 'package:mysumber/modules/leakage/data/leakage_repository.dart';
import 'package:mysumber/modules/leakage/models/alert.dart';
import 'package:mysumber/modules/leakage/services/baseline_service.dart';
import 'package:mysumber/modules/leakage/services/nrw_service.dart';
import 'package:mysumber/modules/leakage/services/simulation_service.dart';
import 'package:mysumber/modules/leakage/state/app_state.dart';
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

  testWidgets('overview labels Maintenance malls as Maintenance, not Warning',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final dataset = _StaticDatasetState()..nodes = _maintenanceMall;
    await tester.pumpWidget(
      _dashboard(dataset: dataset, app: _StubAppState(repository)),
    );

    expect(find.text('1 maintenance'), findsOneWidget);
    expect(find.textContaining('warning'), findsNothing);
  });

  testWidgets('overview summarises anomaly lifecycle', (tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final dataset = _StaticDatasetState()..nodes = _maintenanceMall;
    await tester.pumpWidget(
      _dashboard(
        dataset: dataset,
        app: _StubAppState(
          repository,
          alerts: [
            _alert(AlertStatus.pendingReview),
            _alert(AlertStatus.investigating),
            _alert(AlertStatus.resolved),
            _alert(AlertStatus.faults),
          ],
        ),
      ),
    );

    expect(find.text('1 to review'), findsOneWidget);
    expect(find.text('1 ongoing'), findsOneWidget);
    expect(find.text('1 resolved'), findsOneWidget);
    expect(find.text('1 rejected'), findsOneWidget);
  });

  testWidgets('landscape keeps the shared overview card', (tester) async {
    tester.view.physicalSize = const Size(914, 411);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final dataset = _StaticDatasetState()..nodes = _maintenanceMall;
    await tester.pumpWidget(
      _dashboard(dataset: dataset, app: _StubAppState(repository)),
    );

    expect(find.byKey(const ValueKey('overview-malls')), findsOneWidget);
    expect(find.byKey(const ValueKey('overview-anomalies')), findsOneWidget);
    expect(find.text('System health'), findsNothing);
  });

  testWidgets('overview rows open Mall and Anomalies tabs', (tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final openedTabs = <int>[];

    final dataset = _StaticDatasetState()..nodes = _maintenanceMall;
    await tester.pumpWidget(
      _dashboard(
        dataset: dataset,
        app: _StubAppState(repository),
        onOpenTab: openedTabs.add,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('overview-malls')));
    await tester.tap(find.byKey(const ValueKey('overview-anomalies')));

    expect(openedTabs, [1, 2]);
  });

  testWidgets('overview uses approved icons and token-coloured outlines',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final dataset = _StaticDatasetState()..nodes = _overviewMalls;
    await tester.pumpWidget(
      _dashboard(
        dataset: dataset,
        app: _StubAppState(
          repository,
          alerts: [
            _alert(AlertStatus.investigating),
            _alert(AlertStatus.resolved),
            _alert(AlertStatus.faults),
          ],
        ),
      ),
    );

    expect(find.text('Mall health'), findsOneWidget);
    expect(find.text('Anomaly queue'), findsOneWidget);
    expect(find.byKey(const ValueKey('overview-malls-icon')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('overview-anomalies-icon')), findsOneWidget);

    void expectStatus(String key, Color color, IconData icon) {
      final finder = find.byKey(ValueKey('overview-pill-$key'));
      final box = tester.widget<Container>(finder);
      final decoration = box.decoration! as BoxDecoration;
      expect(decoration.color, Colors.transparent);
      expect((decoration.border! as Border).top.color, color);
      final renderedIcon = tester.widget<Icon>(find.descendant(
        of: finder,
        matching: find.byType(Icon),
      ));
      expect(renderedIcon.icon, icon);
      expect(renderedIcon.color, color);
    }

    expectStatus('critical', AppColors.critical, Icons.error_outline);
    expectStatus('warning', AppColors.warning, Icons.warning_amber_outlined);
    expectStatus('maintenance', AppColors.textSecondary, Icons.build_outlined);
    expectStatus('active', AppColors.success, Icons.check_circle_outline);
    expectStatus('ongoing', AppColors.waterAccent, Icons.schedule_outlined);
    expectStatus('resolved', AppColors.success, Icons.check_circle_outline);
    expectStatus('rejected', AppColors.textSecondary, Icons.block_outlined);

    final queueTitle = tester.widget<Text>(find.text('Anomaly queue'));
    expect(queueTitle.style?.color, AppColors.textPrimary);
    final reviewMetric = tester.widget<Text>(find.text('0 to review'));
    expect(reviewMetric.style?.color, AppColors.textPrimary);
  });
}

Widget _dashboard({
  required DatasetState dataset,
  required AppState app,
  ValueChanged<int>? onOpenTab,
}) {
  return MaterialApp(
    home: MultiProvider(
      providers: [
        ChangeNotifierProvider<DatasetState>.value(value: dataset),
        ChangeNotifierProvider<AppState>.value(value: app),
      ],
      child: DashboardScreen(onOpenTab: onOpenTab),
    ),
  );
}

const _maintenanceMall = [
  EquipmentNode(
    nodeId: 'trf-1',
    nodeName: 'Transformer T1',
    utilityType: 'Electricity',
    zoneId: 'Selangor',
    facilityName: 'Sunway Pyramid',
    status: 'Maintenance',
  ),
];

const _overviewMalls = [
  EquipmentNode(
    nodeId: 'critical',
    nodeName: 'Critical pump',
    utilityType: 'Water',
    zoneId: 'Selangor',
    facilityName: 'Critical Mall',
    status: 'Critical',
  ),
  EquipmentNode(
    nodeId: 'warning',
    nodeName: 'Warning pump',
    utilityType: 'Water',
    zoneId: 'Selangor',
    facilityName: 'Warning Mall',
    status: 'Warning',
  ),
  EquipmentNode(
    nodeId: 'maintenance',
    nodeName: 'Maintenance pump',
    utilityType: 'Water',
    zoneId: 'Selangor',
    facilityName: 'Maintenance Mall',
    status: 'Maintenance',
  ),
  EquipmentNode(
    nodeId: 'active',
    nodeName: 'Active pump',
    utilityType: 'Water',
    zoneId: 'Selangor',
    facilityName: 'Active Mall',
    status: 'Active',
  ),
];

Alert _alert(String status) => Alert(
      id: status.hashCode,
      state: 'Selangor',
      alertType: AlertType.nrwHotspot,
      detectedAt: DateTime(2026, 8, 28),
      signature: 'Test alert',
      severity: Severity.high,
      status: status,
      explanation: 'Test alert',
    );

class _StaticDatasetState extends DatasetState {
  _StaticDatasetState() : super(repository: DatasetRepository());

  @override
  Future<void> loadNodes() async {}
}

class _StubAppState extends AppState {
  _StubAppState(LeakageRepository repository, {List<Alert> alerts = const []})
      : _alerts = alerts,
        super(
          baseline: BaselineService(),
          nrw: NrwService(),
          repository: repository,
          simulation: SimulationService(
            baseline: BaselineService(),
            repository: repository,
          ),
        );

  final List<Alert> _alerts;

  @override
  bool get loading => false;

  @override
  List<Alert> get alerts => _alerts;
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
