import 'package:csv/csv.dart';

import 'equipment_identity.dart';

import '../models/models.dart';

enum IpAssignment {
  staticIp,
  dhcp,
  notAssigned,
}

class ImportFacility {
  final String? facilityId;
  final String code;
  final String name;
  final String city;
  final String state;

  const ImportFacility({
    this.facilityId,
    required this.code,
    required this.name,
    required this.city,
    required this.state,
  });
}

class ImportModel {
  final String? modelId;
  final String? manufacturerId;
  final String equipmentType;
  final String utilityType;
  final String manufacturer;
  final String model;
  final List<String> firmwareVersions;
  final Map<String, String> firmwareIds;

  const ImportModel({
    this.modelId,
    this.manufacturerId,
    required this.equipmentType,
    required this.utilityType,
    required this.manufacturer,
    required this.model,
    required this.firmwareVersions,
    this.firmwareIds = const {},
  });
}

class EquipmentImportCatalog {
  final List<ImportFacility> facilities;
  final List<ImportModel> models;

  const EquipmentImportCatalog({
    required this.facilities,
    required this.models,
  });

  ImportFacility? facilityFor(String code) {
    final normalized = _normalize(code).toUpperCase();
    for (final facility in facilities) {
      if (_normalize(facility.code).toUpperCase() == normalized) {
        return facility;
      }
    }
    return null;
  }

  ImportModel? modelFor({
    required String equipmentType,
    required String utilityType,
    required String manufacturer,
    required String model,
  }) {
    final key = _modelKey(
      equipmentType: equipmentType,
      utilityType: utilityType,
      manufacturer: manufacturer,
      model: model,
    );
    for (final candidate in models) {
      if (_modelKey(
            equipmentType: candidate.equipmentType,
            utilityType: candidate.utilityType,
            manufacturer: candidate.manufacturer,
            model: candidate.model,
          ) ==
          key) {
        return candidate;
      }
    }
    return null;
  }
}

/// Returns a stable, human-readable code for generated asset tags.
///
/// Facilities created by the catalog migration can temporarily have a
/// `LEGACY-...` code. That code is unique, but it is not a useful asset-tag
/// prefix and it can reproduce the legacy tag that already exists on the
/// device. Prefer a short code already supplied by the catalog; otherwise
/// derive one from the facility name.
String generatedFacilityCode(ImportFacility facility) {
  final code = facility.code.trim().toUpperCase();
  if (code.isNotEmpty && !code.startsWith('LEGACY-')) {
    return _safeTagPart(code, fallback: 'FACILITY');
  }

  final matches = RegExp(r'[A-Za-z0-9]+').allMatches(facility.name);
  final words = matches.map((match) => match.group(0)!).toList();
  final explicitCode = words
      .where((word) => RegExp(r'^[A-Z0-9]{2,6}$').hasMatch(word))
      .lastOrNull;
  if (explicitCode != null) return explicitCode;

  const ignoredWords = {'THE', 'OF', 'SHOPPING', 'MALL', 'CENTRE', 'CENTER'};
  final initials = words
      .map((word) => word.toUpperCase())
      .where((word) => !ignoredWords.contains(word))
      .map((word) => word[0])
      .take(4)
      .join();
  return _safeTagPart(initials, fallback: 'FACILITY');
}

String equipmentTagTypeCode(String equipmentType) {
  final normalized = equipmentType.trim().toLowerCase();
  const knownCodes = {
    'main water pump': 'MWP',
    'cooling tower valve': 'CTV',
    'sub-transformer': 'TR',
  };
  final known = knownCodes[normalized];
  if (known != null) return known;

  final initials = equipmentType
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .map((word) => word[0].toUpperCase())
      .take(4)
      .join();
  return _safeTagPart(initials, fallback: 'EQUIP');
}

String generateAvailableAssetTag({
  required ImportFacility facility,
  required String equipmentType,
  required Iterable<EquipmentNode> existingNodes,
}) {
  final prefix =
      '${generatedFacilityCode(facility)}-${equipmentTagTypeCode(equipmentType)}';
  final existingTags = existingNodes
      .map((node) => normalizedAssetTag(node.assetTag))
      .whereType<String>()
      .toSet();

  var sequence = 1;
  while (
      existingTags.contains('$prefix-${sequence.toString().padLeft(3, '0')}')) {
    sequence++;
  }
  return '$prefix-${sequence.toString().padLeft(3, '0')}';
}

String _safeTagPart(String value, {required String fallback}) {
  final safe = value.replaceAll(RegExp(r'[^A-Z0-9]+'), '').toUpperCase();
  return safe.isEmpty ? fallback : safe.substring(0, safe.length.clamp(0, 12));
}

EquipmentImportCatalog catalogFromNodes(Iterable<EquipmentNode> nodes) {
  final facilities = <String, ImportFacility>{};
  final models = <String, ImportModel>{};

  for (final node in nodes) {
    final facilityName = node.facilityName;
    if (facilityName != null && facilityName.trim().isNotEmpty) {
      final code = node.facilityCode ?? _catalogCode(facilityName);
      facilities[code] = ImportFacility(
        facilityId: node.facilityId,
        code: code,
        name: facilityName,
        city: node.facilityCity ?? 'Unknown',
        state: node.zoneId ?? 'Unknown',
      );
    }

    final manufacturer = node.manufacturer;
    if (manufacturer == null || manufacturer.trim().isEmpty) continue;
    final equipmentType =
        node.equipmentType ?? equipmentTypeFromDisplayName(node.nodeName);
    final modelName = node.modelName ?? 'Unspecified';
    final key = _modelKey(
      equipmentType: equipmentType,
      utilityType: node.utilityType,
      manufacturer: manufacturer,
      model: modelName,
    );
    final known = models[key];
    final firmware = node.firmwareVersion ?? 'Unknown';
    if (known == null) {
      models[key] = ImportModel(
        modelId: node.modelId,
        manufacturerId: node.manufacturerId,
        equipmentType: equipmentType,
        utilityType: node.utilityType,
        manufacturer: manufacturer,
        model: modelName,
        firmwareVersions: _firmwareOptions([firmware]),
        firmwareIds: node.firmwareId == null
            ? const <String, String>{}
            : {firmware: node.firmwareId!},
      );
    } else if (!known.firmwareVersions.contains(firmware)) {
      models[key] = ImportModel(
        modelId: known.modelId ?? node.modelId,
        manufacturerId: known.manufacturerId ?? node.manufacturerId,
        equipmentType: known.equipmentType,
        utilityType: known.utilityType,
        manufacturer: known.manufacturer,
        model: known.model,
        firmwareVersions: _firmwareOptions([
          ...known.firmwareVersions,
          firmware,
        ]),
        firmwareIds: {
          ...known.firmwareIds,
          if (node.firmwareId != null) firmware: node.firmwareId!,
        },
      );
    }
  }

  if (models.isEmpty) return defaultEquipmentImportCatalog();
  return EquipmentImportCatalog(
    facilities: facilities.values.toList(),
    models: models.values.toList(),
  );
}

/// Legacy rows sometimes stored the instance label in `node_name` only.
/// Keep the instance suffix for Display Name, but use the category as the
/// controlled Equipment Type value.
String equipmentTypeFromDisplayName(String value) {
  final trimmed = value.trim();
  return trimmed.replaceFirst(RegExp(r'\s+[A-Za-z]\d+$'), '').trim();
}

EquipmentImportCatalog mergeImportCatalogs(
  EquipmentImportCatalog primary,
  EquipmentImportCatalog fallback,
) {
  final facilities = <String, ImportFacility>{
    for (final facility in fallback.facilities) facility.code: facility,
  };
  for (final facility in primary.facilities) {
    facilities[facility.code] = facility;
  }

  final models = <String, ImportModel>{};
  for (final model in [...fallback.models, ...primary.models]) {
    final key = _modelKey(
      equipmentType: model.equipmentType,
      utilityType: model.utilityType,
      manufacturer: model.manufacturer,
      model: model.model,
    );
    final existing = models[key];
    if (existing == null) {
      models[key] = model;
      continue;
    }
    models[key] = ImportModel(
      modelId: model.modelId ?? existing.modelId,
      manufacturerId: model.manufacturerId ?? existing.manufacturerId,
      equipmentType: model.equipmentType,
      utilityType: model.utilityType,
      manufacturer: model.manufacturer,
      model: model.model,
      firmwareVersions: _firmwareOptions([
        ...existing.firmwareVersions,
        ...model.firmwareVersions,
      ]),
      firmwareIds: {...existing.firmwareIds, ...model.firmwareIds},
    );
  }
  return EquipmentImportCatalog(
    facilities: facilities.values.toList(),
    models: models.values.toList(),
  );
}

EquipmentImportCatalog defaultEquipmentImportCatalog() =>
    const EquipmentImportCatalog(
      facilities: [],
      models: [
        ImportModel(
          equipmentType: 'Main Water Pump',
          utilityType: 'Water',
          manufacturer: 'Grundfos',
          model: 'Unspecified',
          firmwareVersions: [
            'Unknown',
            'Pending Verification',
            'Not Applicable',
            '2.4.1',
          ],
        ),
        ImportModel(
          equipmentType: 'Cooling Tower Valve',
          utilityType: 'Water',
          manufacturer: 'Schneider Electric',
          model: 'Unspecified',
          firmwareVersions: [
            'Unknown',
            'Pending Verification',
            'Not Applicable',
            '3.0.5',
          ],
        ),
        ImportModel(
          equipmentType: 'Sub-Transformer',
          utilityType: 'Electricity',
          manufacturer: 'Siemens',
          model: 'Unspecified',
          firmwareVersions: [
            'Unknown',
            'Pending Verification',
            'Not Applicable',
            '1.1.0',
          ],
        ),
      ],
    );

class EquipmentImportRow {
  final int sourceRow;
  final String assetTag;
  final String equipmentType;
  final String utilityType;
  final ImportFacility facility;
  final String? facilityId;
  final String? serialNumber;
  final String manufacturer;
  final String? manufacturerId;
  final String model;
  final String? modelId;
  final IpAssignment ipAssignment;
  final String? ipAddress;
  final String firmwareVersion;
  final String? firmwareId;
  final String status;
  final DateTime? installationDate;
  final DateTime? lastMaintenanceDate;
  final DateTime? nextMaintenanceDate;

  const EquipmentImportRow({
    required this.sourceRow,
    required this.assetTag,
    required this.equipmentType,
    required this.utilityType,
    required this.facility,
    required this.facilityId,
    required this.serialNumber,
    required this.manufacturer,
    required this.manufacturerId,
    required this.model,
    required this.modelId,
    required this.ipAssignment,
    required this.ipAddress,
    required this.firmwareVersion,
    required this.firmwareId,
    required this.status,
    required this.installationDate,
    required this.lastMaintenanceDate,
    required this.nextMaintenanceDate,
  });
}

class EquipmentImportIssue {
  final int sourceRow;
  final String column;
  final String message;

  const EquipmentImportIssue({
    required this.sourceRow,
    required this.column,
    required this.message,
  });
}

class EquipmentImportResult {
  final List<EquipmentImportRow> rows;
  final List<EquipmentImportIssue> issues;
  final int newCount;
  final int updateCount;

  const EquipmentImportResult({
    required this.rows,
    required this.issues,
    required this.newCount,
    required this.updateCount,
  });

  bool get canImport => rows.isNotEmpty;

  bool get hasIssues => issues.isNotEmpty;
}

EquipmentImportResult parseEquipmentCsv(
  String csv, {
  required EquipmentImportCatalog catalog,
  Set<String> existingAssetTags = const <String>{},
}) {
  final rows = <EquipmentImportRow>[];
  final issues = <EquipmentImportIssue>[];
  final seenInFile = <String>{};

  List<List<dynamic>> parsed;
  try {
    parsed = const CsvToListConverter(
      shouldParseNumbers: false,
      eol: '\n',
    ).convert(csv);
  } catch (_) {
    return const EquipmentImportResult(
      rows: [],
      issues: [
        EquipmentImportIssue(
          sourceRow: 1,
          column: 'file',
          message: 'The file is not a valid CSV document.',
        ),
      ],
      newCount: 0,
      updateCount: 0,
    );
  }

  if (parsed.isEmpty) {
    return const EquipmentImportResult(
      rows: [],
      issues: [
        EquipmentImportIssue(
          sourceRow: 1,
          column: 'file',
          message: 'The CSV file is empty.',
        ),
      ],
      newCount: 0,
      updateCount: 0,
    );
  }

  final headers = parsed.first.map((value) => _normalize(value)).toList();
  const requiredHeaders = [
    'asset_tag',
    'equipment_type',
    'utility_type',
    'facility_code',
    'manufacturer',
    'model',
    'ip_assignment',
    'firmware_version',
    'status',
  ];
  for (final header in requiredHeaders) {
    if (!headers.contains(header)) {
      issues.add(EquipmentImportIssue(
        sourceRow: 1,
        column: header,
        message: 'Required column is missing.',
      ));
    }
  }
  if (issues.isNotEmpty) {
    return EquipmentImportResult(
      rows: rows,
      issues: issues,
      newCount: 0,
      updateCount: 0,
    );
  }

  final columnIndex = {
    for (var i = 0; i < headers.length; i++) headers[i]: i,
  };
  String valueAt(List<dynamic> values, String name) {
    final index = columnIndex[name];
    if (index == null || index >= values.length) return '';
    return _normalize(values[index]);
  }

  for (var index = 1; index < parsed.length; index++) {
    final sourceRow = index + 1;
    final values = parsed[index];
    if (values.every((value) => _normalize(value).isEmpty)) continue;

    final assetTag = normalizeAssetTag(valueAt(values, 'asset_tag'));
    final equipmentType = valueAt(values, 'equipment_type');
    final rawUtility = valueAt(values, 'utility_type');
    final utilityType = _canonicalUtility(rawUtility);
    final facilityCode = valueAt(values, 'facility_code').toUpperCase();
    final serialNumber = _optional(valueAt(values, 'serial_number'));
    final rawManufacturer = valueAt(values, 'manufacturer');
    final modelName = valueAt(values, 'model');
    final rawIpAssignment = valueAt(values, 'ip_assignment');
    final ipAssignment = _parseIpAssignment(rawIpAssignment);
    final ipAddress = _optional(valueAt(values, 'ip_address'));
    final firmwareVersion = valueAt(values, 'firmware_version');
    final rawStatus = valueAt(values, 'status');
    final status = _canonicalStatus(rawStatus);

    final rowIssues = <EquipmentImportIssue>[];
    void issue(String column, String message) {
      rowIssues.add(EquipmentImportIssue(
        sourceRow: sourceRow,
        column: column,
        message: message,
      ));
    }

    if (assetTag.isEmpty) issue('asset_tag', 'Asset Tag is required.');
    if (assetTag.isNotEmpty && !seenInFile.add(assetTag)) {
      issue('asset_tag', 'Duplicate Asset Tag in this file.');
    }
    if (equipmentType.isEmpty) {
      issue('equipment_type', 'Equipment Type is required.');
    }
    if (utilityType == null) {
      issue('utility_type', 'Utility Type must be Water or Electricity.');
    }

    final facility = catalog.facilityFor(facilityCode);
    if (facility == null) {
      issue('facility_code', 'Facility Code is not registered.');
    }
    if (rawManufacturer.isEmpty) {
      issue('manufacturer', 'Manufacturer is required.');
    }
    if (modelName.isEmpty) issue('model', 'Model is required.');

    final model = utilityType == null || facility == null
        ? null
        : catalog.modelFor(
            equipmentType: equipmentType,
            utilityType: utilityType,
            manufacturer: rawManufacturer,
            model: modelName,
          );
    if (model == null) {
      issue('model', 'The selected equipment model is not registered.');
    }

    if (ipAssignment == null) {
      issue('ip_assignment',
          'IP Assignment must be Static, DHCP, or Not Assigned.');
    } else if (ipAssignment == IpAssignment.staticIp) {
      if (ipAddress == null) {
        issue('ip_address', 'A Static IP requires an IP Address.');
      } else if (!_isValidIp(ipAddress)) {
        issue('ip_address', 'Enter a valid IPv4 or IPv6 address.');
      }
    } else if (ipAddress != null) {
      issue('ip_address', 'IP Address must be empty for DHCP or Not Assigned.');
    }

    if (model != null &&
        (firmwareVersion.isEmpty ||
            !model.firmwareVersions
                .map(_normalize)
                .contains(_normalize(firmwareVersion)))) {
      issue('firmware_version',
          'Firmware Version is not supported by this model.');
    }
    if (status == null) {
      issue('status',
          'Status must be Active, Warning, Critical, or Maintenance.');
    }

    final installationDate = _parseDate(
      valueAt(values, 'installation_date'),
      sourceRow: sourceRow,
      column: 'installation_date',
      onIssue: issue,
    );
    final lastMaintenanceDate = _parseDate(
      valueAt(values, 'last_maintenance_date'),
      sourceRow: sourceRow,
      column: 'last_maintenance_date',
      onIssue: issue,
    );
    final nextMaintenanceDate = _parseDate(
      valueAt(values, 'next_maintenance_date'),
      sourceRow: sourceRow,
      column: 'next_maintenance_date',
      onIssue: issue,
    );

    if (rowIssues.isNotEmpty) {
      issues.addAll(rowIssues);
      continue;
    }

    rows.add(EquipmentImportRow(
      sourceRow: sourceRow,
      assetTag: assetTag,
      equipmentType: model!.equipmentType,
      utilityType: model.utilityType,
      facility: facility!,
      facilityId: facility.facilityId,
      serialNumber: serialNumber,
      manufacturer: model.manufacturer,
      manufacturerId: model.manufacturerId,
      model: model.model,
      modelId: model.modelId,
      ipAssignment: ipAssignment!,
      ipAddress: ipAddress,
      firmwareVersion: firmwareVersion,
      firmwareId: model.firmwareIds[firmwareVersion],
      status: status!,
      installationDate: installationDate,
      lastMaintenanceDate: lastMaintenanceDate,
      nextMaintenanceDate: nextMaintenanceDate,
    ));
  }

  final existing =
      existingAssetTags.map((tag) => tag.trim().toUpperCase()).toSet();
  final updateCount =
      rows.where((row) => existing.contains(row.assetTag)).length;
  return EquipmentImportResult(
    rows: rows,
    issues: issues,
    newCount: rows.length - updateCount,
    updateCount: updateCount,
  );
}

String _normalize(Object? value) => value?.toString().trim() ?? '';

String? _optional(String value) => value.isEmpty ? null : value;

String? _canonicalUtility(String value) {
  switch (value.toLowerCase()) {
    case 'water':
      return 'Water';
    case 'electricity':
      return 'Electricity';
    default:
      return null;
  }
}

String? _canonicalStatus(String value) {
  for (final candidate in ['Active', 'Warning', 'Critical', 'Maintenance']) {
    if (candidate.toLowerCase() == value.toLowerCase()) return candidate;
  }
  return null;
}

IpAssignment? _parseIpAssignment(String value) {
  switch (value.toLowerCase().replaceAll(' ', '')) {
    case 'static':
    case 'staticip':
      return IpAssignment.staticIp;
    case 'dhcp':
      return IpAssignment.dhcp;
    case 'notassigned':
    case 'none':
      return IpAssignment.notAssigned;
    default:
      return null;
  }
}

DateTime? _parseDate(
  String value, {
  required int sourceRow,
  required String column,
  required void Function(String column, String message) onIssue,
}) {
  if (value.isEmpty) return null;
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    onIssue(column, 'Use an ISO date such as 2025-01-12.');
  }
  return parsed;
}

bool _isValidIp(String value) {
  final ipv4Parts = value.split('.');
  if (ipv4Parts.length == 4) {
    return ipv4Parts.every((part) {
      final number = int.tryParse(part);
      return number != null && number >= 0 && number <= 255;
    });
  }
  return value.contains(':') &&
      value.length <= 45 &&
      RegExp(r'^[0-9a-fA-F:]+$').hasMatch(value);
}

String _modelKey({
  required String equipmentType,
  required String utilityType,
  required String manufacturer,
  required String model,
}) =>
    [equipmentType, utilityType, manufacturer, model]
        .map(_normalize)
        .map((value) => value.toLowerCase())
        .join('|');

String _catalogCode(String value) => value
    .toUpperCase()
    .replaceAll(RegExp(r'[^A-Z0-9]+'), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');

List<String> _firmwareOptions(Iterable<String> values) {
  const sentinel = ['Unknown', 'Pending Verification', 'Not Applicable'];
  return [
    ...sentinel,
    ...values.where((value) => !sentinel.contains(value)).toSet(),
  ];
}
