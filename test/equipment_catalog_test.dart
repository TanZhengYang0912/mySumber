import 'package:flutter_test/flutter_test.dart';

import 'package:mysumber/modules/dataset/models/models.dart';
import 'package:mysumber/modules/dataset/services/equipment_import.dart';
import 'package:mysumber/modules/dataset/services/equipment_identity.dart';

void main() {
  test('equipment identity and deployment metadata survive map round trip', () {
    const node = EquipmentNode(
      nodeId: 'node-1',
      assetTag: 'MY-SKLC-WP-001',
      nodeName: 'Main Water Pump · MY-SKLC-WP-001',
      equipmentType: 'Main Water Pump',
      utilityType: 'Water',
      zoneId: 'W.P. Kuala Lumpur',
      facilityId: 'facility-1',
      facilityCode: 'SKLC',
      facilityName: 'Suria KLCC',
      facilityCity: 'Kuala Lumpur',
      modelId: 'model-1',
      modelName: 'CR 32-4',
      serialNumber: 'SN-001',
      manufacturer: 'Grundfos',
      firmwareId: 'firmware-1',
      firmwareVersion: '2.4.1',
      ipAssignment: 'Static',
      ipAddress: '10.0.1.10',
      status: 'Active',
    );

    final restored = EquipmentNode.fromMap(node.toMap());

    expect(restored.assetTag, 'MY-SKLC-WP-001');
    expect(restored.equipmentType, 'Main Water Pump');
    expect(restored.facilityId, 'facility-1');
    expect(restored.facilityCode, 'SKLC');
    expect(restored.modelId, 'model-1');
    expect(restored.modelName, 'CR 32-4');
    expect(restored.serialNumber, 'SN-001');
    expect(restored.firmwareId, 'firmware-1');
    expect(restored.ipAssignment, 'Static');
  });

  test('legacy equipment remains readable without canonical identity fields',
      () {
    const node = EquipmentNode(
      nodeName: 'Main Water Pump A1',
      utilityType: 'Water',
      status: 'Active',
    );

    final restored = EquipmentNode.fromMap(node.toMap());

    expect(restored.assetTag, isNull);
    expect(restored.facilityName, isNull);
    expect(restored.ipAssignment, 'Not Assigned');
  });

  test('legacy instance labels become equipment categories', () {
    expect(
      equipmentTypeFromDisplayName('Main Water Pump A1'),
      'Main Water Pump',
    );
    expect(
      equipmentTypeFromDisplayName('Sub-Transformer B2'),
      'Sub-Transformer',
    );
    expect(equipmentTypeFromDisplayName('Cooling Tower Valve'),
        'Cooling Tower Valve');
  });

  test('normalizes asset tags and keeps display names separate', () {
    const node = EquipmentNode(
      assetTag: ' legacy-09fd ',
      nodeName: 'Sub-Transformer · LEGACY-09FD',
      equipmentType: 'Sub-Transformer',
      utilityType: 'Electricity',
      status: 'Active',
    );

    expect(normalizeAssetTag(node.assetTag!), 'LEGACY-09FD');
    expect(equipmentDisplayName(node), 'Sub-Transformer');
    expect(
      equipmentDisplayName(
        const EquipmentNode(
          assetTag: 'LEGACY-09FD',
          nodeName: 'Sub-Transformer · LEGACY-09FD',
          utilityType: 'Electricity',
          status: 'Active',
        ),
      ),
      'Sub-Transformer',
    );
  });

  test('collapses only equivalent equipment records', () {
    const first = EquipmentNode(
      nodeId: 'first',
      assetTag: 'LEGACY-09FD',
      nodeName: 'Sub-Transformer · LEGACY-09FD',
      equipmentType: 'Sub-Transformer',
      utilityType: 'Electricity',
      serialNumber: 'SERIAL-001',
      facilityCode: 'TRX',
      status: 'Active',
    );
    const second = EquipmentNode(
      nodeId: 'second',
      assetTag: 'TRX-TR-001',
      nodeName: 'Sub-Transformer · TRX-TR-001',
      equipmentType: 'Sub-Transformer',
      utilityType: 'Electricity',
      serialNumber: 'SERIAL-001',
      facilityCode: 'TRX',
      status: 'Active',
    );
    const separate = EquipmentNode(
      nodeId: 'separate',
      assetTag: 'TRX-TR-002',
      nodeName: 'Sub-Transformer · TRX-TR-002',
      equipmentType: 'Sub-Transformer',
      utilityType: 'Electricity',
      serialNumber: 'SERIAL-002',
      facilityCode: 'TRX',
      status: 'Active',
    );

    final collapsed = deduplicateEquivalentEquipmentNodes(
      [first, second, separate],
    );

    expect(collapsed, hasLength(2));
    expect(collapsed.map((node) => node.nodeId),
        containsAll(['second', 'separate']));
  });

  test('generates the next available canonical asset tag', () {
    const facility = ImportFacility(
      code: 'TRX',
      name: 'The Exchange TRX',
      city: 'Kuala Lumpur',
      state: 'W.P. Kuala Lumpur',
    );
    final existing = [
      const EquipmentNode(
        nodeName: 'Legacy transformer',
        assetTag: 'LEGACY-09fd8a4eb3-S-001',
        utilityType: 'Electricity',
        status: 'Active',
      ),
      const EquipmentNode(
        nodeName: 'Transformer 1',
        assetTag: 'TRX-TR-001',
        utilityType: 'Electricity',
        status: 'Active',
      ),
      const EquipmentNode(
        nodeName: 'Transformer 3',
        assetTag: 'TRX-TR-003',
        utilityType: 'Electricity',
        status: 'Active',
      ),
    ];

    expect(
      generateAvailableAssetTag(
        facility: facility,
        equipmentType: 'Sub-Transformer',
        existingNodes: existing,
      ),
      'TRX-TR-002',
    );
  });
}
