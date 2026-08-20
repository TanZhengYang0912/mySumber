import 'alert.dart';

class AnomalyCaseStatus {
  static const pendingReview = 'pending_review';
  static const approved = 'approved';
  static const rejected = 'rejected';

  static const all = [pendingReview, approved, rejected];

  static String label(String status) {
    switch (status) {
      case pendingReview:
        return 'Pending Review';
      case approved:
        return 'Approved';
      case rejected:
        return 'Rejected';
      default:
        return status;
    }
  }
}

/// A durable anomaly submission awaiting an Admin decision. It intentionally
/// stores source scope separately from Water/Electricity, then becomes exactly
/// one Worker [Alert] only after approval.
class AnomalyCase {
  final String? id;
  final String sourceScope;
  final String sourceKey;
  final Utility utility;
  final String state;
  final String? facilityName;
  final String? equipmentNodeId;
  final String? equipmentName;
  final String? householdId;
  final String severity;
  final String explanation;
  final Map<String, Object?> evidence;
  final String status;
  final String? rejectionReason;
  final String? submittedBy;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? aiSummary;
  final String? aiPossibleCause;
  final String? aiSeverityAssessment;
  final String? aiRecommendation;
  final double? aiConfidence;
  final DateTime? aiGeneratedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AnomalyCase({
    this.id,
    required this.sourceScope,
    required this.sourceKey,
    required this.utility,
    required this.state,
    this.facilityName,
    this.equipmentNodeId,
    this.equipmentName,
    this.householdId,
    required this.severity,
    required this.explanation,
    this.evidence = const {},
    this.status = AnomalyCaseStatus.pendingReview,
    this.rejectionReason,
    this.submittedBy,
    this.reviewedBy,
    this.reviewedAt,
    this.aiSummary,
    this.aiPossibleCause,
    this.aiSeverityAssessment,
    this.aiRecommendation,
    this.aiConfidence,
    this.aiGeneratedAt,
    this.createdAt,
    this.updatedAt,
  });

  bool get isMall => sourceScope == AlertSourceScope.mall;
  bool get isHousehold => sourceScope == AlertSourceScope.household;
  bool get isState => sourceScope == AlertSourceScope.state;
  String get sourceLabel => AlertSourceScope.label(sourceScope);
  String get utilityLabel => utility == Utility.water ? 'Water' : 'Electricity';
  bool get hasAiAnalysis =>
      aiSummary != null &&
      aiPossibleCause != null &&
      aiSeverityAssessment != null &&
      aiRecommendation != null &&
      aiConfidence != null &&
      aiGeneratedAt != null;

  String get title {
    if (isMall) return facilityName ?? state;
    if (isHousehold) return '$state · ${householdId ?? 'Unknown'}';
    return state;
  }

  Map<String, Object?> toInsertMap() => {
        'source_scope': sourceScope,
        'source_key': sourceKey,
        'utility': utility == Utility.water ? 'water' : 'electricity',
        'state': state,
        'facility_name': facilityName,
        'equipment_node_id': equipmentNodeId,
        'equipment_name': equipmentName,
        'household_id': householdId,
        'severity': severity,
        'explanation': explanation,
        'evidence': evidence,
        if (submittedBy != null) 'submitted_by': submittedBy,
      };

  factory AnomalyCase.fromMap(Map<String, Object?> map) {
    final rawEvidence = map['evidence'];
    return AnomalyCase(
      id: map['id'] as String?,
      sourceScope: map['source_scope'] as String,
      sourceKey: map['source_key'] as String,
      utility:
          map['utility'] == 'electricity' ? Utility.electricity : Utility.water,
      state: map['state'] as String,
      facilityName: map['facility_name'] as String?,
      equipmentNodeId: map['equipment_node_id'] as String?,
      equipmentName: map['equipment_name'] as String?,
      householdId: map['household_id'] as String?,
      severity: map['severity'] as String,
      explanation: map['explanation'] as String,
      evidence: rawEvidence is Map
          ? Map<String, Object?>.from(rawEvidence)
          : const {},
      status: map['status'] as String? ?? AnomalyCaseStatus.pendingReview,
      rejectionReason: map['rejection_reason'] as String?,
      submittedBy: map['submitted_by'] as String?,
      reviewedBy: map['reviewed_by'] as String?,
      reviewedAt: _date(map['reviewed_at']),
      aiSummary: map['ai_summary'] as String?,
      aiPossibleCause: map['ai_possible_cause'] as String?,
      aiSeverityAssessment: map['ai_severity_assessment'] as String?,
      aiRecommendation: map['ai_recommendation'] as String?,
      aiConfidence: (map['ai_confidence'] as num?)?.toDouble(),
      aiGeneratedAt: _date(map['ai_generated_at']),
      createdAt: _date(map['created_at']),
      updatedAt: _date(map['updated_at']),
    );
  }

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;

  AnomalyCase copyWith({
    String? status,
    String? rejectionReason,
    String? aiSummary,
    String? aiPossibleCause,
    String? aiSeverityAssessment,
    String? aiRecommendation,
    double? aiConfidence,
    DateTime? aiGeneratedAt,
    DateTime? reviewedAt,
  }) =>
      AnomalyCase(
        id: id,
        sourceScope: sourceScope,
        sourceKey: sourceKey,
        utility: utility,
        state: state,
        facilityName: facilityName,
        equipmentNodeId: equipmentNodeId,
        equipmentName: equipmentName,
        householdId: householdId,
        severity: severity,
        explanation: explanation,
        evidence: evidence,
        status: status ?? this.status,
        rejectionReason: rejectionReason ?? this.rejectionReason,
        submittedBy: submittedBy,
        reviewedBy: reviewedBy,
        reviewedAt: reviewedAt ?? this.reviewedAt,
        aiSummary: aiSummary ?? this.aiSummary,
        aiPossibleCause: aiPossibleCause ?? this.aiPossibleCause,
        aiSeverityAssessment: aiSeverityAssessment ?? this.aiSeverityAssessment,
        aiRecommendation: aiRecommendation ?? this.aiRecommendation,
        aiConfidence: aiConfidence ?? this.aiConfidence,
        aiGeneratedAt: aiGeneratedAt ?? this.aiGeneratedAt,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
