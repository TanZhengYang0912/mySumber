import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mysumber/core/local_database/cache_status.dart';
import 'package:mysumber/core/local_database/remote_fallback.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('best-effort cache writes do not hide a successful remote result',
      () async {
    var continued = false;

    await cacheBestEffort('test', () async {
      throw StateError('local database unavailable');
    });
    continued = true;

    expect(continued, isTrue);
  });

  test('network failure returns cache and marks offline', () async {
    final status = CacheStatus();
    final syncedAt = DateTime.utc(2026, 8, 18, 4);

    final result = await remoteFirst<List<int>>(
      remote: () => throw const SocketException('offline'),
      local: () async => [1, 2],
      hasLocalData: (rows) => rows.isNotEmpty,
      lastSync: () async => syncedAt,
      status: status,
    );

    expect(result, [1, 2]);
    expect(status.isOffline, isTrue);
    expect(status.lastSuccessfulSync, syncedAt);
  });

  test('Supabase service failure returns cache', () async {
    final status = CacheStatus();

    final result = await remoteFirst<List<int>>(
      remote: () => throw const PostgrestException(
        message: 'Service unavailable',
        code: '503',
      ),
      local: () async => [4],
      hasLocalData: (rows) => rows.isNotEmpty,
      status: status,
    );

    expect(result, [4]);
    expect(status.isOffline, isTrue);
  });

  test('Supabase permission failures never use cached data', () async {
    final status = CacheStatus();

    await expectLater(
      remoteFirst<List<int>>(
        remote: () => throw const PostgrestException(
          message: 'Permission denied',
          code: '42501',
        ),
        local: () async => [1],
        hasLocalData: (rows) => rows.isNotEmpty,
        status: status,
      ),
      throwsA(isA<PostgrestException>()),
    );
    expect(status.isOffline, isFalse);
  });

  test('successful remote read marks the app online', () async {
    final status = CacheStatus()..markOffline(DateTime.utc(2026, 8, 17));

    final result = await remoteFirst<List<int>>(
      remote: () async => [3],
      local: () async => [1],
      hasLocalData: (rows) => rows.isNotEmpty,
      status: status,
    );

    expect(result, [3]);
    expect(status.isOffline, isFalse);
    expect(status.lastSuccessfulSync, isNotNull);
  });

  test('authorization failures never use cached data', () async {
    final status = CacheStatus();

    await expectLater(
      remoteFirst<List<int>>(
        remote: () => throw const AuthException('denied'),
        local: () async => [1],
        hasLocalData: (rows) => rows.isNotEmpty,
        status: status,
      ),
      throwsA(isA<AuthException>()),
    );
    expect(status.isOffline, isFalse);
  });

  test('mapping failures are rethrown instead of using cache', () async {
    final status = CacheStatus();

    await expectLater(
      remoteFirst<List<int>>(
        remote: () => throw const FormatException('bad row'),
        local: () async => [1],
        hasLocalData: (rows) => rows.isNotEmpty,
        status: status,
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('empty cache rethrows the original network failure', () async {
    final status = CacheStatus();

    await expectLater(
      remoteFirst<List<int>>(
        remote: () => throw const SocketException('offline'),
        local: () async => [],
        hasLocalData: (rows) => rows.isNotEmpty,
        status: status,
      ),
      throwsA(isA<SocketException>()),
    );
    expect(status.isOffline, isFalse);
  });
}
