import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../data/dataset_repository.dart';
import '../models/models.dart';
import '../services/equipment_import.dart';
import '../services/equipment_identity.dart';

class DatasetState extends ChangeNotifier {
  final DatasetRepository repository;

  DatasetState({required this.repository});

  List<EquipmentNode> nodes = [];
  List<UtilityLog> currentLogs = [];
  bool isLoading = false;
  EquipmentNode? selectedNode;
  EquipmentImportCatalog importCatalog = defaultEquipmentImportCatalog();

  Map<String, double> stateWaterSupply = {};
  Map<String, double> stateWaterConsumption = {};
  Map<String, double> stateElectricitySupply = {};
  Map<String, double> stateElectricityConsumption = {};

  Future<void> loadNodes() async {
    isLoading = true;
    notifyListeners();

    try {
      nodes = deduplicateEquivalentEquipmentNodes(
        await repository.fetchNodes(),
      );
      final legacyCatalog = catalogFromNodes(nodes);
      try {
        importCatalog = mergeImportCatalogs(
          await repository.fetchImportCatalog(),
          legacyCatalog,
        );
      } catch (_) {
        // Keep existing inventory usable while a deployment catalog migration
        // is being rolled out or when the catalog tables are unavailable.
        importCatalog = legacyCatalog;
      }
      if (stateWaterSupply.isEmpty) {
        await loadAggregatedStateData();
      }
    } catch (e) {
      debugPrint('Error loading nodes: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addOrUpdateNode(EquipmentNode node) async {
    await repository.upsertNode(node);
    await loadNodes();
  }

  Future<void> importRows(List<EquipmentImportRow> rows) async {
    if (rows.isEmpty) return;
    final existingByAssetTag = {
      for (final node in nodes)
        if (node.assetTag != null) normalizeAssetTag(node.assetTag!): node,
    };
    final existingByPhysicalIdentity = {
      for (final node in nodes)
        if (equipmentNodePhysicalIdentity(node) != null)
          equipmentNodePhysicalIdentity(node)!: node,
    };
    final importedNodes = rows.map((row) {
      final existing = existingByAssetTag[normalizeAssetTag(row.assetTag)] ??
          existingByPhysicalIdentity[physicalEquipmentIdentity(
            serialNumber: row.serialNumber,
            ipAddress: row.ipAddress,
          )];
      final ipAssignment = switch (row.ipAssignment) {
        IpAssignment.staticIp => 'Static',
        IpAssignment.dhcp => 'DHCP',
        IpAssignment.notAssigned => 'Not Assigned',
      };
      return EquipmentNode(
        nodeId: existing?.nodeId,
        assetTag: row.assetTag,
        nodeName: existing == null
            ? row.equipmentType
            : equipmentDisplayName(existing),
        equipmentType: row.equipmentType,
        utilityType: row.utilityType,
        zoneId: row.facility.state,
        facilityId: row.facilityId ?? existing?.facilityId,
        facilityCode: row.facility.code,
        facilityName: row.facility.name,
        facilityCity: row.facility.city,
        modelId: row.modelId ?? existing?.modelId,
        modelName: row.model,
        serialNumber: row.serialNumber ?? existing?.serialNumber,
        status: row.status,
        createdAt: existing?.createdAt,
        manufacturer: row.manufacturer,
        manufacturerId: row.manufacturerId ?? existing?.manufacturerId,
        installationDate: row.installationDate ?? existing?.installationDate,
        lastMaintenanceDate:
            row.lastMaintenanceDate ?? existing?.lastMaintenanceDate,
        nextMaintenanceDate:
            row.nextMaintenanceDate ?? existing?.nextMaintenanceDate,
        healthScore: existing?.healthScore ?? 100,
        firmwareId: row.firmwareId ?? existing?.firmwareId,
        firmwareVersion: row.firmwareVersion,
        ipAssignment: ipAssignment,
        ipAddress: row.ipAddress,
      );
    }).toList();
    await repository.upsertNodes(importedNodes);
    await loadNodes();
  }

  Future<void> deleteNode(String nodeId) async {
    await repository.deleteNode(nodeId);
    await loadNodes();
  }

  Future<void> selectNode(EquipmentNode node) async {
    selectedNode = node;
    isLoading = true;
    notifyListeners();

    try {
      if (selectedNode?.nodeId != null) {
        final selected = selectedNode!;
        currentLogs = await repository.fetchLogsForNode(selected.nodeId!);
      }
    } catch (e) {
      debugPrint('Error loading logs: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadAggregatedStateData() async {
    try {
      // 1. Load Water Supply (Production)
      final waterSupplyStr =
          await rootBundle.loadString('assets/water_production.csv');
      final waterSupplyLines = waterSupplyStr.split('\n');
      for (var line in waterSupplyLines.skip(1)) {
        final p = line.split(',');
        if (p.length >= 3 && p[0] != 'Malaysia' && p[0].trim().isNotEmpty) {
          final state = p[0].trim();
          final val = double.tryParse(p[2]) ?? 0.0;
          stateWaterSupply[state] = (stateWaterSupply[state] ?? 0.0) + val;
        }
      }

      // 2. Load Water Consumption
      final waterConStr =
          await rootBundle.loadString('assets/water_consumption.csv');
      final waterConLines = waterConStr.split('\n');
      for (var line in waterConLines.skip(1)) {
        final p = line.split(',');
        if (p.length >= 4 && p[0] != 'Malaysia' && p[0].trim().isNotEmpty) {
          final state = p[0].trim();
          final val = double.tryParse(p[3]) ?? 0.0;
          stateWaterConsumption[state] =
              (stateWaterConsumption[state] ?? 0.0) + val;
        }
      }

      // 3. Load Electricity Supply
      final elecSupplyStr =
          await rootBundle.loadString('assets/electricity_supply.csv');
      final elecSupplyLines = elecSupplyStr.split('\n');
      for (var line in elecSupplyLines.skip(1)) {
        final p = line.split(',');
        if (p.length >= 4 && p[0] != 'Malaysia' && p[0].trim().isNotEmpty) {
          final state = p[0].trim();
          final val = double.tryParse(p[3]) ?? 0.0;
          stateElectricitySupply[state] =
              (stateElectricitySupply[state] ?? 0.0) + val;
        }
      }

      // 4. Load Electricity Consumption
      final elecConStr =
          await rootBundle.loadString('assets/electricity_consumption.csv');
      final elecConLines = elecConStr.split('\n');
      for (var line in elecConLines.skip(1)) {
        final p = line.split(',');
        if (p.length >= 4 && p[0] != 'Malaysia' && p[0].trim().isNotEmpty) {
          final state = p[0].trim();
          final val = double.tryParse(p[3]) ?? 0.0;
          stateElectricityConsumption[state] =
              (stateElectricityConsumption[state] ?? 0.0) + val;
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading aggregated data: $e');
    }
  }
}
