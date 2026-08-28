import 'package:flutter_test/flutter_test.dart';

import 'package:mysumber/modules/dataset/models/models.dart';
import 'package:mysumber/modules/dataset/services/mall_summary.dart';

EquipmentNode _node({
  required String id,
  required String name,
  required String utility,
  String status = 'Active',
  String facility = 'Sunway Pyramid',
}) =>
    EquipmentNode(
      nodeId: id,
      nodeName: name,
      equipmentType: name,
      utilityType: utility,
      status: status,
      zoneId: 'Selangor',
      facilityName: facility,
      facilityCity: 'Subang Jaya',
      ipAssignment: 'DHCP',
    );

void main() {
  test('usage is summed per utility within a mall', () {
    final summaries = buildMallSummaries(
      [
        _node(id: 'a', name: 'Chiller', utility: 'Electricity'),
        _node(id: 'b', name: 'HVAC', utility: 'Electricity'),
        _node(id: 'c', name: 'Water Pump', utility: 'Water'),
      ],
      {'a': 10, 'b': 15, 'c': 7},
      const {},
    );

    expect(summaries, hasLength(1));
    expect(summaries.single.electricityUsage, 25);
    expect(summaries.single.waterUsage, 7);
  });

  test('a mall reports the worst status held by each utility', () {
    final summaries = buildMallSummaries(
      [
        _node(
            id: 'a',
            name: 'Chiller',
            utility: 'Electricity',
            status: 'Warning'),
        _node(
            id: 'b', name: 'HVAC', utility: 'Electricity', status: 'Critical'),
        _node(id: 'c', name: 'Water Pump', utility: 'Water', status: 'Active'),
      ],
      const {},
      const {},
    );

    expect(summaries.single.electricityStatus, 'Critical');
    expect(summaries.single.waterStatus, 'Active');
  });

  test('attention count covers Critical, Warning and Maintenance', () {
    final summaries = buildMallSummaries(
      [
        _node(
            id: 'a',
            name: 'Chiller',
            utility: 'Electricity',
            status: 'Critical'),
        _node(id: 'b', name: 'HVAC', utility: 'Electricity', status: 'Warning'),
        _node(id: 'c', name: 'Toilet', utility: 'Water', status: 'Maintenance'),
        _node(id: 'd', name: 'Valve', utility: 'Water', status: 'Active'),
      ],
      const {},
      const {},
    );

    expect(summaries.single.attentionCount, 3);
  });

  test('malls are separated and sorted by name', () {
    final summaries = buildMallSummaries(
      [
        _node(
            id: 'a',
            name: 'Chiller',
            utility: 'Electricity',
            facility: 'Suria KLCC'),
        _node(
            id: 'b',
            name: 'HVAC',
            utility: 'Electricity',
            facility: 'Gurney Plaza'),
      ],
      const {},
      const {},
    );

    expect(summaries.map((m) => m.name), ['Gurney Plaza', 'Suria KLCC']);
  });

  test('last updated is the newest reading across the mall', () {
    final summaries = buildMallSummaries(
      [
        _node(id: 'a', name: 'Chiller', utility: 'Electricity'),
        _node(id: 'b', name: 'HVAC', utility: 'Electricity'),
      ],
      const {},
      {'a': DateTime(2026, 8, 19), 'b': DateTime(2026, 8, 21)},
    );

    expect(summaries.single.lastUpdated, DateTime(2026, 8, 21));
  });

  test('equipment with no facility is ignored', () {
    final orphan = EquipmentNode(
      nodeId: 'x',
      nodeName: 'Orphan',
      utilityType: 'Water',
      status: 'Active',
      ipAssignment: 'DHCP',
    );
    expect(buildMallSummaries([orphan], const {}, const {}), isEmpty);
  });

  MallSummary summary(String water, String electricity) => MallSummary(
        name: 'Test Mall',
        state: 'Selangor',
        city: 'Petaling Jaya',
        waterUsage: 0,
        electricityUsage: 0,
        waterStatus: water,
        electricityStatus: electricity,
        attentionCount: 0,
        lastUpdated: null,
        nodes: const [],
      );

  test('worstStatus takes the more severe of the two utilities', () {
    expect(summary('Critical', 'Active').worstStatus, 'Critical');
    expect(summary('Active', 'Critical').worstStatus, 'Critical');
  });

  test('worstStatus ranks Warning above Maintenance above Active', () {
    expect(summary('Warning', 'Maintenance').worstStatus, 'Warning');
    expect(summary('Maintenance', 'Active').worstStatus, 'Maintenance');
  });

  test('worstStatus returns the shared value when both agree', () {
    expect(summary('Active', 'Active').worstStatus, 'Active');
  });

  test('worstStatus prefers Critical over Warning from either side', () {
    expect(summary('Warning', 'Critical').worstStatus, 'Critical');
    expect(summary('Critical', 'Warning').worstStatus, 'Critical');
  });
}
