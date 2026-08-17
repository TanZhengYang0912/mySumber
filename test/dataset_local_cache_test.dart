import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysumber/core/local_database/cache_status.dart';
import 'package:mysumber/core/local_database/local_database.dart';
import 'package:mysumber/modules/dataset/data/dataset_repository.dart';
import 'package:mysumber/modules/dataset/models/models.dart';

void main() {
  late LocalDatabase database;
  late CacheStatus cacheStatus;
  late _FakeDatasetRemote remote;
  late DatasetRepository repository;

  setUp(() {
    database = LocalDatabase.forTesting(NativeDatabase.memory());
    cacheStatus = CacheStatus();
    remote = _FakeDatasetRemote();
    repository = DatasetRepository(
      remote: remote,
      database: database,
      cacheStatus: cacheStatus,
    );
  });

  tearDown(() => database.close());

  test('successful equipment fetch stores the Supabase snapshot', () async {
    remote.nodes = [_node('node-1', 'Pump A').toMap()];

    final result = await repository.fetchNodes();

    expect(result.single.nodeName, 'Pump A');
    expect((await database.equipmentNodes()).single['node_id'], 'node-1');
    expect(cacheStatus.isOffline, isFalse);
  });

  test('network failure returns the persisted equipment snapshot', () async {
    remote.nodes = [_node('node-1', 'Pump A').toMap()];
    await repository.fetchNodes();
    remote.offline = true;

    final result = await repository.fetchNodes();

    expect(result.single.nodeName, 'Pump A');
    expect(cacheStatus.isOffline, isTrue);
  });

  test('log refresh replaces only the selected equipment scope', () async {
    remote.logs['node-1'] = [_log('log-1', 'node-1', 10).toMap()];
    remote.logs['node-2'] = [_log('log-2', 'node-2', 20).toMap()];
    await repository.fetchLogsForNode('node-1');
    await repository.fetchLogsForNode('node-2');

    remote.logs['node-1'] = [_log('log-3', 'node-1', 11).toMap()];
    await repository.fetchLogsForNode('node-1');

    expect((await database.equipmentLogs('node-1')).single['log_id'], 'log-3');
    expect((await database.equipmentLogs('node-2')).single['log_id'], 'log-2');
  });

  test('failed remote upsert does not change the local snapshot', () async {
    remote.nodes = [_node('node-1', 'Original').toMap()];
    await repository.fetchNodes();
    remote.offline = true;

    await expectLater(
      repository.upsertNode(_node('node-1', 'Changed')),
      throwsA(isA<SocketException>()),
    );

    expect((await database.equipmentNodes()).single['node_name'], 'Original');
  });
}

EquipmentNode _node(String id, String name) => EquipmentNode(
      nodeId: id,
      assetTag: 'TEST-${id.toUpperCase()}',
      nodeName: name,
      utilityType: 'Water',
      status: 'Active',
    );

UtilityLog _log(String id, String nodeId, double value) => UtilityLog(
      logId: id,
      nodeId: nodeId,
      timestamp: DateTime.utc(2026, 8, value.toInt()),
      usageValue: value,
    );

class _FakeDatasetRemote implements DatasetRemoteStore {
  bool offline = false;
  List<Map<String, Object?>> nodes = [];
  final Map<String, List<Map<String, Object?>>> logs = {};

  void _checkOnline() {
    if (offline) throw const SocketException('offline');
  }

  @override
  Future<List<Map<String, Object?>>> fetchNodes() async {
    _checkOnline();
    return nodes;
  }

  @override
  Future<List<Map<String, Object?>>> fetchLogsForNode(String nodeId) async {
    _checkOnline();
    return logs[nodeId] ?? [];
  }

  @override
  Future<bool> hasEquipmentNodes() async {
    _checkOnline();
    return nodes.isNotEmpty;
  }

  @override
  Future<bool> hasLogsForNode(String nodeId) async {
    _checkOnline();
    return logs[nodeId]?.isNotEmpty ?? false;
  }

  @override
  Future<void> deleteNode(String nodeId) async {
    _checkOnline();
    nodes.removeWhere((row) => row['node_id'] == nodeId);
  }

  @override
  Future<void> upsertNodes(List<Map<String, Object?>> rows) async {
    _checkOnline();
    for (final row in rows) {
      nodes.removeWhere((item) => item['node_id'] == row['node_id']);
      nodes.add(row);
    }
  }

  @override
  Future<void> upsertLogs(List<Map<String, Object?>> rows) async {
    _checkOnline();
    for (final row in rows) {
      final nodeId = row['node_id'] as String;
      logs.putIfAbsent(nodeId, () => []).add(row);
    }
  }
}
