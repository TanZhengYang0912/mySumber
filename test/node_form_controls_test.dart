import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mysumber/modules/dataset/data/dataset_repository.dart';
import 'package:mysumber/modules/dataset/models/models.dart';
import 'package:mysumber/modules/dataset/screens/node_form_screen.dart';
import 'package:mysumber/modules/dataset/services/equipment_import.dart';
import 'package:mysumber/modules/dataset/state/dataset_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('new deployment uses controlled identity and hardware choices',
      (tester) async {
    tester.view.physicalSize = const Size(800, 5000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final state = DatasetState(repository: DatasetRepository());
    state.nodes = await state.repository.fetchNodes();
    state.importCatalog = catalogFromNodes(state.nodes);

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<DatasetState>.value(
          value: state,
          child: const NodeFormScreen(),
        ),
      ),
    );

    expect(find.text('Device ID (Asset Tag)'), findsOneWidget);
    expect(find.text('Asset Tag'), findsNothing);
    expect(find.text('Example: DEMO-01-MWP-001'), findsOneWidget);
    expect(find.text('Facility'), findsOneWidget);
    expect(find.text('Equipment Type'), findsOneWidget);
    expect(find.text('Filtered by utility type'), findsOneWidget);
    expect(find.text('IP Assignment'), findsOneWidget);
    expect(find.text('Firmware Version'), findsOneWidget);
    expect(find.text('Model'), findsOneWidget);
    expect(find.text('Model not registered yet'), findsOneWidget);
    expect(find.text('Model list comes from the equipment catalog'),
        findsOneWidget);
    expect(find.text('Shopping Mall / Facility'), findsNothing);
    expect(find.text('Manufacturer'), findsOneWidget);
    expect(find.byType(DropdownButton<String>), findsNWidgets(7));
  });

  testWidgets('shows confirmation after a deployment is saved', (tester) async {
    tester.view.physicalSize = const Size(800, 5000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final state = DatasetState(repository: DatasetRepository());
    state.nodes = await state.repository.fetchNodes();
    state.importCatalog = catalogFromNodes(state.nodes);
    state.stateWaterSupply['test'] = 1;
    final existing = state.nodes.first;

    await tester.pumpWidget(
      ChangeNotifierProvider<DatasetState>.value(
        value: state,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () async {
                    final saved = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => NodeFormScreen(node: existing),
                      ),
                    );
                    if (context.mounted && saved == true) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Deployment saved successfully'),
                        ),
                      );
                    }
                  },
                  child: const Text('Open deployment'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open deployment'));
    await tester.pumpAndSettle();
    final saveButton = find.text('Save Changes');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(find.text('Edit Configuration'), findsNothing);
    expect(find.text('Deployment saved successfully'), findsOneWidget);
  });

  testWidgets('changing utility type resets dependent hardware choices',
      (tester) async {
    tester.view.physicalSize = const Size(800, 5000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final state = DatasetState(repository: DatasetRepository());
    state.nodes = await state.repository.fetchNodes();
    state.importCatalog = catalogFromNodes(state.nodes);

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<DatasetState>.value(
          value: state,
          child: const NodeFormScreen(),
        ),
      ),
    );

    final dropdowns = find.byType(DropdownButton<String>);
    await tester.tap(dropdowns.at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Electricity').last);
    await tester.pumpAndSettle();

    expect(find.text('Sub-Transformer'), findsOneWidget);
    expect(find.text('Siemens'), findsOneWidget);
    expect(find.text('Grundfos'), findsNothing);
    expect(find.text('Cooling Tower Valve'), findsNothing);

    await tester.tap(find.byType(DropdownButton<String>).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Water').last);
    await tester.pumpAndSettle();

    expect(find.text('Main Water Pump'), findsOneWidget);
    expect(find.text('Grundfos'), findsOneWidget);
    expect(find.text('Siemens'), findsNothing);
  });

  testWidgets('replaces legacy facility prefixes with a unique generated ID',
      (tester) async {
    tester.view.physicalSize = const Size(800, 5000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final state = DatasetState(repository: DatasetRepository());
    state.nodes = [
      const EquipmentNode(
        nodeName: 'Legacy transformer',
        assetTag: 'LEGACY-09fd8a4eb3-S-001',
        equipmentType: 'Sub-Transformer',
        utilityType: 'Electricity',
        status: 'Active',
      ),
      const EquipmentNode(
        nodeName: 'Transformer 1',
        assetTag: 'TRX-TR-001',
        equipmentType: 'Sub-Transformer',
        utilityType: 'Electricity',
        status: 'Active',
      ),
    ];
    state.importCatalog = const EquipmentImportCatalog(
      facilities: [
        ImportFacility(
          code: 'LEGACY-09fd8a4eb3',
          name: 'The Exchange TRX',
          city: 'Kuala Lumpur',
          state: 'W.P. Kuala Lumpur',
        ),
      ],
      models: [
        ImportModel(
          equipmentType: 'Main Water Pump',
          utilityType: 'Water',
          manufacturer: 'Grundfos',
          model: 'Unspecified',
          firmwareVersions: ['Unknown'],
        ),
        ImportModel(
          equipmentType: 'Sub-Transformer',
          utilityType: 'Electricity',
          manufacturer: 'Siemens',
          model: 'Unspecified',
          firmwareVersions: ['Unknown'],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<DatasetState>.value(
          value: state,
          child: const NodeFormScreen(),
        ),
      ),
    );

    await tester.tap(find.text('Select a registered facility'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('The Exchange TRX').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButton<String>).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Electricity').last);
    await tester.pumpAndSettle();

    final assetTagField = tester.widget<TextFormField>(
      find.byType(TextFormField).first,
    );
    expect(assetTagField.controller!.text, 'TRX-TR-002');
    expect(find.text('Device ID already exists'), findsNothing);
  });
}
