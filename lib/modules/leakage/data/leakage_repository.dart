import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/alert.dart';
import '../models/anomaly_case.dart';
import '../models/reading.dart';
import '../models/report.dart';

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

  Future<List<AnomalyCase>> anomalyCases({String? sourceScope}) async {
    // AppState starts while the landing screen is still unauthenticated. The
    // Admin-review table is deliberately not readable by anon, so defer this
    // query until a real session exists; the normal polling refresh then loads
    // the correct role-scoped cases after sign-in.
    if (_client.auth.currentUser == null) return const [];
    var query = _client.from('anomaly_cases').select();
    if (sourceScope != null) {
      query = query.eq('source_scope', sourceScope);
    }
    final rows = await query.order('created_at', ascending: false);
    return rows.map((row) => AnomalyCase.fromMap(row)).toList();
  }

  Future<AnomalyCase> insertAnomalyCase(AnomalyCase anomalyCase) async {
    final row = await _client
        .from('anomaly_cases')
        .insert(anomalyCase.toInsertMap())
        .select()
        .single();
    return AnomalyCase.fromMap(row);
  }

  Future<AnomalyCase> upsertAnomalyCase(AnomalyCase anomalyCase) async {
    final row = await _client
        .from('anomaly_cases')
        .upsert(anomalyCase.toInsertMap(), onConflict: 'source_key')
        .select()
        .single();
    return AnomalyCase.fromMap(row);
  }

  Future<int> approveAnomalyCase(String caseId) async {
    final result = await _client.rpc(
      'approve_anomaly_case',
      params: {'p_case_id': caseId},
    );
    return (result as num).toInt();
  }

  Future<void> rejectAnomalyCase(String caseId, String reason) async {
    await _client.rpc(
      'reject_anomaly_case',
      params: {'p_case_id': caseId, 'p_reason': reason},
    );
  }

  Future<void> updateAlertStatus(int id, String status,
      {String? handledBy, String? handledById}) async {
    await _client.from('alerts').update({
      'status': status,
      if (handledBy != null) 'handled_by': handledBy,
      if (handledById != null) 'handled_by_id': handledById,
    }).eq('id', id);
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

  Future<Map<String, String>> workerNames() async {
    final rows = await _client.from('profiles').select('id, full_name');
    return {
      for (final row in rows)
        row['id'] as String: row['full_name'] as String? ?? '',
    };
  }

  Future<void> setReportDeleted(int id, bool isDeleted) async {
    await _client
        .from('reports')
        .update({'is_deleted': isDeleted}).eq('id', id);
  }
}
