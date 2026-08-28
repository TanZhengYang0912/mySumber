import '../models/models.dart';

/// One shopping mall's rolled-up view: what it owns, what it is drawing, and
/// how much of it needs attention. Kept free of Flutter types so the
/// aggregation can be tested without pumping a widget.
class MallSummary {
  final String name;
  final String state;
  final String? city;
  final double waterUsage;
  final double electricityUsage;
  final String waterStatus;
  final String electricityStatus;
  final int attentionCount;
  final DateTime? lastUpdated;
  final List<EquipmentNode> nodes;

  const MallSummary({
    required this.name,
    required this.state,
    required this.city,
    required this.waterUsage,
    required this.electricityUsage,
    required this.waterStatus,
    required this.electricityStatus,
    required this.attentionCount,
    required this.lastUpdated,
    required this.nodes,
  });

  bool get hasWater => nodes.any((n) => n.utilityType == 'Water');
  bool get hasElectricity => nodes.any((n) => n.utilityType == 'Electricity');

  /// The worse of the two utility statuses, so a mall reads as Critical when
  /// either side is. Ranked by the same table the roll-up already uses.
  String get worstStatus =>
      (_statusRank[waterStatus] ?? 0) >= (_statusRank[electricityStatus] ?? 0)
          ? waterStatus
          : electricityStatus;
}

const _attentionStatuses = {'Critical', 'Warning', 'Maintenance'};

const _statusRank = {
  'Critical': 4,
  'Warning': 3,
  'Maintenance': 2,
  'Active': 1,
};

String _worstStatus(Iterable<EquipmentNode> nodes) {
  var worst = 'Active';
  for (final node in nodes) {
    if ((_statusRank[node.status] ?? 0) > (_statusRank[worst] ?? 0)) {
      worst = node.status;
    }
  }
  return worst;
}

List<MallSummary> buildMallSummaries(
  List<EquipmentNode> nodes,
  Map<String, double> latestUsage,
  Map<String, DateTime> latestTimestamp,
) {
  final byFacility = <String, List<EquipmentNode>>{};
  for (final node in nodes) {
    final facility = node.facilityName;
    if (facility == null || facility.isEmpty) continue;
    byFacility.putIfAbsent(facility, () => []).add(node);
  }

  final summaries = byFacility.entries.map((entry) {
    final owned = entry.value;
    final water = owned.where((n) => n.utilityType == 'Water');
    final electricity = owned.where((n) => n.utilityType == 'Electricity');

    double sum(Iterable<EquipmentNode> group) => group.fold<double>(
          0,
          (total, node) => total + (latestUsage[node.nodeId] ?? 0),
        );

    DateTime? newest;
    for (final node in owned) {
      final timestamp = latestTimestamp[node.nodeId];
      if (timestamp == null) continue;
      if (newest == null || timestamp.isAfter(newest)) newest = timestamp;
    }

    return MallSummary(
      name: entry.key,
      state: owned.first.zoneId ?? 'Unknown',
      city: owned.first.facilityCity,
      waterUsage: sum(water),
      electricityUsage: sum(electricity),
      waterStatus: _worstStatus(water),
      electricityStatus: _worstStatus(electricity),
      attentionCount: owned
          .where((node) => _attentionStatuses.contains(node.status))
          .length,
      lastUpdated: newest,
      nodes: owned,
    );
  }).toList();

  summaries.sort((a, b) => a.name.compareTo(b.name));
  return summaries;
}
