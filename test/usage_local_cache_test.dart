import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysumber/core/local_database/cache_status.dart';
import 'package:mysumber/core/local_database/local_database.dart';
import 'package:mysumber/modules/usage/data/usage_repository.dart';
import 'package:mysumber/modules/usage/models/utility_entry.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late LocalDatabase database;
  late CacheStatus cacheStatus;
  late _FakeUsageRemote remote;
  late String? userId;
  late UsageRepository repository;

  setUp(() {
    database = LocalDatabase.forTesting(NativeDatabase.memory());
    cacheStatus = CacheStatus();
    remote = _FakeUsageRemote();
    userId = 'customer-a';
    repository = UsageRepository.withRemote(
      remote: remote,
      currentUserId: () => userId,
      database: database,
      cacheStatus: cacheStatus,
    );
  });

  tearDown(() => database.close());

  test('successful usage fetch is available offline for the same user',
      () async {
    remote.rows = [_entryMap(1, 'water', 12.5)];
    await repository.entriesFor(UtilityType.water);
    remote.offline = true;

    final cached = await repository.entriesFor(UtilityType.water);

    expect(cached.single.value, 12.5);
    expect(cacheStatus.isOffline, isTrue);
  });

  test('one customer cannot read another customer cache', () async {
    remote.rows = [_entryMap(1, 'water', 12.5)];
    await repository.entriesFor(UtilityType.water);
    userId = 'customer-b';
    remote.offline = true;

    await expectLater(
      repository.entriesFor(UtilityType.water),
      throwsA(isA<SocketException>()),
    );
  });

  test('usage cache requires an authenticated user', () async {
    userId = null;

    await expectLater(
      repository.entriesFor(UtilityType.water),
      throwsA(isA<AuthException>()),
    );
  });

  test('confirmed upsert updates only the current user cache', () async {
    final saved = await repository.upsertEntry(
      utility: UtilityType.electricity,
      month: DateTime(2026, 8),
      value: 99,
    );

    expect(saved.value, 99);
    expect(
        await database.customerEntries('customer-b', 'electricity'), isEmpty);
    expect(
      (await database.customerEntries('customer-a', 'electricity'))
          .single['value'],
      99,
    );
  });
}

Map<String, Object?> _entryMap(int id, String utility, double value) => {
      'id': id,
      'utility': utility,
      'period_month': '2026-08-01',
      'value': value,
    };

class _FakeUsageRemote implements UsageRemoteStore {
  bool offline = false;
  List<Map<String, Object?>> rows = [];

  void _checkOnline() {
    if (offline) throw const SocketException('offline');
  }

  @override
  Future<List<Map<String, Object?>>> entriesFor(UtilityType utility) async {
    _checkOnline();
    return rows.where((row) => row['utility'] == utility.key).toList();
  }

  @override
  Future<Map<String, Object?>> upsertEntry({
    required UtilityType utility,
    required DateTime periodMonth,
    required double value,
  }) async {
    _checkOnline();
    final row = _entryMap(8, utility.key, value);
    rows.add(row);
    return row;
  }
}
