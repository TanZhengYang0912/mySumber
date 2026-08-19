import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/local_database/cache_status.dart';
import '../../../core/local_database/local_database.dart';
import '../../../core/local_database/remote_fallback.dart';
import '../models/alert.dart';
import '../models/reading.dart';
import '../models/report.dart';

abstract class LeakageRemoteStore {
  Future<List<Map<String, Object?>>> readings();
  Future<Map<String, Object?>> insertReading(Map<String, Object?> row);
  Future<Map<String, Object?>> insertAlert(Map<String, Object?> row);
  Future<List<Map<String, Object?>>> alerts({required bool includeDismissed});
  Future<Map<String, Object?>?> alertById(int id);
  Future<Map<String, Object?>> updateAlertStatus(int id, String status);
  Future<Map<String, Object?>> updateAlertLocation({
    required int id,
    String? equipmentNodeId,
    String? facilityName,
    String? facilityCity,
    String? equipmentName,
  });
  Future<Map<String, Object?>> insertReport(Map<String, Object?> row);
  Future<List<Map<String, Object?>>> reports({required bool includeDeleted});
  Future<Map<String, Object?>> setReportDeleted(int id, bool isDeleted);
}

class SupabaseLeakageRemoteStore implements LeakageRemoteStore {
  const SupabaseLeakageRemoteStore(this.client);

  final SupabaseClient client;

  @override
  Future<List<Map<String, Object?>>> readings() async {
    final rows = await client
        .from('readings')
        .select()
        .order('reading_date', ascending: false);
    return rows.map((row) => Map<String, Object?>.from(row)).toList();
  }

  @override
  Future<Map<String, Object?>> insertReading(Map<String, Object?> row) async =>
      Map<String, Object?>.from(
          await client.from('readings').insert(row).select().single());

  @override
  Future<Map<String, Object?>> insertAlert(Map<String, Object?> row) async =>
      Map<String, Object?>.from(
          await client.from('alerts').insert(row).select().single());

  @override
  Future<List<Map<String, Object?>>> alerts({
    required bool includeDismissed,
  }) async {
    var query = client.from('alerts').select().eq('is_deleted', false);
    if (!includeDismissed) {
      query = query.neq('status', AlertStatus.dismissed);
    }
    final rows = await query.order('detected_at', ascending: false);
    return rows.map((row) => Map<String, Object?>.from(row)).toList();
  }

  @override
  Future<Map<String, Object?>?> alertById(int id) async {
    final row = await client.from('alerts').select().eq('id', id).maybeSingle();
    return row == null ? null : Map<String, Object?>.from(row);
  }

  @override
  Future<Map<String, Object?>> updateAlertStatus(int id, String status) async =>
      Map<String, Object?>.from(await client
          .from('alerts')
          .update({'status': status})
          .eq('id', id)
          .select()
          .single());

  @override
  Future<Map<String, Object?>> updateAlertLocation({
    required int id,
    String? equipmentNodeId,
    String? facilityName,
    String? facilityCity,
    String? equipmentName,
  }) async =>
      Map<String, Object?>.from(await client
          .from('alerts')
          .update({
            'equipment_node_id': equipmentNodeId,
            'facility_name': facilityName,
            'facility_city': facilityCity,
            'equipment_name': equipmentName,
          })
          .eq('id', id)
          .select()
          .single());

  @override
  Future<Map<String, Object?>> insertReport(Map<String, Object?> row) async =>
      Map<String, Object?>.from(
          await client.from('reports').insert(row).select().single());

  @override
  Future<List<Map<String, Object?>>> reports({
    required bool includeDeleted,
  }) async {
    var query = client.from('reports').select();
    if (!includeDeleted) {
      query = query.eq('is_deleted', false);
    }
    final rows = await query.order('updated_at', ascending: false);
    return rows.map((row) => Map<String, Object?>.from(row)).toList();
  }

  @override
  Future<Map<String, Object?>> setReportDeleted(
    int id,
    bool isDeleted,
  ) async =>
      Map<String, Object?>.from(await client
          .from('reports')
          .update({'is_deleted': isDeleted})
          .eq('id', id)
          .select()
          .single());
}

class LeakageRepository {
  LeakageRepository([SupabaseClient? client])
      : this._(
          remote: SupabaseLeakageRemoteStore(
            client ?? Supabase.instance.client,
          ),
        );

  LeakageRepository.cached({
    required SupabaseClient client,
    required LocalDatabase database,
    required CacheStatus cacheStatus,
  }) : this._(
          remote: SupabaseLeakageRemoteStore(client),
          database: database,
          cacheStatus: cacheStatus,
        );

  LeakageRepository.withRemote({
    required LeakageRemoteStore remote,
    required LocalDatabase database,
    required CacheStatus cacheStatus,
  }) : this._(
          remote: remote,
          database: database,
          cacheStatus: cacheStatus,
        );

  LeakageRepository._({
    required LeakageRemoteStore remote,
    LocalDatabase? database,
    CacheStatus? cacheStatus,
  })  : _remote = remote,
        _database = database,
        _cacheStatus = cacheStatus ?? CacheStatus();

  final LeakageRemoteStore _remote;
  final LocalDatabase? _database;
  final CacheStatus _cacheStatus;

  Future<List<Reading>> readings() async {
    final database = _database;
    if (database == null) {
      return _readingsFromRows(await _remote.readings());
    }
    return remoteFirst(
      remote: () async {
        final rows = await _remote.readings();
        await cacheBestEffort('readings', () async {
          await database.replaceReadings(rows);
          await database.setLastSync('readings', DateTime.now());
        });
        return _readingsFromRows(rows);
      },
      local: () async => _readingsFromRows(await database.readings()),
      hasLocalData: (rows) => rows.isNotEmpty,
      lastSync: () => database.lastSync('readings'),
      status: _cacheStatus,
    );
  }

  Future<int> insertReading(Reading reading) async {
    final request = reading.toMap()..remove('id');
    final row = await _remote.insertReading(request);
    final database = _database;
    if (database != null) {
      await cacheBestEffort('readings', () => database.upsertReading(row));
    }
    _cacheStatus.markOnline();
    return (row['id'] as num).toInt();
  }

  Future<int> insertAlert(Alert alert) async {
    final request = alert.toMap()..remove('id');
    final row = await _remote.insertAlert(request);
    final database = _database;
    if (database != null) {
      await cacheBestEffort('alerts', () => database.upsertAlert(row));
    }
    _cacheStatus.markOnline();
    return (row['id'] as num).toInt();
  }

  Future<List<Alert>> alerts({bool includeDismissed = true}) async {
    final database = _database;
    if (database == null) {
      return _alertsFromRows(
        await _remote.alerts(includeDismissed: includeDismissed),
      );
    }
    return remoteFirst(
      remote: () async {
        final rows = await _remote.alerts(includeDismissed: includeDismissed);
        await cacheBestEffort('alerts', () async {
          if (includeDismissed) {
            await database.replaceAlerts(rows);
          } else {
            await database.replaceVisibleAlerts(rows);
          }
          await database.setLastSync('alerts', DateTime.now());
        });
        return _alertsFromRows(rows);
      },
      local: () async => _alertsFromRows(
        await database.alerts(includeDismissed: includeDismissed),
      ),
      hasLocalData: (rows) => rows.isNotEmpty,
      lastSync: () => database.lastSync('alerts'),
      status: _cacheStatus,
    );
  }

  Future<Alert?> alertById(int id) async {
    final database = _database;
    if (database == null) {
      final row = await _remote.alertById(id);
      return row == null ? null : Alert.fromMap(row);
    }
    return remoteFirst(
      remote: () async {
        final row = await _remote.alertById(id);
        if (row != null) {
          await cacheBestEffort('alerts', () => database.upsertAlert(row));
        }
        return row == null ? null : Alert.fromMap(row);
      },
      local: () async {
        final row = await database.alertById(id);
        return row == null ? null : Alert.fromMap(row);
      },
      hasLocalData: (alert) => alert != null,
      lastSync: () => database.lastSync('alerts'),
      status: _cacheStatus,
    );
  }

  Future<void> updateAlertStatus(int id, String status) async {
    final row = await _remote.updateAlertStatus(id, status);
    final database = _database;
    if (database != null) {
      await cacheBestEffort('alerts', () => database.upsertAlert(row));
    }
    _cacheStatus.markOnline();
  }

  Future<void> updateAlertLocation({
    required int id,
    String? equipmentNodeId,
    String? facilityName,
    String? facilityCity,
    String? equipmentName,
  }) async {
    final row = await _remote.updateAlertLocation(
      id: id,
      equipmentNodeId: equipmentNodeId,
      facilityName: facilityName,
      facilityCity: facilityCity,
      equipmentName: equipmentName,
    );
    final database = _database;
    if (database != null) {
      await cacheBestEffort('alerts', () => database.upsertAlert(row));
    }
    _cacheStatus.markOnline();
  }

  Future<int> insertReport(Report report) async {
    final request = report.toMap()..remove('id');
    final row = await _remote.insertReport(request);
    final database = _database;
    if (database != null) {
      await cacheBestEffort('reports', () => database.upsertReport(row));
    }
    _cacheStatus.markOnline();
    return (row['id'] as num).toInt();
  }

  Future<Set<String>> nrwAlertStates() async => (await alerts())
      .where((alert) => alert.alertType == AlertType.nrwHotspot)
      .map((alert) => alert.state)
      .toSet();

  Future<Set<String>> electricityAlertStates() async => (await alerts())
      .where((alert) => alert.alertType == AlertType.electricityHotspot)
      .map((alert) => alert.state)
      .toSet();

  Future<List<Report>> reports({bool includeDeleted = false}) async {
    final database = _database;
    if (database == null) {
      return _reportsFromRows(
        await _remote.reports(includeDeleted: includeDeleted),
      );
    }
    return remoteFirst(
      remote: () async {
        final rows = await _remote.reports(includeDeleted: includeDeleted);
        await cacheBestEffort('reports', () async {
          if (includeDeleted) {
            await database.replaceReports(rows);
          } else {
            await database.replaceVisibleReports(rows);
          }
          await database.setLastSync('reports', DateTime.now());
        });
        return _reportsFromRows(rows);
      },
      local: () async => _reportsFromRows(
        await database.reports(includeDeleted: includeDeleted),
      ),
      hasLocalData: (rows) => rows.isNotEmpty,
      lastSync: () => database.lastSync('reports'),
      status: _cacheStatus,
    );
  }

  Future<void> setReportDeleted(int id, bool isDeleted) async {
    final row = await _remote.setReportDeleted(id, isDeleted);
    final database = _database;
    if (database != null) {
      await cacheBestEffort('reports', () => database.upsertReport(row));
    }
    _cacheStatus.markOnline();
  }

  List<Alert> _alertsFromRows(List<Map<String, Object?>> rows) =>
      rows.map(Alert.fromMap).toList();

  List<Reading> _readingsFromRows(List<Map<String, Object?>> rows) =>
      rows.map(Reading.fromMap).toList();

  List<Report> _reportsFromRows(List<Map<String, Object?>> rows) =>
      rows.map(Report.fromMap).toList();
}
