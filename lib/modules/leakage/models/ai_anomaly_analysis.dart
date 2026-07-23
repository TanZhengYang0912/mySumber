class AiAnomalyFormatException implements Exception {
  final String message;

  const AiAnomalyFormatException(this.message);

  @override
  String toString() => 'AiAnomalyFormatException: $message';
}

class AiAnomalyAnalysis {
  static const _allowedSeverities = {'Low', 'Medium', 'High'};

  final String summary;
  final String possibleCause;
  final String severityAssessment;
  final double confidence;
  final String recommendation;
  final DateTime generatedAt;

  const AiAnomalyAnalysis({
    required this.summary,
    required this.possibleCause,
    required this.severityAssessment,
    required this.confidence,
    required this.recommendation,
    required this.generatedAt,
  });

  factory AiAnomalyAnalysis.fromJson(Map<String, dynamic> json) {
    final summary = (json['summary'] as String?)?.trim() ?? '';
    final cause = (json['possible_cause'] as String?)?.trim() ?? '';
    final severity = (json['severity_assessment'] as String?)?.trim() ?? '';
    final recommendation = (json['recommendation'] as String?)?.trim() ?? '';
    final confidence = (json['confidence'] as num?)?.toDouble();

    if (summary.isEmpty ||
        cause.isEmpty ||
        recommendation.isEmpty ||
        !_allowedSeverities.contains(severity) ||
        confidence == null ||
        confidence < 0 ||
        confidence > 1) {
      throw const AiAnomalyFormatException('Invalid AI response fields');
    }

    return AiAnomalyAnalysis(
      summary: summary,
      possibleCause: cause,
      severityAssessment: severity,
      confidence: confidence,
      recommendation: recommendation,
      generatedAt: DateTime.now(),
    );
  }

  Map<String, Object?> toAlertFields() => {
        'ai_summary': summary,
        'ai_possible_cause': possibleCause,
        'ai_recommendation': recommendation,
        'ai_confidence': confidence,
        'ai_generated_at': generatedAt.toIso8601String(),
      };
}
