import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'local_database.g.dart';

class LocalEquipmentNodes extends Table {
  TextColumn get nodeId => text()();
  TextColumn get facilityName => text().nullable()();
  TextColumn get nodeName => text()();
  TextColumn get payload => text()();

  @override
  Set<Column<Object>> get primaryKey => {nodeId};
}

class LocalEquipmentUsageLogs extends Table {
  TextColumn get logId => text()();
  TextColumn get nodeId => text()();
  DateTimeColumn get loggedAt => dateTime()();
  TextColumn get payload => text()();

  @override
  Set<Column<Object>> get primaryKey => {logId};
}

class LocalReadings extends Table {
  IntColumn get remoteId => integer()();
  TextColumn get payload => text()();

  @override
  Set<Column<Object>> get primaryKey => {remoteId};
}

class LocalAlerts extends Table {
  IntColumn get remoteId => integer()();
  TextColumn get status => text()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get detectedAt => dateTime()();
  TextColumn get payload => text()();

  @override
  Set<Column<Object>> get primaryKey => {remoteId};
}

class LocalReports extends Table {
  IntColumn get remoteId => integer()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get payload => text()();

  @override
  Set<Column<Object>> get primaryKey => {remoteId};
}

class LocalCustomerUtilityEntries extends Table {
  IntColumn get remoteId => integer()();
  TextColumn get userId => text()();
  TextColumn get utility => text()();
  DateTimeColumn get periodMonth => dateTime()();
  TextColumn get payload => text()();

  @override
  Set<Column<Object>> get primaryKey => {remoteId, userId};
}

class LocalSyncMetadata extends Table {
  TextColumn get scope => text()();
  DateTimeColumn get syncedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {scope};
}

@DriftDatabase(tables: [
  LocalEquipmentNodes,
  LocalEquipmentUsageLogs,
  LocalReadings,
  LocalAlerts,
  LocalReports,
  LocalCustomerUtilityEntries,
  LocalSyncMetadata,
])
class LocalDatabase extends _$LocalDatabase {
  LocalDatabase.defaults() : super(driftDatabase(name: 'mysumber_cache'));

  LocalDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  Future<void> replaceEquipmentNodes(
    List<Map<String, Object?>> rows,
  ) async {
    await transaction(() async {
      await delete(localEquipmentNodes).go();
      if (rows.isNotEmpty) {
        await batch((batch) => batch.insertAll(
              localEquipmentNodes,
              rows.map(_equipmentNodeCompanion).toList(),
            ));
      }
    });
  }

  Future<void> upsertEquipmentNode(Map<String, Object?> row) =>
      into(localEquipmentNodes).insertOnConflictUpdate(
        _equipmentNodeCompanion(row),
      );

  Future<void> deleteEquipmentNode(String nodeId) async {
    await (delete(localEquipmentNodes)
          ..where((row) => row.nodeId.equals(nodeId)))
        .go();
    await (delete(localEquipmentUsageLogs)
          ..where((row) => row.nodeId.equals(nodeId)))
        .go();
  }

  Future<List<Map<String, Object?>>> equipmentNodes() async {
    final rows = await (select(localEquipmentNodes)
          ..orderBy([
            (row) => OrderingTerm.asc(row.facilityName),
            (row) => OrderingTerm.asc(row.nodeName),
          ]))
        .get();
    return rows.map((row) => _decode(row.payload)).toList();
  }

  Future<void> replaceEquipmentLogs(
    String nodeId,
    List<Map<String, Object?>> rows,
  ) async {
    await transaction(() async {
      await (delete(localEquipmentUsageLogs)
            ..where((row) => row.nodeId.equals(nodeId)))
          .go();
      if (rows.isNotEmpty) {
        await batch((batch) => batch.insertAll(
              localEquipmentUsageLogs,
              rows.map(_equipmentLogCompanion).toList(),
            ));
      }
    });
  }

  Future<void> upsertEquipmentLog(Map<String, Object?> row) =>
      into(localEquipmentUsageLogs).insertOnConflictUpdate(
        _equipmentLogCompanion(row),
      );

  Future<List<Map<String, Object?>>> equipmentLogs(String nodeId) async {
    final rows = await (select(localEquipmentUsageLogs)
          ..where((row) => row.nodeId.equals(nodeId))
          ..orderBy([(row) => OrderingTerm.asc(row.loggedAt)]))
        .get();
    return rows.map((row) => _decode(row.payload)).toList();
  }

  Future<void> upsertReading(Map<String, Object?> row) =>
      into(localReadings).insertOnConflictUpdate(
        LocalReadingsCompanion.insert(
          remoteId: Value(_int(row, 'id')),
          payload: jsonEncode(row),
        ),
      );

  Future<void> replaceReadings(List<Map<String, Object?>> rows) async {
    await transaction(() async {
      await delete(localReadings).go();
      if (rows.isNotEmpty) {
        await batch((batch) => batch.insertAll(
              localReadings,
              rows
                  .map((row) => LocalReadingsCompanion.insert(
                        remoteId: Value(_int(row, 'id')),
                        payload: jsonEncode(row),
                      ))
                  .toList(),
            ));
      }
    });
  }

  Future<List<Map<String, Object?>>> readings() async {
    final rows = await select(localReadings).get();
    return rows.map((row) => _decode(row.payload)).toList();
  }

  Future<void> replaceAlerts(List<Map<String, Object?>> rows) async {
    await transaction(() async {
      await delete(localAlerts).go();
      if (rows.isNotEmpty) {
        await batch((batch) => batch.insertAll(
              localAlerts,
              rows.map(_alertCompanion).toList(),
            ));
      }
    });
  }

  Future<void> replaceVisibleAlerts(List<Map<String, Object?>> rows) async {
    await transaction(() async {
      await (delete(localAlerts)
            ..where((row) =>
                row.isDeleted.equals(false) &
                row.status.equals('dismissed').not()))
          .go();
      if (rows.isNotEmpty) {
        await batch((batch) => batch.insertAll(
              localAlerts,
              rows.map(_alertCompanion).toList(),
              mode: InsertMode.insertOrReplace,
            ));
      }
    });
  }

  Future<void> upsertAlert(Map<String, Object?> row) =>
      into(localAlerts).insertOnConflictUpdate(_alertCompanion(row));

  Future<Map<String, Object?>?> alertById(int id) async {
    final row = await (select(localAlerts)
          ..where((row) => row.remoteId.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _decode(row.payload);
  }

  Future<List<Map<String, Object?>>> alerts({
    bool includeDismissed = true,
  }) async {
    final query = select(localAlerts)
      ..where((row) => row.isDeleted.equals(false));
    if (!includeDismissed) {
      query.where((row) => row.status.equals('dismissed').not());
    }
    query.orderBy([(row) => OrderingTerm.desc(row.detectedAt)]);
    final rows = await query.get();
    return rows.map((row) => _decode(row.payload)).toList();
  }

  Future<void> replaceReports(List<Map<String, Object?>> rows) async {
    await transaction(() async {
      await delete(localReports).go();
      if (rows.isNotEmpty) {
        await batch((batch) => batch.insertAll(
              localReports,
              rows.map(_reportCompanion).toList(),
            ));
      }
    });
  }

  Future<void> replaceVisibleReports(List<Map<String, Object?>> rows) async {
    await transaction(() async {
      await (delete(localReports)..where((row) => row.isDeleted.equals(false)))
          .go();
      if (rows.isNotEmpty) {
        await batch((batch) => batch.insertAll(
              localReports,
              rows.map(_reportCompanion).toList(),
              mode: InsertMode.insertOrReplace,
            ));
      }
    });
  }

  Future<void> upsertReport(Map<String, Object?> row) =>
      into(localReports).insertOnConflictUpdate(_reportCompanion(row));

  Future<List<Map<String, Object?>>> reports({
    bool includeDeleted = false,
  }) async {
    final query = select(localReports);
    if (!includeDeleted) {
      query.where((row) => row.isDeleted.equals(false));
    }
    query.orderBy([(row) => OrderingTerm.desc(row.updatedAt)]);
    final rows = await query.get();
    return rows.map((row) => _decode(row.payload)).toList();
  }

  Future<void> replaceCustomerEntries({
    required String userId,
    required String utility,
    required List<Map<String, Object?>> rows,
  }) async {
    await transaction(() async {
      await (delete(localCustomerUtilityEntries)
            ..where((row) =>
                row.userId.equals(userId) & row.utility.equals(utility)))
          .go();
      if (rows.isNotEmpty) {
        await batch((batch) => batch.insertAll(
              localCustomerUtilityEntries,
              rows.map((row) => _customerEntryCompanion(row, userId)).toList(),
            ));
      }
    });
  }

  Future<void> upsertCustomerEntry(
    String userId,
    Map<String, Object?> row,
  ) =>
      into(localCustomerUtilityEntries).insertOnConflictUpdate(
        _customerEntryCompanion(row, userId),
      );

  Future<List<Map<String, Object?>>> customerEntries(
    String userId,
    String utility,
  ) async {
    final rows = await (select(localCustomerUtilityEntries)
          ..where(
              (row) => row.userId.equals(userId) & row.utility.equals(utility))
          ..orderBy([(row) => OrderingTerm.asc(row.periodMonth)]))
        .get();
    return rows.map((row) => _decode(row.payload)).toList();
  }

  Future<void> setLastSync(String scope, DateTime syncedAt) =>
      into(localSyncMetadata).insertOnConflictUpdate(
        LocalSyncMetadataCompanion.insert(scope: scope, syncedAt: syncedAt),
      );

  Future<DateTime?> lastSync(String scope) async {
    final row = await (select(localSyncMetadata)
          ..where((row) => row.scope.equals(scope)))
        .getSingleOrNull();
    return row?.syncedAt.toUtc();
  }

  LocalEquipmentNodesCompanion _equipmentNodeCompanion(
    Map<String, Object?> row,
  ) =>
      LocalEquipmentNodesCompanion.insert(
        nodeId: _string(row, 'node_id'),
        facilityName: Value(row['facility_name'] as String?),
        nodeName: _string(row, 'node_name'),
        payload: jsonEncode(row),
      );

  LocalEquipmentUsageLogsCompanion _equipmentLogCompanion(
    Map<String, Object?> row,
  ) =>
      LocalEquipmentUsageLogsCompanion.insert(
        logId: _string(row, 'log_id'),
        nodeId: _string(row, 'node_id'),
        loggedAt: _date(row, 'timestamp'),
        payload: jsonEncode(row),
      );

  LocalAlertsCompanion _alertCompanion(Map<String, Object?> row) =>
      LocalAlertsCompanion.insert(
        remoteId: Value(_int(row, 'id')),
        status: _string(row, 'status'),
        isDeleted: Value(row['is_deleted'] as bool? ?? false),
        detectedAt: _date(row, 'detected_at'),
        payload: jsonEncode(row),
      );

  LocalReportsCompanion _reportCompanion(Map<String, Object?> row) =>
      LocalReportsCompanion.insert(
        remoteId: Value(_int(row, 'id')),
        isDeleted: Value(row['is_deleted'] as bool? ?? false),
        updatedAt: _date(row, 'updated_at'),
        payload: jsonEncode(row),
      );

  LocalCustomerUtilityEntriesCompanion _customerEntryCompanion(
    Map<String, Object?> row,
    String userId,
  ) {
    final payload = Map<String, Object?>.from(row)..['user_id'] = userId;
    return LocalCustomerUtilityEntriesCompanion.insert(
      remoteId: _int(row, 'id'),
      userId: userId,
      utility: _string(row, 'utility'),
      periodMonth: _date(row, 'period_month'),
      payload: jsonEncode(payload),
    );
  }

  static Map<String, Object?> _decode(String payload) =>
      Map<String, Object?>.from(jsonDecode(payload) as Map);

  static String _string(Map<String, Object?> row, String key) =>
      row[key] as String;

  static int _int(Map<String, Object?> row, String key) =>
      (row[key] as num).toInt();

  static DateTime _date(Map<String, Object?> row, String key) {
    final value = row[key];
    if (value is DateTime) return value;
    return DateTime.parse(value as String);
  }
}
