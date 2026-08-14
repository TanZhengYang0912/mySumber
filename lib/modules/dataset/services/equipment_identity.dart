import '../models/models.dart';

String normalizeAssetTag(String value) => value.trim().toUpperCase();

String? normalizedAssetTag(String? value) {
  if (value == null) return null;
  final normalized = normalizeAssetTag(value);
  return normalized.isEmpty ? null : normalized;
}

String equipmentDisplayName(EquipmentNode node) {
  final rawName = node.nodeName.trim();
  final equipmentType = node.equipmentType?.trim();
  final assetTag = normalizedAssetTag(node.assetTag);

  // Older records generated names as "Type · AssetTag". Keep custom names,
  // but remove that identity data from the title when it is still present.
  final separator = rawName.indexOf(' · ');
  if (separator > 0) {
    final prefix = rawName.substring(0, separator).trim();
    final suffix = rawName.substring(separator + 3).trim();
    if ((equipmentType != null && prefix == equipmentType) ||
        (assetTag != null && normalizeAssetTag(suffix) == assetTag)) {
      return prefix;
    }
  }
  if (rawName.isNotEmpty) return rawName;
  if (equipmentType != null && equipmentType.isNotEmpty) return equipmentType;
  return 'Unnamed equipment';
}

String? physicalEquipmentIdentity({
  required String? serialNumber,
  required String? ipAddress,
}) {
  final serial = _normalizeIdentityValue(serialNumber);
  if (serial != null) return 'serial:$serial';

  final ip = _normalizeIdentityValue(ipAddress);
  if (ip != null) return 'ip:$ip';

  return null;
}

String? equipmentNodePhysicalIdentity(EquipmentNode node) {
  return physicalEquipmentIdentity(
    serialNumber: node.serialNumber,
    ipAddress: node.ipAddress,
  );
}

EquipmentNode canonicalizeEquipmentNode(EquipmentNode node) {
  return node.copyWith(
    assetTag: normalizedAssetTag(node.assetTag),
    nodeName: equipmentDisplayName(node),
  );
}

List<EquipmentNode> deduplicateEquivalentEquipmentNodes(
  Iterable<EquipmentNode> source,
) {
  final result = <EquipmentNode>[];
  final keyToIndex = <String, int>{};

  for (final rawNode in source) {
    final node = canonicalizeEquipmentNode(rawNode);
    final keys = <String>[
      if (node.assetTag != null) 'tag:${node.assetTag}',
      if (equipmentNodePhysicalIdentity(node) != null)
        'physical:${equipmentNodePhysicalIdentity(node)}',
    ];
    final existingIndex =
        keys.map((key) => keyToIndex[key]).whereType<int>().firstOrNull;

    if (existingIndex == null) {
      final index = result.length;
      result.add(node);
      for (final key in keys) {
        keyToIndex[key] = index;
      }
      continue;
    }

    if (_equipmentCompleteness(node) >
        _equipmentCompleteness(result[existingIndex])) {
      result[existingIndex] = node;
      for (final key in keys) {
        keyToIndex[key] = existingIndex;
      }
    }
  }

  return result;
}

String? _normalizeIdentityValue(String? value) {
  final normalized = value?.trim().toUpperCase();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

int _equipmentCompleteness(EquipmentNode node) {
  var score = 0;
  final tag = normalizedAssetTag(node.assetTag);
  if (tag != null && !tag.startsWith('LEGACY-')) score += 10;
  if (node.serialNumber?.trim().isNotEmpty == true) score += 4;
  if (node.ipAddress?.trim().isNotEmpty == true) score += 4;
  if (node.facilityId?.trim().isNotEmpty == true) score += 2;
  if (node.modelId?.trim().isNotEmpty == true) score += 2;
  if (node.manufacturerId?.trim().isNotEmpty == true) score += 1;
  return score;
}
