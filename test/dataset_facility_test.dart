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

  testWidgets('inventory can open with a selected state filter',
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

    expect(find.text('State / Federal Territory'), findsOneWidget);
    expect(find.widgetWithText(FilterDropdown, 'Shopping Mall'), findsOneWidget);
    expect(find.text('Aman Central'), findsNothing);

    await tester.tap(find.text('Selangor').last);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Johor').last);
    await tester.pump();

    expect(find.widgetWithText(FilterDropdown, 'Shopping Mall'), findsOneWidget);
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
    expect(electricityLabel.style?.color, AppColors.warning);

    final legendMarker = tester.widget<Container>(
      find.byKey(const ValueKey('usage-comparison-electricity-legend')),
    );
    expect(
      (legendMarker.decoration! as BoxDecoration).color,
      AppColors.warning,
    );

    final electricityBar = find.byKey(
      const ValueKey('usage-comparison-electricity-bar'),
    );
    final fills = find.descendant(
      of: electricityBar,
      matching: find.byType(Container),
    );
    final fill = tester.widget<Container>(fills.at(1));
    expect((fill.decoration! as BoxDecoration).color, AppColors.warning);

    expect(AppColors.electricityAccent, const Color(0xFF3B82F6));
    expect(AppColors.electricitySurface, const Color(0xFFE0EBFB));
  });

  testWidgets(
      'inventory keeps portrait location labels outside dropdown borders',
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

    expect(find.byType(FilterDropdown), findsNWidgets(3));
    expect(find.text('State / Federal Territory'), findsOneWidget);
    expect(find.text('Shopping Mall'), findsOneWidget);
    expect(
        find.widgetWithText(FilterDropdown, 'State / Federal Territory'),
        findsOneWidget);
    expect(
        find.widgetWithText(FilterDropdown, 'Shopping Mall'), findsOneWidget);
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

  testWidgets('inventory status filter shows counts and updates on selection',
      (tester) async {
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

    final statusDropdown = find.widgetWithText(FilterDropdown, 'Status');
    expect(statusDropdown, findsOneWidget);

    await tester.tap(statusDropdown);
    await tester.pumpAndSettle();
    expect(find.text('Active (65)'), findsWidgets);
    expect(find.text('Critical (7)'), findsWidgets);

    await tester.tap(find.text('Critical (7)').last);
    await tester.pump();

    // DropdownButton keeps an off-screen copy of every item for sizing, so
    // even the closed state shows the selected label at least once, not
    // exactly once.
    expect(find.text('Critical (7)'), findsWidgets);
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

    // "All (78)" now comes from the Utility "All" chip and the Status
    // dropdown's closed value (the only two that carry counts) — State and
    // Shopping Mall show a bare "All" since they aren't given a counts map.
    expect(find.text('All (78)'), findsNWidgets(2));
    expect(find.text('All'), findsNWidgets(2));
  });

  testWidgets('inventory uses a compact filter workspace in phone landscape',
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

    expect(
      find.byKey(const PageStorageKey('phone-landscape-inventory')),
      findsOneWidget,
    );
    expect(find.byTooltip('Filter equipment'), findsOneWidget);
    expect(find.byTooltip('Add equipment'), findsOneWidget);
    expect(find.text('State / Federal Territory'), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);

    await tester.tap(find.byTooltip('Filter equipment'));
    await tester.pumpAndSettle();
    expect(find.text('State / Federal Territory'), findsOneWidget);
  });

  testWidgets(
      'inventory aligns equipment details into status and operation zones',
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

    // "Status" also labels the filter dropdown added this round, so scope
    // this card's own label to inside its Dismissible wrapper.
    final cardStatusLabel = find.descendant(
      of: find.byType(Dismissible),
      matching: find.text('Status'),
    );
    expect(cardStatusLabel, findsOneWidget);
    expect(find.text('Operation'), findsOneWidget);
    expect(find.byTooltip('Edit equipment'), findsOneWidget);

    final statusColumn = tester.widget<Column>(
      find
          .ancestor(
            of: cardStatusLabel,
            matching: find.byType(Column),
          )
          .first,
    );
    expect(statusColumn.crossAxisAlignment, CrossAxisAlignment.center);

    final statusLabelY = tester.getCenter(cardStatusLabel).dy;
    final operationLabelY = tester.getCenter(find.text('Operation')).dy;
    final statusValueY = tester.getCenter(find.text('Active')).dy;
    final operationY = tester.getCenter(find.byTooltip('Edit equipment')).dy;
    expect(statusLabelY, closeTo(operationLabelY, 1));
    expect(statusValueY, closeTo(operationY, 1));
  });
}

class _StaticDatasetState extends DatasetState {
  _StaticDatasetState() : super(repository: DatasetRepository());

  @override
  Future<void> loadNodes() async {}
}
