import 'package:flutter_test/flutter_test.dart';

import 'package:mysumber/modules/dataset/data/dataset_repository.dart';
import 'package:mysumber/modules/dataset/models/models.dart';
import 'package:mysumber/modules/dataset/services/equipment_import.dart';
import 'package:mysumber/modules/dataset/state/dataset_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('batch upsert creates and updates equipment by asset tag', () async {
    final repository = DatasetRepository();
    const assetTag = 'TEST-BATCH-IMPORT-001';

    addTearDown(() async {
      final nodes = await repository.fetchNodes();
      final created = nodes.where((node) => node.assetTag == assetTag);
      for (final node in created) {
        if (node.nodeId != null) await repository.deleteNode(node.nodeId!);
      }
    });

    await repository.upsertNodes([
      const EquipmentNode(
        assetTag: assetTag,
        nodeName: 'Test Pump',
        equipmentType: 'Main Water Pump',
        utilityType: 'Water',
        facilityCode: 'TEST',
        facilityName: 'Test Facility',
        facilityCity: 'Kuala Lumpur',
        manufacturer: 'Grundfos',
        modelName: 'Unspecified',
        ipAssignment: 'Not Assigned',
        status: 'Active',
      ),
    ]);
    final created = (await repository.fetchNodes())
        .singleWhere((node) => node.assetTag == assetTag);

    await repository.upsertNodes([
      EquipmentNode(
        nodeId: created.nodeId,
        assetTag: assetTag,
        nodeName: 'Updated Test Pump',
        equipmentType: 'Main Water Pump',
        utilityType: 'Water',
        facilityCode: 'TEST',
        facilityName: 'Test Facility',
        facilityCity: 'Kuala Lumpur',
        manufacturer: 'Grundfos',
        modelName: 'Unspecified',
        ipAssignment: 'DHCP',
        status: 'Warning',
      ),
    ]);
    final updated = (await repository.fetchNodes())
        .singleWhere((node) => node.assetTag == assetTag);

    expect(updated.nodeName, 'Updated Test Pump');
    expect(updated.status, 'Warning');
    expect(updated.ipAssignment, 'DHCP');
  });

  test('dataset state converts validated import rows into equipment nodes',
      () async {
    final repository = DatasetRepository();
    final state = DatasetState(repository: repository);
    const assetTag = 'TEST-STATE-IMPORT-001';
    final result = parseEquipmentCsv(
      '''asset_tag,equipment_type,utility_type,facility_code,serial_number,manufacturer,model,ip_assignment,ip_address,firmware_version,status
$assetTag,Main Water Pump,Water,TEST,SN-007,Grundfos,Unspecified,Not Assigned,,Unknown,Active''',
      catalog: const EquipmentImportCatalog(
        facilities: [
          ImportFacility(
            facilityId: 'facility-1',
            code: 'TEST',
            name: 'Test Facility',
            city: 'Kuala Lumpur',
            state: 'Selangor',
          ),
        ],
        models: [
          ImportModel(
            modelId: 'model-1',
            manufacturerId: 'manufacturer-1',
            equipmentType: 'Main Water Pump',
            utilityType: 'Water',
            manufacturer: 'Grundfos',
            model: 'Unspecified',
            firmwareVersions: ['Unknown'],
            firmwareIds: {'Unknown': 'firmware-1'},
          ),
        ],
      ),
    );

    addTearDown(() async {
      final nodes = await repository.fetchNodes();
      for (final node in nodes.where((node) => node.assetTag == assetTag)) {
        if (node.nodeId != null) await repository.deleteNode(node.nodeId!);
      }
    });

    await state.importRows(result.rows);

    final imported = (await repository.fetchNodes())
        .singleWhere((node) => node.assetTag == assetTag);
    expect(imported.nodeName, 'Main Water Pump');
    expect(imported.facilityName, 'Test Facility');
    expect(imported.zoneId, 'Selangor');
    expect(imported.serialNumber, 'SN-007');
    expect(imported.facilityId, 'facility-1');
    expect(imported.modelId, 'model-1');
    expect(imported.manufacturerId, 'manufacturer-1');
    expect(imported.firmwareId, 'firmware-1');
    expect(imported.ipAssignment, 'Not Assigned');
  });

  test('import updates a physical device when its asset tag changes', () async {
    final repository = DatasetRepository();
    final state = DatasetState(repository: repository);
    const serialNumber = 'SN-PHYSICAL-DEDUP-001';
    const oldAssetTag = 'LEGACY-PHYSICAL-DEDUP-001';
    const newAssetTag = 'TRX-TR-001';

    await repository.upsertNode(
      const EquipmentNode(
        assetTag: oldAssetTag,
        nodeName: 'Sub-Transformer · LEGACY-PHYSICAL-DEDUP-001',
        equipmentType: 'Sub-Transformer',
        utilityType: 'Electricity',
        facilityCode: 'TRX',
        facilityName: 'The Exchange TRX',
        facilityCity: 'Kuala Lumpur',
        serialNumber: serialNumber,
        manufacturer: 'Siemens',
        modelName: 'Unspecified',
        firmwareVersion: 'Unknown',
        ipAssignment: 'Not Assigned',
        status: 'Active',
      ),
    );

    addTearDown(() async {
      final nodes = await repository.fetchNodes();
      for (final node
          in nodes.where((node) => node.serialNumber == serialNumber)) {
        if (node.nodeId != null) await repository.deleteNode(node.nodeId!);
      }
    });

    await state.loadNodes();
    final result = parseEquipmentCsv(
      '''asset_tag,equipment_type,utility_type,facility_code,serial_number,manufacturer,model,ip_assignment,ip_address,firmware_version,status
$newAssetTag,Sub-Transformer,Electricity,TRX,$serialNumber,Siemens,Unspecified,Not Assigned,,Unknown,Active''',
      catalog: const EquipmentImportCatalog(
        facilities: [
          ImportFacility(
            facilityId: 'facility-trx',
            code: 'TRX',
            name: 'The Exchange TRX',
            city: 'Kuala Lumpur',
            state: 'W.P. Kuala Lumpur',
          ),
        ],
        models: [
          ImportModel(
            modelId: 'model-transformer',
            manufacturerId: 'manufacturer-siemens',
            equipmentType: 'Sub-Transformer',
            utilityType: 'Electricity',
            manufacturer: 'Siemens',
            model: 'Unspecified',
            firmwareVersions: ['Unknown'],
          ),
        ],
      ),
    );

    await state.importRows(result.rows);

    final matches = (await repository.fetchNodes())
        .where((node) => node.serialNumber == serialNumber)
        .toList();
    expect(matches, hasLength(1));
    expect(matches.single.assetTag, newAssetTag);
    expect(matches.single.nodeName, 'Sub-Transformer');
  });
}
