import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mysumber/modules/dataset/services/equipment_import.dart';
import 'package:mysumber/modules/dataset/widgets/equipment_import_preview_dialog.dart';

void main() {
  const result = EquipmentImportResult(
    rows: [
      EquipmentImportRow(
        sourceRow: 2,
        assetTag: 'PHONE-IMPORT-WP-001',
        equipmentType: 'Main Water Pump',
        utilityType: 'Water',
        facility: ImportFacility(
          code: 'VIVACITY-MEGAMALL',
          name: 'Vivacity Megamall',
          city: 'Kuching',
          state: 'Sarawak',
        ),
        facilityId: null,
        serialNumber: 'SN-PHONE-IMPORT-001',
        manufacturer: 'Grundfos',
        manufacturerId: null,
        model: 'Unspecified',
        modelId: null,
        ipAssignment: IpAssignment.staticIp,
        ipAddress: '10.16.0.10',
        firmwareVersion: 'v2.4.1',
        firmwareId: null,
        status: 'Active',
        installationDate: null,
        lastMaintenanceDate: null,
        nextMaintenanceDate: null,
      ),
    ],
    issues: [],
    newCount: 1,
    updateCount: 0,
  );

  testWidgets('shows row details before confirming import', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EquipmentImportPreviewDialog(
            fileName: 'MySumber_Equipment_Import_Test.csv',
            result: result,
          ),
        ),
      ),
    );

    expect(find.text('PHONE-IMPORT-WP-001'), findsOneWidget);
    expect(find.textContaining('Vivacity Megamall'), findsOneWidget);
    expect(find.text('Main Water Pump · Water'), findsOneWidget);
    expect(find.text('Confirm import (1)'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });
}
