import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/ai_anomaly_analysis.dart';
import '../models/alert.dart';

enum AnomalyAiFailure {
  missingApiKey,
  timeout,
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

class AnomalyAiService {
  static const endpoint = 'https://api.groq.com/openai/v1/chat/completions';
  static const model = 'llama-3.1-8b-instant';

  final http.Client client;
  final String apiKey;
  final Duration timeout;

  const AnomalyAiService({
    required this.client,
    required this.apiKey,
    this.timeout = const Duration(seconds: 30),
  });

  Future<AiAnomalyAnalysis> generate(Alert alert) async {
    if (apiKey.trim().isEmpty) {
      throw const AnomalyAiException(
        AnomalyAiFailure.missingApiKey,
        'Groq API key is not configured.',
      );
    }

    final request = {
      'model': model,
      'messages': [
        {
          'role': 'system',
          'content': 'You analyze Malaysian water and electricity equipment anomalies. '
              'Return only valid JSON with exactly these keys: summary, '
              'possible_cause, severity_assessment, confidence, recommendation. '
              'severity_assessment must be exactly Low, Medium, or High. '
              'confidence must be a JSON number from 0 to 1, for example 0.85; '
              'do not use a string, percentage, word, or label. '
              'Do not change system status or system severity. Do not recommend '
              'a Worker visit, photo upload, or repair result.',
        },
        {
          'role': 'user',
          'content': _contextFor(alert),
        },
      ],
      'response_format': {'type': 'json_object'},
      'temperature': 0.3,
      'max_tokens': 512,
    };

    late http.Response response;
    try {
      response = await client
          .post(
            Uri.parse(endpoint),
            headers: {
              'Authorization': 'Bearer ${apiKey.trim()}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(request),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const AnomalyAiException(
        AnomalyAiFailure.timeout,
        'Groq request timed out.',
      );
    } on SocketException catch (error) {
      throw AnomalyAiException(AnomalyAiFailure.apiError, error.message);
    } on http.ClientException catch (error) {
      throw AnomalyAiException(AnomalyAiFailure.apiError, error.message);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AnomalyAiException(
        AnomalyAiFailure.apiError,
        'Groq returned HTTP ${response.statusCode}.',
      );
    }

    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = decoded['choices'] as List<dynamic>?;
      final first = choices == null || choices.isEmpty
          ? null
          : choices.first as Map<String, dynamic>;
      final message = first?['message'] as Map<String, dynamic>?;
      final content = message?['content'] as String?;
      if (content == null || content.trim().isEmpty) {
        throw const FormatException('Missing assistant content.');
      }
      return AiAnomalyAnalysis.fromJson(
        jsonDecode(content) as Map<String, dynamic>,
      );
    } on AiAnomalyFormatException catch (error) {
      throw AnomalyAiException(
        AnomalyAiFailure.invalidResponse,
        error.message,
      );
    } catch (error) {
      throw AnomalyAiException(
        AnomalyAiFailure.invalidResponse,
        'Groq response could not be parsed: $error',
      );
    }
  }

  String _contextFor(Alert alert) {
    final location = [
      alert.state,
      alert.facilityName,
      alert.facilityCity,
      alert.equipmentName,
    ].whereType<String>().where((value) => value.trim().isNotEmpty).join(' → ');

    final metrics = <String>[
      'Actual: ${alert.actualL}',
      'Baseline: ${alert.baselineL}',
      if (alert.producedMld != null) 'Produced/supplied: ${alert.producedMld}',
      if (alert.billedMld != null) 'Billed/consumed: ${alert.billedMld}',
      if (alert.lossMld != null) 'Loss: ${alert.lossMld}',
      if (alert.lossPct != null) 'Loss rate: ${alert.lossPct}%',
    ];

    return [
      'Utility: ${alert.utility == Utility.water ? 'Water' : 'Electricity'}',
      'Location: ${location.isEmpty ? 'Not linked' : location}',
      'Alert type: ${alert.alertType}',
      'Alert signature: ${alert.signature}',
      'System severity: ${alert.severity}',
      'Evidence: ${metrics.join('; ')}',
      'Deterministic explanation: ${alert.explanation}',
    ].join('\n');
  }
}
