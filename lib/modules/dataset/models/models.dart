class EquipmentNode {
  final String? nodeId;
  final String? assetTag;
  final String nodeName;
  final String? equipmentType;
  final String utilityType;
  final String? zoneId;
  final String? facilityId;
  final String? facilityCode;
  final String? facilityName;
  final String? facilityCity;
  final String? modelId;
  final String? modelName;
  final String? serialNumber;
  final String status;
  final DateTime? createdAt;
  final String? manufacturer;
  final String? manufacturerId;
  final DateTime? installationDate;
  final DateTime? lastMaintenanceDate;
  final DateTime? nextMaintenanceDate;
  final int healthScore;
  final String? firmwareId;
  final String? firmwareVersion;
  final String ipAssignment;
  final String? ipAddress;

  const EquipmentNode({
    this.nodeId,
    this.assetTag,
    required this.nodeName,
    this.equipmentType,
    required this.utilityType,
    this.zoneId,
    this.facilityId,
    this.facilityCode,
    this.facilityName,
    this.facilityCity,
    this.modelId,
    this.modelName,
    this.serialNumber,
    required this.status,
    this.createdAt,
    this.manufacturer,
    this.manufacturerId,
    this.installationDate,
    this.lastMaintenanceDate,
    this.nextMaintenanceDate,
    this.healthScore = 100,
    this.firmwareId,
    this.firmwareVersion,
    this.ipAssignment = 'Not Assigned',
    this.ipAddress,
  });

  Map<String, Object?> toMap() => {
        if (nodeId != null) 'node_id': nodeId,
        if (assetTag != null) 'asset_tag': assetTag,
        'node_name': nodeName,
        if (equipmentType != null) 'equipment_type': equipmentType,
        'utility_type': utilityType,
        if (zoneId != null) 'zone_id': zoneId,
        if (facilityId != null) 'facility_id': facilityId,
        if (facilityCode != null) 'facility_code': facilityCode,
        if (facilityName != null) 'facility_name': facilityName,
        if (facilityCity != null) 'facility_city': facilityCity,
        if (modelId != null) 'model_id': modelId,
        if (modelName != null) 'model_name': modelName,
        if (serialNumber != null) 'serial_number': serialNumber,
        'status': status,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
        if (manufacturer != null) 'manufacturer': manufacturer,
        if (manufacturerId != null) 'manufacturer_id': manufacturerId,
        if (installationDate != null)
          'installation_date': installationDate!.toIso8601String(),
        if (lastMaintenanceDate != null)
          'last_maintenance_date': lastMaintenanceDate!.toIso8601String(),
        if (nextMaintenanceDate != null)
          'next_maintenance_date': nextMaintenanceDate!.toIso8601String(),
        'health_score': healthScore,
        if (firmwareId != null) 'firmware_id': firmwareId,
        if (firmwareVersion != null) 'firmware_version': firmwareVersion,
        'ip_assignment': ipAssignment,
        if (ipAddress != null) 'ip_address': ipAddress,
      };

  factory EquipmentNode.fromMap(Map<String, Object?> map) => EquipmentNode(
        nodeId: map['node_id'] as String?,
        assetTag: map['asset_tag'] as String?,
        nodeName: map['node_name'] as String,
        equipmentType: map['equipment_type'] as String?,
        utilityType: map['utility_type'] as String,
        zoneId: map['zone_id'] as String?,
        facilityId: map['facility_id'] as String?,
        facilityCode: map['facility_code'] as String?,
        facilityName: map['facility_name'] as String?,
        facilityCity: map['facility_city'] as String?,
        modelId: map['model_id'] as String?,
        modelName: map['model_name'] as String?,
        serialNumber: map['serial_number'] as String?,
        status: map['status'] as String,
        createdAt: map['created_at'] != null
            ? DateTime.parse(map['created_at'] as String)
            : null,
        manufacturer: map['manufacturer'] as String?,
        manufacturerId: map['manufacturer_id'] as String?,
        installationDate: map['installation_date'] != null
            ? DateTime.parse(map['installation_date'] as String)
            : null,
        lastMaintenanceDate: map['last_maintenance_date'] != null
            ? DateTime.parse(map['last_maintenance_date'] as String)
            : null,
        nextMaintenanceDate: map['next_maintenance_date'] != null
            ? DateTime.parse(map['next_maintenance_date'] as String)
            : null,
        healthScore: map['health_score'] as int? ?? 100,
        firmwareId: map['firmware_id'] as String?,
        firmwareVersion: map['firmware_version'] as String?,
        ipAssignment: map['ip_assignment'] as String? ?? 'Not Assigned',
        ipAddress: map['ip_address'] as String?,
      );

  EquipmentNode copyWith({
    String? nodeId,
    String? assetTag,
    String? nodeName,
    String? equipmentType,
    String? utilityType,
    String? zoneId,
    String? facilityId,
    String? facilityCode,
    String? facilityName,
    String? facilityCity,
    String? modelId,
    String? modelName,
    String? serialNumber,
    String? status,
    DateTime? createdAt,
    String? manufacturer,
    String? manufacturerId,
    DateTime? installationDate,
    DateTime? lastMaintenanceDate,
    DateTime? nextMaintenanceDate,
    int? healthScore,
    String? firmwareId,
    String? firmwareVersion,
    String? ipAssignment,
    String? ipAddress,
  }) {
    return EquipmentNode(
      nodeId: nodeId ?? this.nodeId,
      assetTag: assetTag ?? this.assetTag,
      nodeName: nodeName ?? this.nodeName,
      equipmentType: equipmentType ?? this.equipmentType,
      utilityType: utilityType ?? this.utilityType,
      zoneId: zoneId ?? this.zoneId,
      facilityId: facilityId ?? this.facilityId,
      facilityCode: facilityCode ?? this.facilityCode,
      facilityName: facilityName ?? this.facilityName,
      facilityCity: facilityCity ?? this.facilityCity,
      modelId: modelId ?? this.modelId,
      modelName: modelName ?? this.modelName,
      serialNumber: serialNumber ?? this.serialNumber,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      manufacturer: manufacturer ?? this.manufacturer,
      manufacturerId: manufacturerId ?? this.manufacturerId,
      installationDate: installationDate ?? this.installationDate,
      lastMaintenanceDate: lastMaintenanceDate ?? this.lastMaintenanceDate,
      nextMaintenanceDate: nextMaintenanceDate ?? this.nextMaintenanceDate,
      healthScore: healthScore ?? this.healthScore,
      firmwareId: firmwareId ?? this.firmwareId,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      ipAssignment: ipAssignment ?? this.ipAssignment,
      ipAddress: ipAddress ?? this.ipAddress,
    );
  }
}

class UtilityLog {
  final String? logId;
  final String nodeId;
  final DateTime? timestamp;
  final double usageValue;
  final bool isAnomaly;

  const UtilityLog({
    this.logId,
    required this.nodeId,
    this.timestamp,
    required this.usageValue,
    this.isAnomaly = false,
  });

  Map<String, Object?> toMap() => {
        if (logId != null) 'log_id': logId,
        'node_id': nodeId,
        if (timestamp != null) 'timestamp': timestamp!.toIso8601String(),
        'usage_value': usageValue,
        'is_anomaly': isAnomaly,
      };

  factory UtilityLog.fromMap(Map<String, Object?> map) => UtilityLog(
        logId: map['log_id'] as String?,
        nodeId: map['node_id'] as String,
        timestamp: map['timestamp'] != null
            ? DateTime.parse(map['timestamp'] as String)
            : null,
        usageValue: (map['usage_value'] as num).toDouble(),
        isAnomaly: map['is_anomaly'] as bool? ?? false,
      );
}
