class AlertStatus {
  /// Raised but not yet decided on by an Admin. Alerts sit here while the
  /// AI write-up is generated, and leave it only when an Admin approves them
  /// into the worker queue ([pending]) or rejects them ([faults]).
  static const pendingReview = 'pending_review';
  static const pending = 'pending';
  static const investigating = 'investigating';
  static const resolved = 'resolved';
  static const notFixed = 'not_fixed';
  static const dismissed = 'dismissed';
  static const faults = 'faults';

  // pendingReview is deliberately absent from both lists. Every worker-facing
  // query filters through them, so leaving it out keeps un-approved alerts out
  // of the worker queue without having to patch each query individually.
  static const all = [pending, investigating, resolved, notFixed, dismissed];
  static const unresolved = [pending, investigating, notFixed];

  static String label(String status) {
    switch (status) {
      case pendingReview:
        return 'Pending Review';
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
        return 'Fault';
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

/// What location/model produced an alert. Utility describes Water or
/// Electricity; source scope decides the title and evidence layout.
class AlertSourceScope {
  static const state = 'state';
  static const mall = 'mall';
  static const household = 'household';

  static const all = [state, mall, household];

  static String label(String scope) {
    switch (scope) {
      case state:
        return 'State';
      case mall:
        return 'Mall';
      case household:
        return 'Household';
      default:
        return 'Unknown';
    }
  }
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
        return 'High';
      case medium:
        return 'Medium';
      case low:
        return 'Low';
      default:
        return severity;
    }
  }
}

class Alert {
  final int? id;
  final int? readingId;
  final String alertType;
  final String sourceScope;
  final String? sourceKey;
  final String? utilityType;
  final String? reviewCaseId;
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

  /// Who last moved this alert's status — the display name of the worker or
  /// admin who pressed the button. Null for alerts nobody has touched yet.
  final String? handledBy;
  final String? handledById;
  final bool isDeleted;
  final double? producedMld;
  final double? billedMld;
  final double? lossMld;
  final double? lossPct;
  final int? dataYear;
  final String? aiSummary;
  final String? aiPossibleCause;
  final String? aiSeverityAssessment;
  final String? aiRecommendation;
  final double? aiConfidence;
  final DateTime? aiGeneratedAt;

  const Alert({
    this.id,
    this.readingId,
    required this.alertType,
    String? sourceScope,
    this.sourceKey,
    this.utilityType,
    this.reviewCaseId,
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
    this.handledBy,
    this.handledById,
    this.isDeleted = false,
    this.producedMld,
    this.billedMld,
    this.lossMld,
    this.lossPct,
    this.dataYear,
    this.aiSummary,
    this.aiPossibleCause,
    this.aiSeverityAssessment,
    this.aiRecommendation,
    this.aiConfidence,
    this.aiGeneratedAt,
  }) : sourceScope = sourceScope == AlertSourceScope.state
            ? AlertSourceScope.state
            : sourceScope == AlertSourceScope.mall
                ? AlertSourceScope.mall
                : sourceScope == AlertSourceScope.household
                    ? AlertSourceScope.household
                    : equipmentNodeId != null
                        ? AlertSourceScope.mall
                        : householdId != null
                            ? AlertSourceScope.household
                            : AlertSourceScope.state;

  bool get isNrw => alertType == AlertType.nrwHotspot;
  bool get isElectricity => AlertType.isElectricity(alertType);
  bool get isElectricityHotspot => alertType == AlertType.electricityHotspot;
  bool get isElectricityTampering =>
      alertType == AlertType.electricityTampering;
  Utility get utility => utilityType == 'electricity'
      ? Utility.electricity
      : utilityType == 'water'
          ? Utility.water
          : isElectricity
              ? Utility.electricity
              : Utility.water;
  bool get isMall => sourceScope == AlertSourceScope.mall;
  bool get isHousehold => sourceScope == AlertSourceScope.household;
  String get sourceLabel => AlertSourceScope.label(sourceScope);

  /// True for the per-region loss alerts (water NRW or electricity hotspot)
  /// that share the produced/billed/loss "balance" evidence layout.
  bool get isLossBalance =>
      alertType == AlertType.nrwHotspot ||
      alertType == AlertType.electricityHotspot;

  bool get canRenderBalanceEvidence =>
      sourceScope == AlertSourceScope.state &&
      isLossBalance &&
      producedMld != null &&
      billedMld != null &&
      lossMld != null &&
      lossPct != null;

  bool get canRenderTamperingEvidence =>
      sourceScope == AlertSourceScope.state &&
      isElectricityTampering &&
      producedMld != null &&
      billedMld != null &&
      lossMld != null &&
      lossPct != null;

  double get ratio => baselineL == 0 ? 0 : actualL / baselineL;
  bool get isUnresolved => AlertStatus.unresolved.contains(status);

  bool get hasAiAnalysis =>
      aiSummary != null &&
      aiPossibleCause != null &&
      aiSeverityAssessment != null &&
      aiRecommendation != null &&
      aiConfidence != null &&
      aiGeneratedAt != null;

  String get shortTitle {
    switch (sourceScope) {
      case AlertSourceScope.mall:
        return facilityName ?? state;
      case AlertSourceScope.household:
        return '$state · ${householdId ?? 'Unknown'}';
      default:
        return state;
    }
  }

  String get title => shortTitle;

  Map<String, Object?> toMap() => {
        'id': id,
        'reading_id': readingId,
        'alert_type': alertType,
        'source_scope': sourceScope,
        if (sourceKey != null) 'source_key': sourceKey,
        if (utilityType != null) 'utility_type': utilityType,
        if (reviewCaseId != null) 'review_case_id': reviewCaseId,
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
        'handled_by': handledBy,
        'handled_by_id': handledById,
        'is_deleted': isDeleted,
        'produced_mld': producedMld,
        'billed_mld': billedMld,
        'loss_mld': lossMld,
        'loss_pct': lossPct,
        'data_year': dataYear,
        if (aiSummary != null) 'ai_summary': aiSummary,
        if (aiPossibleCause != null) 'ai_possible_cause': aiPossibleCause,
        if (aiSeverityAssessment != null)
          'ai_severity_assessment': aiSeverityAssessment,
        if (aiRecommendation != null) 'ai_recommendation': aiRecommendation,
        if (aiConfidence != null) 'ai_confidence': aiConfidence,
        if (aiGeneratedAt != null)
          'ai_generated_at': aiGeneratedAt!.toIso8601String(),
      };

  factory Alert.fromMap(Map<String, Object?> map) => Alert(
        id: map['id'] as int?,
        readingId: map['reading_id'] as int?,
        alertType: map['alert_type'] as String,
        sourceScope: map['source_scope'] as String?,
        sourceKey: map['source_key'] as String?,
        utilityType: map['utility_type'] as String?,
        reviewCaseId: map['review_case_id'] as String?,
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
        handledBy: map['handled_by'] as String?,
        handledById: map['handled_by_id'] as String?,
        isDeleted: map['is_deleted'] as bool,
        producedMld: (map['produced_mld'] as num?)?.toDouble(),
        billedMld: (map['billed_mld'] as num?)?.toDouble(),
        lossMld: (map['loss_mld'] as num?)?.toDouble(),
        lossPct: (map['loss_pct'] as num?)?.toDouble(),
        dataYear: map['data_year'] as int?,
        aiSummary: map['ai_summary'] as String?,
        aiPossibleCause: map['ai_possible_cause'] as String?,
        aiSeverityAssessment: map['ai_severity_assessment'] as String?,
        aiRecommendation: map['ai_recommendation'] as String?,
        aiConfidence: (map['ai_confidence'] as num?)?.toDouble(),
        aiGeneratedAt: map['ai_generated_at'] == null
            ? null
            : DateTime.parse(map['ai_generated_at'] as String),
      );

  Alert copyWith({
    int? id,
    String? status,
    String? handledBy,
    String? handledById,
    bool? isDeleted,
    String? sourceScope,
    String? sourceKey,
    String? utilityType,
    String? reviewCaseId,
    String? equipmentNodeId,
    String? facilityName,
    String? facilityCity,
    String? equipmentName,
    String? aiSummary,
    String? aiPossibleCause,
    String? aiSeverityAssessment,
    String? aiRecommendation,
    double? aiConfidence,
    DateTime? aiGeneratedAt,
  }) =>
      Alert(
        id: id ?? this.id,
        readingId: readingId,
        alertType: alertType,
        sourceScope: sourceScope ?? this.sourceScope,
        sourceKey: sourceKey ?? this.sourceKey,
        utilityType: utilityType ?? this.utilityType,
        reviewCaseId: reviewCaseId ?? this.reviewCaseId,
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
        handledBy: handledBy ?? this.handledBy,
        handledById: handledById ?? this.handledById,
        isDeleted: isDeleted ?? this.isDeleted,
        producedMld: producedMld,
        billedMld: billedMld,
        lossMld: lossMld,
        lossPct: lossPct,
        dataYear: dataYear,
        aiSummary: aiSummary ?? this.aiSummary,
        aiPossibleCause: aiPossibleCause ?? this.aiPossibleCause,
        aiSeverityAssessment: aiSeverityAssessment ?? this.aiSeverityAssessment,
        aiRecommendation: aiRecommendation ?? this.aiRecommendation,
        aiConfidence: aiConfidence ?? this.aiConfidence,
        aiGeneratedAt: aiGeneratedAt ?? this.aiGeneratedAt,
      );
}
