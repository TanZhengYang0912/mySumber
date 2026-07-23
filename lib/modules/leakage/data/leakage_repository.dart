import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ai_summary.dart';
import '../models/ai_anomaly_analysis.dart';
import '../models/alert.dart';
import '../models/reading.dart';
import '../models/report.dart';
import '../models/service_review.dart';

class LeakageRepository {
  final SupabaseClient _client;

  LeakageRepository([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  Future<int> insertReading(Reading reading) async {
    final row = await _client
        .from('readings')
        .insert(reading.toMap()..remove('id'))
        .select()
        .single();
    return row['id'] as int;
  }

  Future<int> insertAlert(Alert alert) async {
    final row = await _client
        .from('alerts')
        .insert(alert.toMap()..remove('id'))
        .select()
        .single();
    return row['id'] as int;
  }

  Future<List<Alert>> alerts({bool includeDismissed = true}) async {
    var query = _client.from('alerts').select().eq('is_deleted', false);
    if (!includeDismissed) {
      query = query.neq('status', AlertStatus.dismissed);
    }
    final rows = await query.order('detected_at', ascending: false);
    return rows.map((row) => Alert.fromMap(row)).toList();
  }

  Future<Alert?> alertById(int id) async {
    final row =
        await _client.from('alerts').select().eq('id', id).maybeSingle();
    return row == null ? null : Alert.fromMap(row);
  }

  Future<void> updateAlertStatus(int id, String status) async {
    await _client.from('alerts').update({'status': status}).eq('id', id);
  }

  Future<void> updateAlertLocation({
    required int id,
    String? equipmentNodeId,
    String? facilityName,
    String? facilityCity,
    String? equipmentName,
  }) async {
    await _client.from('alerts').update({
      'equipment_node_id': equipmentNodeId,
      'facility_name': facilityName,
      'facility_city': facilityCity,
      'equipment_name': equipmentName,
    }).eq('id', id);
  }

  Future<void> updateAlertAiAnalysis({
    required int id,
    required AiAnomalyAnalysis analysis,
  }) async {
    await _client.from('alerts').update(analysis.toAlertFields()).eq('id', id);
  }

  Future<int> insertReport(Report report) async {
    final row = await _client
        .from('reports')
        .insert(report.toMap()..remove('id'))
        .select()
        .single();
    return row['id'] as int;
  }

  Future<Set<String>> nrwAlertStates() async {
    final rows = await _client
        .from('alerts')
        .select('state')
        .eq('alert_type', AlertType.nrwHotspot)
        .eq('is_deleted', false);
    return rows.map((row) => row['state'] as String).toSet();
  }

  Future<Set<String>> electricityAlertStates() async {
    final rows = await _client
        .from('alerts')
        .select('state')
        .eq('alert_type', AlertType.electricityHotspot)
        .eq('is_deleted', false);
    return rows.map((row) => row['state'] as String).toSet();
  }

  Future<List<Report>> reports({bool includeDeleted = false}) async {
    var query = _client.from('reports').select();
    if (!includeDeleted) {
      query = query.eq('is_deleted', false);
    }
    final rows = await query.order('updated_at', ascending: false);
    return rows.map((row) => Report.fromMap(row)).toList();
  }

  Future<void> setReportDeleted(int id, bool isDeleted) async {
    await _client
        .from('reports')
        .update({'is_deleted': isDeleted}).eq('id', id);
  }

  // ── Service Reviews ────────────────────────────────────────────────────────

  Future<int> insertReview(ServiceReview review) async {
    final row = await _client
        .from('service_reviews')
        .insert(review.toMap()..remove('id'))
        .select()
        .single();
    return row['id'] as int;
  }

  Future<List<ServiceReview>> reviews() async {
    final rows = await _client
        .from('service_reviews')
        .select()
        .order('created_at', ascending: false);
    return rows.map((r) => ServiceReview.fromMap(r)).toList();
  }

  Future<bool> hasReviewedAlert(int alertId, String email) async {
    final row = await _client
        .from('service_reviews')
        .select('id')
        .eq('alert_id', alertId)
        .eq('consumer_email', email)
        .maybeSingle();
    return row != null;
  }

  // ── AI Summaries ───────────────────────────────────────────────────────────

  Future<AiSummary?> latestAiSummary() async {
    final row = await _client
        .from('ai_summaries')
        .select()
        .order('generated_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return row == null ? null : AiSummary.fromMap(row);
  }

  Future<void> insertAiSummary({
    required String summaryText,
    required List<String> pros,
    required List<String> cons,
    required int reviewCount,
  }) async {
    await _client.from('ai_summaries').insert({
      'summary_text': summaryText,
      'pros': pros,
      'cons': cons,
      'review_count': reviewCount,
    });
  }
}
