class AiAnomalyFormatException implements Exception {
  final String message;

  const AiAnomalyFormatException(this.message);

  @override
  String toString() => 'AiAnomalyFormatException: $message';
}

class AiAnomalyAnalysis {
  static const _allowedSeverities = {'Low', 'Medium', 'High'};

  final String summary;

  /// Null for customer-submitted household reports, where the alert carries no
  /// telemetry for the model to reason about. Asking for a cause there produced
  /// invented ones, so those alerts get a summary and recommendation only.
  final String? possibleCause;
  final String? severityAssessment;
  final double? confidence;
  final String recommendation;
  final DateTime generatedAt;

  const AiAnomalyAnalysis({
    required this.summary,
    this.possibleCause,
    this.severityAssessment,
    this.confidence,
    required this.recommendation,
    required this.generatedAt,
  });

  factory AiAnomalyAnalysis.fromJson(Map<String, dynamic> json) {
    final summary = _textValue(json['summary']);
    final recommendation = _textValue(json['recommendation']);

    final invalidFields = <String>[];
    if (summary.isEmpty) invalidFields.add('summary');
    if (recommendation.isEmpty) invalidFields.add('recommendation');

    String? cause;
    if (json.containsKey('possible_cause')) {
      cause = _textValue(json['possible_cause']);
      if (cause.isEmpty) invalidFields.add('possible_cause');
    }

    String? severity;
    if (json.containsKey('severity_assessment')) {
      severity = _normalizeSeverity(json['severity_assessment']);
      if (!_allowedSeverities.contains(severity)) {
        invalidFields.add('severity_assessment');
      }
    }

    double? confidence;
    if (json.containsKey('confidence')) {
      confidence = _parseConfidence(json['confidence']);
      if (confidence == null || confidence < 0 || confidence > 1) {
        invalidFields.add('confidence');
      }
    }
    if (invalidFields.isNotEmpty) {
      throw AiAnomalyFormatException(
        'Invalid AI response fields: ${invalidFields.join(', ')}',
      );
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

  static String _textValue(Object? value) =>
      value is String ? value.trim() : '';

  static String _normalizeSeverity(Object? value) {
    final normalized = value?.toString().trim().toLowerCase() ?? '';
    for (final severity in _allowedSeverities) {
      if (RegExp('\\b${severity.toLowerCase()}\\b').hasMatch(normalized)) {
        return severity;
      }
    }
    return '';
  }

  static double? _parseConfidence(Object? value) {
    if (value is num) {
      final confidence = value.toDouble();
      return confidence > 1 && confidence <= 100
          ? confidence / 100
          : confidence;
    }

    if (value is! String) return null;
    final text = value.trim();
    final normalized = text.toLowerCase();
    final number = RegExp(r'[-+]?\d*\.?\d+').firstMatch(normalized)?.group(0);
    final parsed = number == null ? null : double.tryParse(number);
    if (parsed == null) return null;
    final isPercentage =
        normalized.contains('%') || normalized.contains('percent');
    return isPercentage || (parsed > 1 && parsed <= 100)
        ? parsed / 100
        : parsed;
  }

  Map<String, Object?> toAlertFields() => {
        'ai_summary': summary,
        'ai_possible_cause': possibleCause,
        'ai_severity_assessment': severityAssessment,
        'ai_recommendation': recommendation,
        'ai_confidence': confidence,
        'ai_generated_at': generatedAt.toIso8601String(),
      };
}
