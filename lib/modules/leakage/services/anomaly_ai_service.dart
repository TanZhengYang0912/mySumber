import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ai_anomaly_analysis.dart';
import '../models/alert.dart';

enum AnomalyAiFailure {
  apiError,
  invalidResponse,
  alreadyRunning,
}

class AnomalyAiException implements Exception {
  final AnomalyAiFailure failure;
  final String message;

  const AnomalyAiException(this.failure, this.message);

  @override
  String toString() => 'AnomalyAiException($failure): $message';
}

typedef AnomalyAnalysisInvoker = Future<Map<String, dynamic>> Function(
  int alertId,
);

class AnomalyAiService {
  const AnomalyAiService._(this._invoke);

  factory AnomalyAiService({SupabaseClient? client}) {
    final functions = (client ?? Supabase.instance.client).functions;
    return AnomalyAiService._((alertId) async {
      final response = await functions.invoke(
        'generate-anomaly-analysis',
        body: {'alert_id': alertId},
      );
      if (response.status < 200 || response.status >= 300) {
        throw StateError('AI analysis request failed.');
      }
      final data = response.data;
      if (data is! Map) throw StateError('AI analysis response is invalid.');
      return Map<String, dynamic>.from(data);
    });
  }

  const AnomalyAiService.forTesting(AnomalyAnalysisInvoker invoke)
      : _invoke = invoke;

  final AnomalyAnalysisInvoker _invoke;

  Future<AiAnomalyAnalysis> generate(Alert alert) async {
    final alertId = alert.id;
    if (alertId == null) {
      throw const AnomalyAiException(
        AnomalyAiFailure.invalidResponse,
        'Cannot analyze an alert without an id.',
      );
    }

    try {
      final response = await _invoke(alertId);
      final rawAnalysis = response['analysis'];
      if (rawAnalysis is! Map) {
        throw const FormatException('Missing analysis payload.');
      }
      return AiAnomalyAnalysis.fromJson(
        Map<String, dynamic>.from(rawAnalysis),
      );
    } on AiAnomalyFormatException catch (error) {
      throw AnomalyAiException(AnomalyAiFailure.invalidResponse, error.message);
    } on FormatException catch (error) {
      throw AnomalyAiException(AnomalyAiFailure.invalidResponse, error.message);
    } on AnomalyAiException {
      rethrow;
    } catch (_) {
      throw const AnomalyAiException(
        AnomalyAiFailure.apiError,
        'AI analysis is unavailable. Please try again.',
      );
    }
  }
}
