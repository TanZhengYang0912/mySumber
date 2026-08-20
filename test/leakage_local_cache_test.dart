import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysumber/core/local_database/cache_status.dart';
import 'package:mysumber/core/local_database/local_database.dart';
import 'package:mysumber/modules/leakage/data/leakage_repository.dart';
import 'package:mysumber/modules/leakage/models/alert.dart';
import 'package:mysumber/modules/leakage/models/reading.dart';
import 'package:mysumber/modules/leakage/models/report.dart';

void main() {
  late LocalDatabase database;
  late CacheStatus cacheStatus;
  late _FakeLeakageRemote remote;
  late LeakageRepository repository;

  setUp(() {
    database = LocalDatabase.forTesting(NativeDatabase.memory());
    cacheStatus = CacheStatus();
    remote = _FakeLeakageRemote();
    repository = LeakageRepository.withRemote(
      remote: remote,
      database: database,
      cacheStatus: cacheStatus,
    );
  });

  tearDown(() => database.close());

  test('successful alert fetch is available after a network failure', () async {
    remote.alertRows = [_alert().toMap()];
    await repository.alerts();
    remote.offline = true;

    final cached = await repository.alerts();

    expect(cached.single.id, 10);
    expect(cacheStatus.isOffline, isTrue);
  });

  test('alert cache preserves includeDismissed filtering', () async {
    remote.alertRows = [
      _alert().toMap(),
      _alert(id: 11, status: AlertStatus.dismissed).toMap(),
    ];
    await repository.alerts();
    remote.offline = true;

    expect(await repository.alerts(includeDismissed: false), hasLength(1));
  });

  test('filtered alert refresh removes stale visible rows', () async {
    remote.alertRows = [_alert().toMap()];
    await repository.alerts();
    remote.alertRows = [
      _alert(status: AlertStatus.dismissed).toMap(),
    ];

    expect(await repository.alerts(includeDismissed: false), isEmpty);
    expect(await database.alerts(includeDismissed: false), isEmpty);
  });

  test('confirmed reading and report inserts are mirrored locally', () async {
    final readingId = await repository.insertReading(_reading());
    final reportId = await repository.insertReport(_report());

    expect(readingId, 20);
    expect(reportId, 30);
    expect((await database.readings()).single['id'], 20);
    expect((await database.reports()).single['id'], 30);
  });

  test('existing Supabase readings are mirrored as a local snapshot', () async {
    remote.readingRows = [
      {..._reading().toMap(), 'id': 21}
    ];

    final readings = await repository.readings();

    expect(readings.single.id, 21);
    expect((await database.readings()).single['id'], 21);
  });

  test('failed alert update leaves the cached row unchanged', () async {
    remote.alertRows = [_alert().toMap()];
    await repository.alerts();
    remote.offline = true;

    await expectLater(
      repository.updateAlertStatus(10, AlertStatus.resolved),
      throwsA(isA<SocketException>()),
    );

    expect((await database.alertById(10))?['status'], AlertStatus.pending);
  });

  test('reports fall back locally and keep deletion filtering', () async {
    remote.reportRows = [
      _report().copyWithForTest(id: 30, isDeleted: false).toMap(),
      _report().copyWithForTest(id: 31, isDeleted: true).toMap(),
    ];
    await repository.reports(includeDeleted: true);
    remote.offline = true;

    expect(await repository.reports(), hasLength(1));
    expect(await repository.reports(includeDeleted: true), hasLength(2));
  });

  test('filtered report refresh removes stale visible rows', () async {
    remote.reportRows = [
      _report().copyWithForTest(id: 30, isDeleted: false).toMap(),
    ];
    await repository.reports(includeDeleted: true);
    remote.reportRows = [
      _report().copyWithForTest(id: 30, isDeleted: true).toMap(),
    ];

    expect(await repository.reports(), isEmpty);
    expect(await database.reports(), isEmpty);
  });
}

Alert _alert({int id = 10, String status = AlertStatus.pending}) => Alert(
      id: id,
      alertType: AlertType.household,
      householdId: 'H-001',
      state: 'Selangor',
      detectedAt: DateTime.utc(2026, 8, 18),
      signature: LeakSignature.continuousLeak,
      severity: Severity.high,
      explanation: 'Continuous night flow',
      status: status,
    );

Reading _reading() => Reading(
      householdId: 'H-001',
      state: 'Selangor',
      householdSize: 4,
      readingDate: DateTime.utc(2026, 8, 18),
      dayFlowL: 100,
      nightFlowL: 50,
      scenario: 'test',
    );

Report _report() => Report(
      alertId: 10,
      workerName: 'Worker',
      findings: 'Leak found',
      actionTaken: 'Valve repaired',
      outcome: ReportOutcome.fixed,
      createdAt: DateTime.utc(2026, 8, 18),
      updatedAt: DateTime.utc(2026, 8, 18),
    );

extension on Report {
  Report copyWithForTest({required int id, required bool isDeleted}) => Report(
        id: id,
        alertId: alertId,
        workerName: workerName,
        findings: findings,
        actionTaken: actionTaken,
        outcome: outcome,
        createdAt: createdAt,
        updatedAt: updatedAt,
        isDeleted: isDeleted,
      );
}

class _FakeLeakageRemote implements LeakageRemoteStore {
  bool offline = false;
  List<Map<String, Object?>> alertRows = [];
  List<Map<String, Object?>> reportRows = [];
  List<Map<String, Object?>> readingRows = [];

  void _checkOnline() {
    if (offline) throw const SocketException('offline');
  }

  @override
  Future<Map<String, Object?>> insertReading(Map<String, Object?> row) async {
    _checkOnline();
    return {...row, 'id': 20};
  }

  @override
  Future<List<Map<String, Object?>>> readings() async {
    _checkOnline();
    return readingRows;
  }

  @override
  Future<Map<String, Object?>> insertAlert(Map<String, Object?> row) async {
    _checkOnline();
    return {...row, 'id': 10};
  }

  @override
  Future<List<Map<String, Object?>>> alerts(
      {required bool includeDismissed}) async {
    _checkOnline();
    return includeDismissed
        ? alertRows
        : alertRows
            .where((row) => row['status'] != AlertStatus.dismissed)
            .toList();
  }

  @override
  Future<Map<String, Object?>?> alertById(int id) async {
    _checkOnline();
    return alertRows.where((row) => row['id'] == id).firstOrNull;
  }

  @override
  Future<Map<String, Object?>> updateAlertStatus(
    int id,
    String status, {
    String? handledBy,
    String? handledById,
  }) async {
    _checkOnline();
    final row = alertRows.firstWhere((row) => row['id'] == id);
    row['status'] = status;
    row['handled_by'] = handledBy;
    row['handled_by_id'] = handledById;
    return row;
  }

  @override
  Future<Map<String, Object?>> updateAlertLocation({
    required int id,
    String? equipmentNodeId,
    String? facilityName,
    String? facilityCity,
    String? equipmentName,
  }) async {
    _checkOnline();
    final row = alertRows.firstWhere((row) => row['id'] == id);
    row.addAll({
      'equipment_node_id': equipmentNodeId,
      'facility_name': facilityName,
      'facility_city': facilityCity,
      'equipment_name': equipmentName,
    });
    return row;
  }

  @override
  Future<Map<String, Object?>> insertReport(Map<String, Object?> row) async {
    _checkOnline();
    final saved = {...row, 'id': 30};
    reportRows.add(saved);
    return saved;
  }

  @override
  Future<List<Map<String, Object?>>> reports(
      {required bool includeDeleted}) async {
    _checkOnline();
    return includeDeleted
        ? reportRows
        : reportRows.where((row) => row['is_deleted'] != true).toList();
  }

  @override
  Future<Map<String, Object?>> setReportDeleted(int id, bool isDeleted) async {
    _checkOnline();
    final row = reportRows.firstWhere((row) => row['id'] == id);
    row['is_deleted'] = isDeleted;
    return row;
  }
}
