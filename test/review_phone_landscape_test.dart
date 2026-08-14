import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mysumber/modules/admin/screens/anomaly_review_detail_screen.dart';
import 'package:mysumber/modules/admin/screens/review_management_screen.dart';
import 'package:mysumber/modules/admin/widgets/admin_page_header.dart';
import 'package:mysumber/modules/leakage/data/leakage_repository.dart';
import 'package:mysumber/modules/leakage/models/alert.dart';
import 'package:mysumber/modules/leakage/services/baseline_service.dart';
import 'package:mysumber/modules/leakage/services/nrw_service.dart';
import 'package:mysumber/modules/leakage/services/simulation_service.dart';
import 'package:mysumber/modules/leakage/state/app_state.dart';

void main() {
  testWidgets(
      'phone portrait review keeps location labels outside dropdown borders',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final appState = _ReviewFixtureState([
      _alert(id: 1, facility: 'Aman Central'),
    ]);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: const MaterialApp(
          home: ReviewManagementScreen(),
        ),
      ),
    );

    final dropdowns = tester.widgetList<DropdownButtonFormField<String>>(
      find.byType(DropdownButtonFormField<String>),
    );
    expect(dropdowns, hasLength(3));
    expect(
      dropdowns.every((dropdown) => dropdown.decoration.labelText == null),
      isTrue,
    );
    expect(find.text('State / Federal Territory'), findsOneWidget);
    expect(find.text('Shopping Mall'), findsOneWidget);
    expect(find.text('Equipment'), findsOneWidget);
  });

  testWidgets('phone landscape review uses a grid and opens full detail',
      (tester) async {
    tester.view.physicalSize = const Size(914, 411);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final appState = _ReviewFixtureState([
      _alert(id: 1, facility: 'Aman Central'),
      _alert(id: 2, facility: 'Gurney Plaza'),
    ]);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: const MaterialApp(
          home: ReviewManagementScreen(),
        ),
      ),
    );

    expect(find.byKey(const PageStorageKey('phone-landscape-review-grid')),
        findsOneWidget);
    final header = tester.getRect(find.byType(AdminPageHeader));
    expect(header.left, 0);
    expect(header.width, 914);
    expect(find.byTooltip('Filter anomalies'), findsOneWidget);
    expect(find.byType(AnomalyReviewDetailContent), findsNothing);

    await tester.tap(find.text('Aman Central'));
    await tester.pumpAndSettle();

    expect(find.byType(AnomalyReviewDetailScreen), findsOneWidget);
  });
}

Alert _alert({required int id, required String facility}) => Alert(
      id: id,
      alertType: AlertType.nrwHotspot,
      state: 'Selangor',
      detectedAt: DateTime.utc(2026, 7, 29),
      signature: 'nrw_hotspot_$id',
      severity: Severity.high,
      explanation: 'Water usage exceeded its baseline.',
      status: AlertStatus.pending,
      facilityName: facility,
      facilityCity: 'Petaling Jaya',
      equipmentName: 'Main Water Pump A1',
    );

class _ReviewFixtureState extends AppState {
  _ReviewFixtureState(this._fixtureAlerts)
      : super(
          baseline: BaselineService(),
          nrw: NrwService(),
          repository: _testRepository(),
          simulation: SimulationService(
            baseline: BaselineService(),
            repository: _testRepository(),
          ),
        );

  final List<Alert> _fixtureAlerts;

  @override
  List<Alert> get alerts => _fixtureAlerts;

  @override
  bool get loading => false;
}

LeakageRepository _testRepository() => LeakageRepository(
      SupabaseClient(
        'http://localhost',
        'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      ),
    );
