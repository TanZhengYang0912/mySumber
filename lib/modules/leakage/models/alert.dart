class AlertStatus {
  static const pending = 'pending';
  static const investigating = 'investigating';
  static const resolved = 'resolved';
  static const notFixed = 'not_fixed';
  static const dismissed = 'dismissed';
  static const faults = 'faults';

  static const all = [
    pending,
    investigating,
    resolved,
    notFixed,
    dismissed,
    faults,
  ];
  static const unresolved = [pending, investigating, notFixed];

  static String label(String status) {
    switch (status) {
      case pending:
        return 'Pending';
      case investigating:
        return 'Investigating';
      case resolved:
        return 'Resolved';
      case notFixed:
        return 'Not Fixed';
      case dismissed:
        return 'Dismissed';
      case faults:
        return 'Faults';
      default:
        return status;
    }
  }
}

class AlertType {
  static const nrwHotspot = 'nrw_hotspot';
  static const household = 'household';
  static const electricityHotspot = 'electricity_hotspot';
  static const electricityTampering = 'electricity_tampering';

  static const _electricity = [electricityHotspot, electricityTampering];
  static bool isElectricity(String type) => _electricity.contains(type);
}

/// Which utility an alert belongs to — used to split the worker's Water
/// and Electricity queues, report histories, and detail evidence views.
enum Utility {
  water(['nrw_hotspot', 'household']),
  electricity(['electricity_hotspot', 'electricity_tampering']);

  final List<String> alertTypes;
  const Utility(this.alertTypes);
}

class LeakSignature {
  static const continuousLeak = 'Continuous leak';
  static const suddenBurst = 'Sudden burst';
  static const creepingLeak = 'Creeping leak';
  static const seasonalSpike = 'Seasonal spike';
  static const nrwHotspot = 'NRW hotspot';
  static const electricityHotspot = 'Electricity loss hotspot';
  static const electricityTampering = 'Potential tampering';
}

class Severity {
  static const low = 'low';
  static const medium = 'medium';
  static const high = 'high';

  static String label(String severity) {
    switch (severity) {
      case high:
        return 'High Severity';
      case medium:
        return 'Medium Severity';
      case low:
        return 'Low Severity';
      default:
        return severity;
    }
  }
}

class Alert {
  final int? id;
  final int? readingId;
  final String alertType;
  final String? householdId;
  final String? equipmentNodeId;
  final String? facilityName;
  final String? facilityCity;
  final String? equipmentName;
  final String state;
  final DateTime detectedAt;
  final String signature;
  final String severity;
  final double baselineL;
  final double actualL;
  final String explanation;
  final String status;
  final bool isDeleted;
  final double? producedMld;
  final double? billedMld;
  final double? lossMld;
  final double? lossPct;
  final int? dataYear;

  const Alert({
    this.id,
    this.readingId,
    required this.alertType,
    this.householdId,
    this.equipmentNodeId,
    this.facilityName,
    this.facilityCity,
    this.equipmentName,
    required this.state,
    required this.detectedAt,
    required this.signature,
    required this.severity,
    this.baselineL = 0,
    this.actualL = 0,
    required this.explanation,
    this.status = AlertStatus.pending,
    this.isDeleted = false,
    this.producedMld,
    this.billedMld,
    this.lossMld,
    this.lossPct,
    this.dataYear,
  });

  bool get isNrw => alertType == AlertType.nrwHotspot;
  bool get isElectricity => AlertType.isElectricity(alertType);
  bool get isElectricityHotspot => alertType == AlertType.electricityHotspot;
  bool get isElectricityTampering =>
      alertType == AlertType.electricityTampering;
  Utility get utility => isElectricity ? Utility.electricity : Utility.water;

  /// True for the per-region loss alerts (water NRW or electricity hotspot)
  /// that share the produced/billed/loss "balance" evidence layout.
  bool get isLossBalance =>
      alertType == AlertType.nrwHotspot ||
      alertType == AlertType.electricityHotspot;

  double get ratio => baselineL == 0 ? 0 : actualL / baselineL;
  bool get isUnresolved => AlertStatus.unresolved.contains(status);

  String get title =>
      alertType == AlertType.household ? '$state · ${householdId ?? ''}' : state;

  Map<String, Object?> toMap() => {
        'id': id,
        'reading_id': readingId,
        'alert_type': alertType,
        'household_id': householdId,
        if (equipmentNodeId != null) 'equipment_node_id': equipmentNodeId,
        if (facilityName != null) 'facility_name': facilityName,
        if (facilityCity != null) 'facility_city': facilityCity,
        if (equipmentName != null) 'equipment_name': equipmentName,
        'state': state,
        'detected_at': detectedAt.toIso8601String(),
        'signature': signature,
        'severity': severity,
        'baseline_l': baselineL,
        'actual_l': actualL,
        'explanation': explanation,
        'status': status,
        'is_deleted': isDeleted,
        'produced_mld': producedMld,
        'billed_mld': billedMld,
        'loss_mld': lossMld,
        'loss_pct': lossPct,
        'data_year': dataYear,
      };

  factory Alert.fromMap(Map<String, Object?> map) => Alert(
        id: map['id'] as int?,
        readingId: map['reading_id'] as int?,
        alertType: map['alert_type'] as String,
        householdId: map['household_id'] as String?,
        equipmentNodeId: map['equipment_node_id'] as String?,
        facilityName: map['facility_name'] as String?,
        facilityCity: map['facility_city'] as String?,
        equipmentName: map['equipment_name'] as String?,
        state: map['state'] as String,
        detectedAt: DateTime.parse(map['detected_at'] as String),
        signature: map['signature'] as String,
        severity: map['severity'] as String,
        baselineL: (map['baseline_l'] as num?)?.toDouble() ?? 0,
        actualL: (map['actual_l'] as num?)?.toDouble() ?? 0,
        explanation: map['explanation'] as String,
        status: map['status'] as String,
        isDeleted: map['is_deleted'] as bool,
        producedMld: (map['produced_mld'] as num?)?.toDouble(),
        billedMld: (map['billed_mld'] as num?)?.toDouble(),
        lossMld: (map['loss_mld'] as num?)?.toDouble(),
        lossPct: (map['loss_pct'] as num?)?.toDouble(),
        dataYear: map['data_year'] as int?,
      );

  Alert copyWith({
    int? id,
    String? status,
    bool? isDeleted,
    String? equipmentNodeId,
    String? facilityName,
    String? facilityCity,
    String? equipmentName,
  }) => Alert(
        id: id ?? this.id,
        readingId: readingId,
        alertType: alertType,
        householdId: householdId,
        equipmentNodeId: equipmentNodeId ?? this.equipmentNodeId,
        facilityName: facilityName ?? this.facilityName,
        facilityCity: facilityCity ?? this.facilityCity,
        equipmentName: equipmentName ?? this.equipmentName,
        state: state,
        detectedAt: detectedAt,
        signature: signature,
        severity: severity,
        baselineL: baselineL,
        actualL: actualL,
        explanation: explanation,
        status: status ?? this.status,
        isDeleted: isDeleted ?? this.isDeleted,
        producedMld: producedMld,
        billedMld: billedMld,
        lossMld: lossMld,
        lossPct: lossPct,
        dataYear: dataYear,
      );
}
