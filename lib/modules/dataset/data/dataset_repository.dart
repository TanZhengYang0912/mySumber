import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import '../services/equipment_import.dart';
import '../services/equipment_identity.dart';

class DatasetRepository {
  DatasetRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;
  final Uuid _uuid = const Uuid();

  // Used only by tests, where no Supabase client is supplied.
  static final List<EquipmentNode> _localNodes = _buildSeedNodes();
  static final List<UtilityLog> _localLogs = [];

  static const List<_FacilitySeed> _facilitySeeds = [
    _FacilitySeed('W.P. Kuala Lumpur', 'Kuala Lumpur', 'Suria KLCC'),
    _FacilitySeed('W.P. Kuala Lumpur', 'Kuala Lumpur', 'Pavilion Kuala Lumpur'),
    _FacilitySeed('W.P. Kuala Lumpur', 'Kuala Lumpur', 'Mid Valley Megamall'),
    _FacilitySeed('W.P. Kuala Lumpur', 'Kuala Lumpur', 'The Exchange TRX'),
    _FacilitySeed('W.P. Kuala Lumpur', 'Kuala Lumpur', 'Berjaya Times Square'),
    _FacilitySeed('Selangor', 'Petaling Jaya', '1 Utama Shopping Centre'),
    _FacilitySeed('Selangor', 'Subang Jaya', 'Sunway Pyramid'),
    _FacilitySeed('Selangor', 'Shah Alam', 'Setia City Mall'),
    _FacilitySeed('Johor', 'Johor Bahru', 'Mid Valley Southkey'),
    _FacilitySeed('Johor', 'Johor Bahru', 'Paradigm Mall Johor Bahru'),
    _FacilitySeed('Pulau Pinang', 'George Town', 'Gurney Plaza'),
    _FacilitySeed('Pulau Pinang', 'Bayan Lepas', 'Queensbay Mall'),
    _FacilitySeed('Sabah', 'Kota Kinabalu', 'Imago Shopping Mall'),
    _FacilitySeed('Sabah', 'Kota Kinabalu', 'Suria Sabah'),
    _FacilitySeed('Sarawak', 'Kuching', 'The Spring Shopping Mall'),
    _FacilitySeed('Sarawak', 'Kuching', 'Vivacity Megamall'),
    _FacilitySeed('Kedah', 'Alor Setar', 'Aman Central'),
    _FacilitySeed('Kelantan', 'Kota Bharu', 'AEON Mall Kota Bharu'),
    _FacilitySeed(
        'Melaka', 'Bandar Melaka', 'Dataran Pahlawan Melaka Megamall'),
    _FacilitySeed('Negeri Sembilan', 'Seremban', 'Palm Mall Seremban'),
    _FacilitySeed('Pahang', 'Kuantan', 'East Coast Mall'),
    _FacilitySeed('Perak', 'Ipoh', 'Ipoh Parade'),
    _FacilitySeed('Perlis', 'Kangar', 'Kangar Central Mall'),
    _FacilitySeed('Terengganu', 'Kuala Terengganu', 'Paya Bunga Square'),
    _FacilitySeed('W.P. Labuan', 'Labuan', 'Financial Park Labuan'),
    _FacilitySeed('W.P. Putrajaya', 'Putrajaya', 'Alamanda Shopping Centre'),
  ];

  static List<EquipmentNode> _buildSeedNodes() {
    final now = DateTime.now();
    final nodes = <EquipmentNode>[];
    for (var i = 0; i < _facilitySeeds.length; i++) {
      final facility = _facilitySeeds[i];
      final subnet = i + 1;
      final facilityCode = 'DEMO-${(i + 1).toString().padLeft(2, '0')}';
      final valveIsCritical = i % 4 == 0;
      final transformerNeedsMaintenance = i % 5 == 0;
      nodes.addAll([
        EquipmentNode(
          nodeId: const Uuid().v4(),
          assetTag: '$facilityCode-WP-001',
          nodeName: 'Main Water Pump A1',
          equipmentType: 'Main Water Pump',
          utilityType: 'Water',
          zoneId: facility.state,
          facilityCode: facilityCode,
          facilityName: facility.name,
          facilityCity: facility.city,
          status: 'Active',
          createdAt: now.subtract(Duration(days: 120 + i)),
          manufacturer: 'Grundfos',
          modelName: 'Unspecified',
          installationDate: now.subtract(Duration(days: 365 + i)),
          lastMaintenanceDate: now.subtract(Duration(days: 15 + i % 12)),
          healthScore: 96 - i % 8,
          firmwareVersion: 'v2.4.1',
          ipAssignment: 'Static',
          ipAddress: '10.0.$subnet.10',
        ),
        EquipmentNode(
          nodeId: const Uuid().v4(),
          assetTag: '$facilityCode-WV-001',
          nodeName: 'Cooling Tower Valve',
          equipmentType: 'Cooling Tower Valve',
          utilityType: 'Water',
          zoneId: facility.state,
          facilityCode: facilityCode,
          facilityName: facility.name,
          facilityCity: facility.city,
          status: valveIsCritical ? 'Critical' : 'Active',
          createdAt: now.subtract(Duration(days: 90 + i)),
          manufacturer: 'Schneider Electric',
          modelName: 'Unspecified',
          installationDate: now.subtract(Duration(days: 240 + i)),
          lastMaintenanceDate: now.subtract(Duration(days: 30 + i % 15)),
          healthScore: valveIsCritical ? 58 : 90 - i % 7,
          firmwareVersion: 'v3.0.5',
          ipAssignment: 'Static',
          ipAddress: '10.0.$subnet.11',
        ),
        EquipmentNode(
          nodeId: const Uuid().v4(),
          assetTag: '$facilityCode-TR-001',
          nodeName: 'Sub-Transformer B2',
          equipmentType: 'Sub-Transformer',
          utilityType: 'Electricity',
          zoneId: facility.state,
          facilityCode: facilityCode,
          facilityName: facility.name,
          facilityCity: facility.city,
          status: transformerNeedsMaintenance ? 'Maintenance' : 'Active',
          createdAt: now.subtract(Duration(days: 150 + i)),
          manufacturer: 'Siemens',
          modelName: 'Unspecified',
          installationDate: now.subtract(Duration(days: 300 + i)),
          lastMaintenanceDate: now.subtract(Duration(days: 2 + i % 20)),
          healthScore: transformerNeedsMaintenance ? 72 : 94 - i % 9,
          firmwareVersion: 'v1.1.0',
          ipAssignment: 'Static',
          ipAddress: '10.0.$subnet.12',
        ),
      ]);
    }
    return nodes;
  }

  Future<List<EquipmentNode>> fetchNodes() async {
    final client = _client;
    if (client == null) return List.from(_localNodes);
    final rows = await client
        .from('equipment_nodes')
        .select()
        .order('facility_name')
        .order('node_name');

    final facilities = {
      for (final row in await client.from('facilities').select('facility_id, name, city'))
        row['facility_id'] as String: (
          name: row['name'] as String,
          city: row['city'] as String,
        ),
    };
    final manufacturers = {
      for (final row in await client.from('manufacturers').select('manufacturer_id, name'))
        row['manufacturer_id'] as String: row['name'] as String,
    };
    final models = {
      for (final row in await client.from('equipment_models').select('model_id, model_name'))
        row['model_id'] as String: row['model_name'] as String,
    };
    final firmwares = {
      for (final row in await client.from('firmware_catalog').select('firmware_id, version'))
        row['firmware_id'] as String: row['version'] as String,
    };

    return rows.map((row) {
      final node = canonicalizeEquipmentNode(
          EquipmentNode.fromMap(Map<String, Object?>.from(row)));
      final facility = facilities[node.facilityId];
      return node.copyWith(
        facilityName: facility?.name ?? node.facilityName,
        facilityCity: facility?.city ?? node.facilityCity,
        manufacturer: manufacturers[node.manufacturerId] ?? node.manufacturer,
        modelName: models[node.modelId] ?? node.modelName,
        firmwareVersion: firmwares[node.firmwareId] ?? node.firmwareVersion,
      );
    }).toList();
  }

  Future<EquipmentImportCatalog> fetchImportCatalog() async {
    final client = _client;
    if (client == null) return catalogFromNodes(_localNodes);

    final facilityRows = await client
        .from('facilities')
        .select('facility_id, facility_code, name, city, state')
        .eq('status', 'Active')
        .order('name');
    final manufacturerRows = await client
        .from('manufacturers')
        .select('manufacturer_id, name')
        .order('name');
    final modelRows = await client
        .from('equipment_models')
        .select(
            'model_id, equipment_type, utility_type, manufacturer_id, model_name')
        .order('equipment_type')
        .order('model_name');
    final firmwareRows = await client
        .from('firmware_catalog')
        .select('firmware_id, model_id, version, is_supported')
        .eq('is_supported', true)
        .order('version');

    final manufacturerNames = {
      for (final raw in manufacturerRows)
        raw['manufacturer_id'] as String: raw['name'] as String,
    };
    final firmwareByModel = <String, Map<String, String>>{};
    for (final raw in firmwareRows) {
      final modelId = raw['model_id'] as String;
      final version = raw['version'] as String;
      firmwareByModel.putIfAbsent(modelId, () => {})[version] =
          raw['firmware_id'] as String;
    }

    return EquipmentImportCatalog(
      facilities: facilityRows
          .map((raw) => ImportFacility(
                facilityId: raw['facility_id'] as String,
                code: raw['facility_code'] as String,
                name: raw['name'] as String,
                city: raw['city'] as String,
                state: raw['state'] as String,
              ))
          .toList(),
      models: modelRows.map((raw) {
        final modelId = raw['model_id'] as String;
        final firmwareIds =
            firmwareByModel[modelId] ?? const <String, String>{};
        return ImportModel(
          modelId: modelId,
          manufacturerId: raw['manufacturer_id'] as String,
          equipmentType: raw['equipment_type'] as String,
          utilityType: raw['utility_type'] as String,
          manufacturer:
              manufacturerNames[raw['manufacturer_id'] as String] ?? 'Unknown',
          model: raw['model_name'] as String,
          firmwareVersions: [
            'Unknown',
            'Pending Verification',
            'Not Applicable',
            ...firmwareIds.keys,
          ],
          firmwareIds: firmwareIds,
        );
      }).toList(),
    );
  }

  Future<void> upsertNode(EquipmentNode node) async {
    await upsertNodes([node]);
  }

  Future<void> upsertNodes(List<EquipmentNode> nodes) async {
    if (nodes.isEmpty) return;
    final savedNodes = nodes.map((node) {
      final assetTag = normalizedAssetTag(node.assetTag);
      if (assetTag == null) {
        throw ArgumentError('Asset Tag is required for equipment records.');
      }
      final canonical = canonicalizeEquipmentNode(
        node.copyWith(assetTag: assetTag),
      );
      return canonical.nodeId == null
          ? canonical.copyWith(nodeId: _uuid.v4(), createdAt: DateTime.now())
          : canonical;
    }).toList();
    final client = _client;
    if (client != null) {
      await client.from('equipment_nodes').upsert(
            savedNodes.map((node) => node.toMap()).toList(),
            onConflict: 'asset_tag',
          );
      return;
    }

    for (final saved in savedNodes) {
      var index = saved.assetTag == null
          ? -1
          : _localNodes.indexWhere(
              (item) => normalizedAssetTag(item.assetTag) == saved.assetTag,
            );
      if (index == -1) {
        index = _localNodes.indexWhere((item) => item.nodeId == saved.nodeId);
      }
      if (index == -1) {
        _localNodes.insert(0, saved);
      } else {
        _localNodes[index] = saved;
      }
    }
  }

  Future<void> deleteNode(String nodeId) async {
    final client = _client;
    if (client != null) {
      await client.from('equipment_nodes').delete().eq('node_id', nodeId);
      return;
    }
    _localNodes.removeWhere((node) => node.nodeId == nodeId);
    _localLogs.removeWhere((log) => log.nodeId == nodeId);
  }

  Future<List<UtilityLog>> fetchLogsForNode(String nodeId) async {
    final client = _client;
    if (client == null) {
      final logs = _localLogs.where((log) => log.nodeId == nodeId).toList();
      logs.sort((a, b) => a.timestamp!.compareTo(b.timestamp!));
      return logs;
    }
    final rows = await client
        .from('equipment_usage_logs')
        .select()
        .eq('node_id', nodeId)
        .order('timestamp');
    return rows
        .map((row) => UtilityLog.fromMap(Map<String, Object?>.from(row)))
        .toList();
  }

  Future<void> insertHistoricalLog(
      String nodeId, double value, DateTime timestamp) async {
    final log = UtilityLog(
        logId: _uuid.v4(),
        nodeId: nodeId,
        usageValue: value,
        timestamp: timestamp);
    final client = _client;
    if (client != null) {
      await client.from('equipment_usage_logs').upsert(log.toMap());
      return;
    }
    _localLogs.add(log);
  }

  Future<void> seedDemoDataIfEmpty() async {
    final client = _client;
    if (client == null) return;
    final existing =
        await client.from('equipment_nodes').select('node_id').limit(1);
    if (existing.isNotEmpty) return;
    await client
        .from('equipment_nodes')
        .insert(_localNodes.map((node) => node.toMap()).toList());
    for (final node in _localNodes) {
      await seedDemoLogsForNode(node);
    }
  }

  Future<void> seedDemoLogsForNode(EquipmentNode node) async {
    final nodeId = node.nodeId;
    if (nodeId == null) return;
    final client = _client;
    if (client == null) {
      if (_localLogs.where((log) => log.nodeId == nodeId).isEmpty) {
        _localLogs.addAll(_demoLogs(node));
      }
      return;
    }
    final existing = await client
        .from('equipment_usage_logs')
        .select('log_id')
        .eq('node_id', nodeId)
        .limit(1);
    if (existing.isEmpty) {
      await client
          .from('equipment_usage_logs')
          .insert(_demoLogs(node).map((log) => log.toMap()).toList());
    }
  }

  List<UtilityLog> _demoLogs(EquipmentNode node) {
    final nodeId = node.nodeId;
    if (nodeId == null) return const [];
    final seed = nodeId.codeUnits.fold<int>(0, (sum, value) => sum + value);
    final random = Random(seed);
    final base = (node.utilityType == 'Water' ? 58.0 : 34.0) +
        random.nextDouble() * (node.utilityType == 'Water' ? 38.0 : 28.0);
    final noise = 2.5 + random.nextDouble() * 5.5;
    final trend = (random.nextDouble() - 0.5) * 0.32;
    final anomalyIndices = <int>{};
    while (anomalyIndices.length < 1 + random.nextInt(3)) {
      anomalyIndices.add(4 + random.nextInt(24));
    }
    final now = DateTime.now();
    return List.generate(30, (index) {
      final wave = sin((index + seed % 11) / 2.4) * noise;
      final jitter = (random.nextDouble() - 0.5) * noise;
      final isAnomaly = anomalyIndices.contains(index);
      final spike = isAnomaly ? base * (0.35 + random.nextDouble() * 0.75) : 0;
      return UtilityLog(
          logId: _uuid.v4(),
          nodeId: nodeId,
          timestamp: now.subtract(Duration(days: 29 - index)),
          usageValue: max(0.1, base + index * trend + wave + jitter + spike),
          isAnomaly: isAnomaly);
    });
  }
}

class _FacilitySeed {
  final String state;
  final String city;
  final String name;
  const _FacilitySeed(this.state, this.city, this.name);
}
