import 'package:flutter_test/flutter_test.dart';

import 'package:mysumber/modules/dataset/services/equipment_import.dart';

void main() {
  const catalog = EquipmentImportCatalog(
    facilities: [
      ImportFacility(
        code: 'SKLC',
        name: 'Suria KLCC',
        city: 'Kuala Lumpur',
        state: 'W.P. Kuala Lumpur',
      ),
    ],
    models: [
      ImportModel(
        equipmentType: 'Main Water Pump',
        utilityType: 'Water',
        manufacturer: 'Grundfos',
        model: 'CR 32-4',
        firmwareVersions: ['2.4.1', '2.4.2'],
      ),
    ],
  );

  test('parses a valid row and normalizes surrounding whitespace', () {
    const csv = '''asset_tag,equipment_type,utility_type,facility_code,serial_number,manufacturer,model,ip_assignment,ip_address,firmware_version,status,installation_date,next_maintenance_date
 MY-SKLC-WP-001 , Main Water Pump , water , SKLC , SN-001 , grundfos , CR 32-4 , Static , 10.0.1.10 , 2.4.1 , active , 2025-01-12 , 2027-01-01''';

    final result = parseEquipmentCsv(csv, catalog: catalog);

    expect(result.issues, isEmpty);
    expect(result.rows, hasLength(1));
    expect(result.rows.single.assetTag, 'MY-SKLC-WP-001');
    expect(result.rows.single.utilityType, 'Water');
    expect(result.rows.single.facility.code, 'SKLC');
    expect(result.rows.single.ipAddress, '10.0.1.10');
    expect(result.rows.single.status, 'Active');
    expect(result.newCount, 1);
    expect(result.updateCount, 0);
  });

  test('rejects unknown facility, invalid IP, invalid status, and missing asset tag', () {
    const csv = '''asset_tag,equipment_type,utility_type,facility_code,serial_number,manufacturer,model,ip_assignment,ip_address,firmware_version,status
,Main Water Pump,Water,UNKNOWN,SN-002,Grundfos,CR 32-4,Static,999.1.1.1,2.4.1,Online''';

    final result = parseEquipmentCsv(csv, catalog: catalog);

    expect(result.rows, isEmpty);
    expect(
      result.issues.map((issue) => issue.column),
      containsAll(<String>['asset_tag', 'facility_code', 'ip_address', 'status']),
    );
  });

  test('allows an unassigned IP when the assignment mode is DHCP', () {
    const csv = '''asset_tag,equipment_type,utility_type,facility_code,serial_number,manufacturer,model,ip_assignment,ip_address,firmware_version,status
MY-SKLC-WP-002,Main Water Pump,Water,SKLC,SN-003,Grundfos,CR 32-4,DHCP,,2.4.2,Active''';

    final result = parseEquipmentCsv(csv, catalog: catalog);

    expect(result.issues, isEmpty);
    expect(result.rows.single.ipAssignment, IpAssignment.dhcp);
    expect(result.rows.single.ipAddress, isNull);
  });

  test('classifies an existing asset tag as an update and duplicate file tags as errors', () {
    const csv = '''asset_tag,equipment_type,utility_type,facility_code,serial_number,manufacturer,model,ip_assignment,ip_address,firmware_version,status
MY-SKLC-WP-001,Main Water Pump,Water,SKLC,SN-004,Grundfos,CR 32-4,Not Assigned,,2.4.1,Active
MY-SKLC-WP-001,Main Water Pump,Water,SKLC,SN-005,Grundfos,CR 32-4,Not Assigned,,2.4.1,Active''';

    final result = parseEquipmentCsv(
      csv,
      catalog: catalog,
      existingAssetTags: {'MY-SKLC-WP-001'},
    );

    expect(result.rows, hasLength(1));
    expect(result.updateCount, 1);
    expect(result.newCount, 0);
    expect(result.issues.single.column, 'asset_tag');
    expect(result.issues.single.message, contains('Duplicate'));
  });

  test('rejects a firmware version that is not supported by the selected model', () {
    const csv = '''asset_tag,equipment_type,utility_type,facility_code,serial_number,manufacturer,model,ip_assignment,ip_address,firmware_version,status
MY-SKLC-WP-003,Main Water Pump,Water,SKLC,SN-006,Grundfos,CR 32-4,Not Assigned,,9.9.9,Active''';

    final result = parseEquipmentCsv(csv, catalog: catalog);

    expect(result.rows, isEmpty);
    expect(result.issues.single.column, 'firmware_version');
  });

  test('merges canonical catalog IDs with legacy inventory fallbacks', () {
    const canonical = EquipmentImportCatalog(
      facilities: [
        ImportFacility(
          facilityId: 'facility-1',
          code: 'SKLC',
          name: 'Suria KLCC',
          city: 'Kuala Lumpur',
          state: 'W.P. Kuala Lumpur',
        ),
      ],
      models: [
        ImportModel(
          modelId: 'model-1',
          manufacturerId: 'manufacturer-1',
          equipmentType: 'Main Water Pump',
          utilityType: 'Water',
          manufacturer: 'Grundfos',
          model: 'CR 32-4',
          firmwareVersions: ['2.4.1'],
          firmwareIds: {'2.4.1': 'firmware-1'},
        ),
      ],
    );
    const legacy = EquipmentImportCatalog(
      facilities: [
        ImportFacility(
          code: 'LEGACY',
          name: 'Legacy Facility',
          city: 'Petaling Jaya',
          state: 'Selangor',
        ),
      ],
      models: [
        ImportModel(
          equipmentType: 'Main Water Pump',
          utilityType: 'Water',
          manufacturer: 'Grundfos',
          model: 'CR 32-4',
          firmwareVersions: ['Unknown'],
        ),
      ],
    );

    final merged = mergeImportCatalogs(canonical, legacy);
    final model = merged.models.single;

    expect(merged.facilities.map((item) => item.code), containsAll(['SKLC', 'LEGACY']));
    expect(model.modelId, 'model-1');
    expect(model.firmwareIds['2.4.1'], 'firmware-1');
    expect(model.firmwareVersions, contains('Unknown'));
  });
}
