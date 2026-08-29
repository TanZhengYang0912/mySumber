import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mysumber/core/local_database/cache_status.dart';
import 'package:mysumber/core/local_database/local_database.dart';
import 'package:mysumber/modules/admin/screens/admin_alert_detail_screen.dart';
import 'package:mysumber/modules/auth/data/account_repository.dart';
import 'package:mysumber/modules/auth/state/auth_state.dart';
import 'package:mysumber/modules/leakage/data/leakage_repository.dart';
import 'package:mysumber/modules/leakage/models/alert.dart';
import 'package:mysumber/modules/leakage/models/report.dart';
import 'package:mysumber/modules/leakage/screens/alert_detail_content.dart';
import 'package:mysumber/modules/leakage/screens/alert_detail_screen.dart';
import 'package:mysumber/modules/leakage/services/baseline_service.dart';
import 'package:mysumber/modules/leakage/services/nrw_service.dart';
import 'package:mysumber/modules/leakage/services/simulation_service.dart';
import 'package:mysumber/modules/leakage/state/app_state.dart';
import 'package:mysumber/modules/leakage/widgets/adaptive_flow.dart';
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

  testWidgets('shared alert content renders evidence, context, AI, and reports',
      (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final alert = _reviewAlert(
      status: AlertStatus.pending,
      producedMld: 1597,
      billedMld: 777,
      lossMld: 820,
      lossPct: 51.3,
      dataYear: 2022,
    );
    final app = _DetailAppState(repository, alert);
    final report = Report(
      id: 7,
      alertId: 1,
      workerName: 'Aisyah',
      findings: 'Leak found at the main junction.',
      actionTaken: 'Replaced the damaged coupling.',
      outcome: ReportOutcome.fixed,
      createdAt: DateTime(2026, 8, 29, 10),
      updatedAt: DateTime(2026, 8, 29, 11),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: app,
        child: MaterialApp(
          home: Scaffold(
            body: AlertDetailContent(
              app: app,
              alert: alert,
              reports: [report],
              primary: const Color(0xFF5E2A84),
              canGenerateAi: false,
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('shared-alert-detail-content')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('alert-detail-summary-card')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('alert-detail-evidence-card')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('alert-detail-context-card')),
        findsOneWidget);
    expect(find.text('Water balance (2022)'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('AI ANALYSIS'), 300);
    expect(find.text('AI ANALYSIS'), findsOneWidget);
    expect(find.text('Review this anomaly.'), findsOneWidget);
    expect(find.text('Regenerate AI Analysis'), findsNothing);

    await tester.scrollUntilVisible(find.text('INVESTIGATION REPORTS'), 300);
    expect(find.text('INVESTIGATION REPORTS'), findsOneWidget);
    expect(find.text('Report · Fixed'), findsOneWidget);

    await tester.tap(find.text('Report · Fixed'));
    await tester.pumpAndSettle();
    final reportAppBar = tester.widget<AppBar>(
      find.ancestor(
        of: find.text('Investigation Report'),
        matching: find.byType(AppBar),
      ),
    );
    expect(reportAppBar.backgroundColor, const Color(0xFF5E2A84));
  });

  testWidgets(
      'review decision stays fixed with clear fault and approve actions',
      (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final alert = _reviewAlert();
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: _DetailAppState(repository, alert),
        child: const MaterialApp(
          home: AdminAlertDetailScreen(alertId: 1),
        ),
      ),
    );

    final panel = find.byKey(const ValueKey('alert-decision-panel'));
    expect(panel, findsOneWidget);
    expect(find.text('Review decision'), findsOneWidget);
    expect(
      find.text('Approve sends this anomaly to the Worker queue.'),
      findsOneWidget,
    );
    expect(
        find.widgetWithText(OutlinedButton, 'Mark as fault'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Approve'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_outlined), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);

    final faultButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Mark as fault'),
    );
    expect(
      faultButton.style?.side?.resolve(<WidgetState>{})?.color,
      AppColors.critical,
    );
    final approveButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Approve'),
    );
    expect(
      approveButton.style?.backgroundColor?.resolve(<WidgetState>{}),
      AppColors.adminPrimary,
    );

    final beforeScroll = tester.getRect(panel);
    await tester.drag(find.byType(ListView), const Offset(0, -350));
    await tester.pump();
    expect(tester.getRect(panel), beforeScroll);
  });

  testWidgets('landscape uses the standard AppBar and shared responsive body',
      (tester) async {
    tester.view.physicalSize = const Size(914, 411);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final alert = _reviewAlert(status: AlertStatus.pending);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: _DetailAppState(repository, alert),
        child: const MaterialApp(
          home: AdminAlertDetailScreen(alertId: 1),
        ),
      ),
    );

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.backgroundColor, AppColors.adminPrimary);
    expect(appBar.foregroundColor, Colors.white);
    expect(find.byKey(const Key('admin-alert-landscape-layout')), findsNothing);
    expect(
      find.byKey(const ValueKey('shared-alert-detail-content')),
      findsOneWidget,
    );
    expect(
      tester
          .getRect(find.byKey(const ValueKey('alert-detail-summary-card')))
          .width,
      greaterThan(850),
    );
  });

  testWidgets('landscape reuses the NRW evidence and AI detail content',
      (tester) async {
    tester.view.physicalSize = const Size(914, 411);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final alert = _reviewAlert(
      status: AlertStatus.pending,
      producedMld: 1597,
      billedMld: 777,
      lossMld: 820,
      lossPct: 51.3,
      dataYear: 2022,
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: _DetailAppState(repository, alert),
        child: const MaterialApp(
          home: AdminAlertDetailScreen(alertId: 1),
        ),
      ),
    );

    expect(find.text('Water balance (2022)'), findsOneWidget);
    expect(find.text('1597 MLD'), findsOneWidget);
    expect(find.text('777 MLD'), findsOneWidget);
    expect(find.text('820'), findsOneWidget);
    expect(find.text('Expected'), findsNothing);
    expect(find.text('Actual'), findsNothing);
    expect(find.text('Ratio'), findsNothing);

    await tester.drag(find.byType(ListView), const Offset(0, -650));
    await tester.pump();
    expect(find.text('AI ANALYSIS'), findsOneWidget);
    expect(find.text('Review this anomaly.'), findsOneWidget);
  });

  testWidgets('worker uses shared content and keeps its action fixed at bottom',
      (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final alert = _reviewAlert(status: AlertStatus.pending);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: _DetailAppState(repository, alert),
        child: const MaterialApp(home: AlertDetailScreen(alertId: 1)),
      ),
    );

    final panel = find.byKey(const ValueKey('worker-alert-action-panel'));
    expect(find.byKey(const ValueKey('shared-alert-detail-content')),
        findsOneWidget);
    expect(panel, findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Start Investigation'),
        findsOneWidget);

    final beforeScroll = tester.getRect(panel);
    await tester.drag(
      find.byKey(const ValueKey('shared-alert-detail-content')),
      const Offset(0, -650),
    );
    await tester.pump();
    expect(tester.getRect(panel), beforeScroll);

    await tester.scrollUntilVisible(find.text('AI ANALYSIS'), 300);
    expect(find.text('AI ANALYSIS'), findsOneWidget);
    expect(find.text('Regenerate AI Analysis'), findsNothing);
    expect(find.text('Generate AI Analysis'), findsNothing);
    expect(find.text('Retry AI Analysis'), findsNothing);
  });

  testWidgets('worker keeps the re-investigation action in the fixed panel',
      (tester) async {
    final alert = _reviewAlert(status: AlertStatus.notFixed);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: _DetailAppState(repository, alert),
        child: const MaterialApp(home: AlertDetailScreen(alertId: 1)),
      ),
    );

    expect(
      find.byKey(const ValueKey('worker-alert-action-panel')),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Re-Investigate'), findsOneWidget);
    expect(find.text('Review decision'), findsNothing);
  });

  testWidgets('worker landscape keeps the same AppBar and content template',
      (tester) async {
    tester.view.physicalSize = const Size(914, 411);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final alert = _reviewAlert(status: AlertStatus.pending);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: _DetailAppState(repository, alert),
        child: const MaterialApp(home: AlertDetailScreen(alertId: 1)),
      ),
    );

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.backgroundColor, AppColors.workerPrimary);
    expect(find.byType(AdaptiveFlow), findsNothing);
    expect(find.byKey(const ValueKey('shared-alert-detail-content')),
        findsOneWidget);
    expect(
      tester
          .getRect(find.byKey(const ValueKey('alert-detail-summary-card')))
          .width,
      greaterThan(850),
    );
  });

  testWidgets('worker writes its identity when starting an investigation',
      (tester) async {
    final app = _RecordingDetailAppState(
      repository,
      _reviewAlert(status: AlertStatus.pending),
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppState>.value(value: app),
          ChangeNotifierProvider<RoleState>(
            create: (_) => _TestRoleState(
              testUserId: 'worker-123',
              testDisplayName: 'Aisyah',
              accountRepository: _testAccountRepository(database),
            ),
          ),
        ],
        child: const MaterialApp(home: AlertDetailScreen(alertId: 1)),
      ),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Start Investigation'));
    await tester.pump();

    expect(app.updatedAlertId, 1);
    expect(app.updatedStatus, AlertStatus.investigating);
    expect(app.updatedHandledBy, 'Aisyah');
    expect(app.updatedHandledById, 'worker-123');
  });

  testWidgets('worker writes its identity when reopening a not-fixed alert',
      (tester) async {
    final app = _RecordingDetailAppState(
      repository,
      _reviewAlert(status: AlertStatus.notFixed),
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppState>.value(value: app),
          ChangeNotifierProvider<RoleState>(
            create: (_) => _TestRoleState(
              testUserId: 'worker-456',
              testDisplayName: 'Mei',
              accountRepository: _testAccountRepository(database),
            ),
          ),
        ],
        child: const MaterialApp(home: AlertDetailScreen(alertId: 1)),
      ),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Re-Investigate'));
    await tester.pump();

    expect(app.updatedAlertId, 1);
    expect(app.updatedStatus, AlertStatus.investigating);
    expect(app.updatedHandledBy, 'Mei');
    expect(app.updatedHandledById, 'worker-456');
  });

  testWidgets('only the investigating worker can write the report',
      (tester) async {
    final alert = _reviewAlert(
      status: AlertStatus.investigating,
      handledBy: 'Aisyah',
      handledById: 'owner-123',
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppState>.value(
            value: _DetailAppState(repository, alert),
          ),
          ChangeNotifierProvider<RoleState>(
            create: (_) => _TestRoleState(
              testUserId: 'owner-123',
              testDisplayName: 'Aisyah',
              accountRepository: _testAccountRepository(database),
            ),
          ),
        ],
        child: const MaterialApp(home: AlertDetailScreen(alertId: 1)),
      ),
    );

    expect(find.widgetWithText(FilledButton, 'Write Report'), findsOneWidget);
    expect(find.textContaining('only they can submit a report.'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppState>.value(
            value: _DetailAppState(repository, alert),
          ),
          ChangeNotifierProvider<RoleState>(
            create: (_) => _TestRoleState(
              testUserId: 'different-worker',
              testDisplayName: 'Mei',
              accountRepository: _testAccountRepository(database),
            ),
          ),
        ],
        child: const MaterialApp(home: AlertDetailScreen(alertId: 1)),
      ),
    );

    expect(find.widgetWithText(FilledButton, 'Write Report'), findsNothing);
    expect(
      find.text(
        'Being investigated by Aisyah — only they can submit a report.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('admin opens reports in its AppBar color and can regenerate AI',
      (tester) async {
    final report = _report();
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: _DetailAppState(
          repository,
          _reviewAlert(status: AlertStatus.pending),
          reports: [report],
        ),
        child: const MaterialApp(home: AdminAlertDetailScreen(alertId: 1)),
      ),
    );

    await tester.scrollUntilVisible(find.text('Regenerate AI Analysis'), 300);
    expect(find.text('Regenerate AI Analysis'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Report · Fixed'), 300);
    await tester.tap(find.text('Report · Fixed'));
    await tester.pumpAndSettle();

    final reportAppBar = tester.widget<AppBar>(
      find.ancestor(
        of: find.text('Investigation Report'),
        matching: find.byType(AppBar),
      ),
    );
    expect(reportAppBar.backgroundColor, AppColors.adminPrimary);
  });

  testWidgets('worker opens reports in its AppBar color', (tester) async {
    final report = _report();
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: _DetailAppState(
          repository,
          _reviewAlert(status: AlertStatus.pending),
          reports: [report],
        ),
        child: const MaterialApp(home: AlertDetailScreen(alertId: 1)),
      ),
    );

    await tester.scrollUntilVisible(find.text('Report · Fixed'), 300);
    await tester.tap(find.text('Report · Fixed'));
    await tester.pumpAndSettle();

    final reportAppBar = tester.widget<AppBar>(
      find.ancestor(
        of: find.text('Investigation Report'),
        matching: find.byType(AppBar),
      ),
    );
    expect(reportAppBar.backgroundColor, AppColors.workerPrimary);
  });
}

Alert _reviewAlert({
  String status = AlertStatus.pendingReview,
  double? producedMld,
  double? billedMld,
  double? lossMld,
  double? lossPct,
  int? dataYear,
  String? handledBy,
  String? handledById,
}) =>
    Alert(
      id: 1,
      alertType: AlertType.nrwHotspot,
      state: 'Selangor',
      detectedAt: DateTime(2026, 8, 28),
      signature: LeakSignature.nrwHotspot,
      severity: Severity.high,
      explanation: 'Water loss is above the expected baseline.',
      status: status,
      producedMld: producedMld,
      billedMld: billedMld,
      lossMld: lossMld,
      lossPct: lossPct,
      dataYear: dataYear,
      handledBy: handledBy,
      handledById: handledById,
      aiSummary: 'Review this anomaly.',
      aiRecommendation: 'Send a worker to inspect it.',
      aiGeneratedAt: DateTime(2026, 8, 28),
    );

Report _report() => Report(
      id: 7,
      alertId: 1,
      workerName: 'Aisyah',
      findings: 'Leak found at the main junction.',
      actionTaken: 'Replaced the damaged coupling.',
      outcome: ReportOutcome.fixed,
      createdAt: DateTime(2026, 8, 29, 10),
      updatedAt: DateTime(2026, 8, 29, 11),
    );

class _DetailAppState extends AppState {
  _DetailAppState(
    LeakageRepository repository,
    this.alert, {
    List<Report> reports = const [],
  })  : _reports = reports,
        super(
          baseline: BaselineService(),
          nrw: NrwService(),
          repository: repository,
          simulation: SimulationService(
            baseline: BaselineService(),
            repository: repository,
          ),
        );

  final Alert alert;
  final List<Report> _reports;

  @override
  bool get loading => false;

  @override
  List<Alert> get alerts => [alert];

  @override
  List<Report> get reports => _reports;
}

class _RecordingDetailAppState extends _DetailAppState {
  _RecordingDetailAppState(super.repository, super.alert) : super();

  int? updatedAlertId;
  String? updatedStatus;
  String? updatedHandledBy;
  String? updatedHandledById;

  @override
  Future<void> updateAlertStatus(
    int alertId,
    String status, {
    String? handledBy,
    String? handledById,
  }) async {
    updatedAlertId = alertId;
    updatedStatus = status;
    updatedHandledBy = handledBy;
    updatedHandledById = handledById;
  }
}

AccountRepository _testAccountRepository(LocalDatabase database) =>
    AccountRepository.withRemote(
      remote: _UnusedAccountRemote(),
      database: database,
      cacheStatus: CacheStatus(),
    );

class _UnusedAccountRemote implements AccountRemoteStore {
  @override
  Future<Map<String, Object?>?> currentProfile(String userId) async => null;
}

class _TestRoleState extends RoleState {
  _TestRoleState({
    required this.testUserId,
    required this.testDisplayName,
    required AccountRepository accountRepository,
  }) : super(
          accountRepository: accountRepository,
          currentSession: () => null,
          authStateChanges: const Stream<AuthState>.empty(),
        );

  final String testUserId;
  final String testDisplayName;

  @override
  String? get userId => testUserId;

  @override
  String get displayName => testDisplayName;
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
