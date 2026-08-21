import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:mysumber/modules/dataset/data/dataset_repository.dart';
import 'package:mysumber/modules/dataset/models/models.dart';
import 'package:mysumber/modules/dataset/screens/dashboard_screen.dart';
import 'package:mysumber/modules/dataset/screens/inventory_screen.dart';
import 'package:mysumber/modules/dataset/services/inventory_filter.dart';
import 'package:mysumber/modules/dataset/state/dataset_state.dart';
import 'package:mysumber/theme/filter_controls.dart';
import 'package:mysumber/theme/tokens.dart';

void main() {
  test('seeds every configured mall with the three core equipment types',
      () async {
    final nodes = await DatasetRepository().fetchNodes();
    final facilities = nodes.map((node) => node.facilityName).toSet();
    final facilitiesByState = <String, int>{};
    for (final node in nodes) {
      facilitiesByState[node.zoneId!] =
          (facilitiesByState[node.zoneId!] ?? 0) + 1;
    }

    expect(facilities.length, 26);
    expect(nodes.length, 26 * 3);
    expect(facilitiesByState['W.P. Kuala Lumpur'], 5 * 3);
    expect(facilitiesByState['Selangor'], 3 * 3);
    expect(facilitiesByState['Johor'], 2 * 3);
    expect(facilitiesByState['Pulau Pinang'], 2 * 3);
    expect(facilitiesByState['Sabah'], 2 * 3);
    expect(facilitiesByState['Sarawak'], 2 * 3);
    expect(facilitiesByState.length, 16);

    for (final facility in facilities) {
      final facilityNodes =
          nodes.where((node) => node.facilityName == facility).toList();
      expect(
        facilityNodes.map((node) => node.nodeName).toSet(),
        containsAll(<String>[
          'Main Water Pump A1',
          'Cooling Tower Valve',
          'Sub-Transformer B2',
        ]),
      );
    }
  });

  test('equipment mapping preserves its mall and city', () {
    const node = EquipmentNode(
      nodeName: 'Main Water Pump A1',
      utilityType: 'Water',
      zoneId: 'Selangor',
      facilityName: '1 Utama Shopping Centre',
      facilityCity: 'Petaling Jaya',
      status: 'Active',
    );

    final restored = EquipmentNode.fromMap(node.toMap());

    expect(restored.facilityName, '1 Utama Shopping Centre');
    expect(restored.facilityCity, 'Petaling Jaya');
  });

  testWidgets('Mall Monitoring can open with a selected state filter',
      (tester) async {
    tester.view.physicalSize = const Size(800, 5000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final datasetState = DatasetState(repository: DatasetRepository());
    datasetState.stateWaterSupply['Selangor'] = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<DatasetState>.value(
          value: datasetState,
          child: const InventoryScreen(initialState: 'Selangor'),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Mall'), findsOneWidget);
    expect(find.widgetWithText(FilterDropdown, 'State / Federal Territory'),
        findsOneWidget);
    expect(find.text('Aman Central'), findsNothing);
  });

  testWidgets('usage comparison alone renders electricity in yellow',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final datasetState = _StaticDatasetState()
      ..stateWaterSupply['Selangor'] = 2000
      ..stateWaterConsumption['Selangor'] = 1000
      ..stateElectricitySupply['Selangor'] = 9000
      ..stateElectricityConsumption['Selangor'] = 2000;

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<DatasetState>.value(
          value: datasetState,
          child: const DashboardScreen(),
        ),
      ),
    );
    await tester.pump();

    final electricityLabel = tester.widget<Text>(find.text('Top Elec. Loss'));
    expect(electricityLabel.style?.color, AppColors.electricityAccent);

    final legendMarker = tester.widget<Container>(
      find.byKey(const ValueKey('usage-comparison-electricity-legend')),
    );
    expect(
      (legendMarker.decoration! as BoxDecoration).color,
      AppColors.electricityAccent,
    );

    final electricityBar = find.byKey(
      const ValueKey('usage-comparison-electricity-bar'),
    );
    final fills = find.descendant(
      of: electricityBar,
      matching: find.byType(Container),
    );
    final fill = tester.widget<Container>(fills.at(1));
    expect(
        (fill.decoration! as BoxDecoration).color, AppColors.electricityAccent);

    expect(AppColors.electricityAccent, const Color(0xFFEAB308));
    expect(AppColors.electricitySurface, const Color(0xFFFEF9C3));
  });

  testWidgets(
      'Mall Monitoring keeps its state filter labelled outside the border',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final datasetState = DatasetState(repository: DatasetRepository());
    datasetState.stateWaterSupply['Malaysia'] = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<DatasetState>.value(
          value: datasetState,
          child: const InventoryScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(FilterDropdown), findsOneWidget);
    expect(find.text('State / Federal Territory'), findsOneWidget);
    expect(find.widgetWithText(FilterDropdown, 'State / Federal Territory'),
        findsOneWidget);
  });

  testWidgets('dashboard keeps full details below its landscape summary',
      (tester) async {
    tester.view.physicalSize = const Size(914, 411);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final datasetState = _StaticDatasetState()
      ..nodes = const [
        EquipmentNode(
          nodeId: 'valve-1',
          nodeName: 'Cooling Tower Valve',
          utilityType: 'Water',
          zoneId: 'Selangor',
          status: 'Critical',
        ),
        EquipmentNode(
          nodeName: 'Main Water Pump A1',
          utilityType: 'Water',
          zoneId: 'Selangor',
          status: 'Active',
        ),
      ];

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<DatasetState>.value(
          value: datasetState,
          child: const DashboardScreen(),
        ),
      ),
    );

    expect(
      find.byKey(const PageStorageKey('phone-landscape-dashboard')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('priority-equipment')), findsOneWidget);
    expect(find.text('Usage Comparison'), findsOneWidget);
    expect(find.byTooltip('View full dashboard'), findsOneWidget);

    final panels = find.byType(AppCard);
    expect(tester.getRect(panels.at(0)).left, 16);
    expect(tester.getRect(panels.at(1)).left, greaterThan(16));
  });

  test('filters Selangor to its nine equipment nodes', () async {
    final nodes = await DatasetRepository().fetchNodes();
    final result = filterEquipmentNodes(nodes: nodes, state: 'Selangor');

    expect(result.nodes, hasLength(9));
  });

  test('filters a Selangor mall to its three core equipment nodes', () async {
    final nodes = await DatasetRepository().fetchNodes();
    final result = filterEquipmentNodes(
      nodes: nodes,
      state: 'Selangor',
      facility: '1 Utama Shopping Centre',
    );

    expect(result.nodes, hasLength(3));
  });

  test('lists only facilities belonging to the selected state', () async {
    final nodes = await DatasetRepository().fetchNodes();

    expect(
      facilitiesForState(nodes, 'Selangor'),
      <String>[
        '1 Utama Shopping Centre',
        'Setia City Mall',
        'Sunway Pyramid',
      ],
    );
  });

  test('combines state, mall, utility, and status filters', () async {
    final nodes = await DatasetRepository().fetchNodes();
    final result = filterEquipmentNodes(
      nodes: nodes,
      state: 'Selangor',
      facility: '1 Utama Shopping Centre',
      utility: 'Electricity',
      status: 'Maintenance',
    );

    expect(result.nodes, hasLength(1));
    expect(result.nodes.single.nodeName, 'Sub-Transformer B2');
  });

  test('computes utility and status counts from the location scope', () async {
    final nodes = await DatasetRepository().fetchNodes();
    final result = filterEquipmentNodes(nodes: nodes);

    expect(result.utilityCounts['Water'], 52);
    expect(result.utilityCounts['Electricity'], 26);
    expect(result.statusCounts['Active'], 65);
    expect(result.statusCounts['Critical'], 7);
    expect(result.statusCounts['Maintenance'], 6);
  });

  testWidgets('Mall Monitoring search narrows the mall cards', (tester) async {
    tester.view.physicalSize = const Size(800, 5000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final datasetState = DatasetState(repository: DatasetRepository());
    datasetState.stateWaterSupply['Malaysia'] = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<DatasetState>.value(
          value: datasetState,
          child: const InventoryScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Sunway Pyramid'), findsOneWidget);
    expect(find.text('Suria KLCC'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Sunway');
    await tester.pump();

    expect(find.text('Sunway Pyramid'), findsOneWidget);
    expect(find.text('Suria KLCC'), findsNothing);
  });

  testWidgets('inventory clear filters restores the default selections',
      (tester) async {
    tester.view.physicalSize = const Size(800, 5000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final datasetState = DatasetState(repository: DatasetRepository());
    datasetState.stateWaterSupply['Selangor'] = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<DatasetState>.value(
          value: datasetState,
          child: const InventoryScreen(initialState: 'Selangor'),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Clear filters'), findsOneWidget);
    await tester.tap(find.text('Clear filters'));
    await tester.pump();

    expect(find.text('All malls'), findsOneWidget);
  });

  testWidgets('Mall Monitoring keeps the mall list usable in phone landscape',
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
          status: 'Critical',
        ),
        EquipmentNode(
          nodeName: 'Cooling Tower Valve',
          utilityType: 'Water',
          zoneId: 'Selangor',
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

    expect(find.text('Mall'), findsOneWidget);
    expect(find.text('State / Federal Territory'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('Mall Monitoring opens a detail surface for its mall card',
      (tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final datasetState = _StaticDatasetState()
      ..nodes = const [
        EquipmentNode(
          nodeName: 'Main Water Pump A1',
          utilityType: 'Water',
          zoneId: 'W.P. Kuala Lumpur',
          facilityName: 'Suria KLCC',
          facilityCity: 'Kuala Lumpur',
          manufacturer: 'Grundfos',
          status: 'Active',
        ),
      ];

    await tester.pumpWidget(MaterialApp(
      home: ChangeNotifierProvider<DatasetState>.value(
        value: datasetState,
        child: const InventoryScreen(),
      ),
    ));
    await tester.pump();

    expect(find.text('Suria KLCC'), findsOneWidget);
    await tester.tap(find.text('Suria KLCC'));
    await tester.pumpAndSettle();
    expect(find.text('Equipment (1)'), findsOneWidget);
    expect(find.text('Manage equipment'), findsOneWidget);
  });
}

class _StaticDatasetState extends DatasetState {
  _StaticDatasetState() : super(repository: DatasetRepository());

  @override
  Future<void> loadNodes() async {}
}
