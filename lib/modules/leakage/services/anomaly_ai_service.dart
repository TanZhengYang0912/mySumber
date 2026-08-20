import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ai_anomaly_analysis.dart';
import '../models/alert.dart';
import '../models/anomaly_case.dart';

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

typedef AnomalyPreviewInvoker = Future<Map<String, dynamic>> Function(
  Map<String, Object?> evidence,
);

typedef AnomalyCaseAnalysisInvoker = Future<Map<String, dynamic>> Function(
  String caseId,
);

class AnomalyAiService {
  const AnomalyAiService._(this._invoke, this._invokePreview, this._invokeCase);

  factory AnomalyAiService({SupabaseClient? client}) {
    final functions = (client ?? Supabase.instance.client).functions;
    return AnomalyAiService._(
      (alertId) async {
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
      },
      (evidence) async {
        final response = await functions.invoke(
          'generate-anomaly-analysis',
          body: {'preview': evidence},
        );
        if (response.status < 200 || response.status >= 300) {
          throw StateError('AI preview request failed.');
        }
        final data = response.data;
        if (data is! Map) throw StateError('AI preview response is invalid.');
        return Map<String, dynamic>.from(data);
      },
      (caseId) async {
        final response = await functions.invoke(
          'generate-anomaly-analysis',
          body: {'case_id': caseId},
        );
        if (response.status < 200 || response.status >= 300) {
          throw StateError('AI case analysis request failed.');
        }
        final data = response.data;
        if (data is! Map) {
          throw StateError('AI case analysis response is invalid.');
        }
        return Map<String, dynamic>.from(data);
      },
    );
  }

  const AnomalyAiService.forTesting(
    AnomalyAnalysisInvoker invoke, [
    AnomalyPreviewInvoker? invokePreview,
    AnomalyCaseAnalysisInvoker? invokeCase,
  ])  : _invoke = invoke,
        _invokePreview = invokePreview ?? _unsupportedPreview,
        _invokeCase = invokeCase ?? _unsupportedCase;

  static Future<Map<String, dynamic>> _unsupportedPreview(
          Map<String, Object?> evidence) =>
      throw UnimplementedError('Preview not configured for this test double.');

  static Future<Map<String, dynamic>> _unsupportedCase(String _) =>
      throw UnimplementedError(
          'Case analysis not configured for this test double.');

  final AnomalyAnalysisInvoker _invoke;
  final AnomalyPreviewInvoker _invokePreview;
  final AnomalyCaseAnalysisInvoker _invokeCase;

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

  Future<AiAnomalyAnalysis> preview(Map<String, Object?> evidence) async {
    try {
      final response = await _invokePreview(evidence);
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
        'AI preview is unavailable. Please try again.',
      );
    }
  }

  Future<AiAnomalyAnalysis> generateCase(AnomalyCase anomalyCase) async {
    final caseId = anomalyCase.id;
    if (caseId == null) {
      throw const AnomalyAiException(
        AnomalyAiFailure.invalidResponse,
        'Cannot analyze a case without an id.',
      );
    }

    try {
      final response = await _invokeCase(caseId);
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
