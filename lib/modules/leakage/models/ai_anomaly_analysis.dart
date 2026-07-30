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
    final summary = _textValue(json['summary']);
    final cause = _textValue(json['possible_cause']);
    final severity = _normalizeSeverity(json['severity_assessment']);
    final recommendation = _textValue(json['recommendation']);
    final confidence = _parseConfidence(json['confidence']);

    final invalidFields = <String>[];
    if (summary.isEmpty) invalidFields.add('summary');
    if (cause.isEmpty) invalidFields.add('possible_cause');
    if (!_allowedSeverities.contains(severity)) {
      invalidFields.add('severity_assessment');
    }
    if (recommendation.isEmpty) invalidFields.add('recommendation');
    if (confidence == null || confidence < 0 || confidence > 1) {
      invalidFields.add('confidence');
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
      confidence: confidence!,
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
