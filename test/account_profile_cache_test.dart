import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysumber/core/local_database/cache_status.dart';
import 'package:mysumber/core/local_database/local_database.dart';
import 'package:mysumber/modules/auth/data/account_repository.dart';
import 'package:mysumber/modules/auth/models/account_profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late LocalDatabase database;
  late CacheStatus cacheStatus;
  late _FakeAccountRemote remote;
  late AccountRepository repository;

  setUp(() {
    database = LocalDatabase.forTesting(NativeDatabase.memory());
    cacheStatus = CacheStatus();
    remote = _FakeAccountRemote();
    repository = AccountRepository.withRemote(
      remote: remote,
      database: database,
      cacheStatus: cacheStatus,
    );
  });

  tearDown(() => database.close());

  test('online profile is cached and restored for the same user offline',
      () async {
    remote.profileRow = _profileRow('user-a', role: 'admin');
    expect((await repository.currentProfile('user-a'))?.role, 'admin');
    remote.error = const SocketException('offline');

    final cached = await repository.currentProfile('user-a');

    expect(cached?.id, 'user-a');
    expect(cached?.role, 'admin');
    expect(cacheStatus.isOffline, isTrue);
  });

  test('one user cannot restore another users cached profile', () async {
    remote.profileRow = _profileRow('user-a', role: 'admin');
    await repository.currentProfile('user-a');
    remote.error = const SocketException('offline');

    await expectLater(
      repository.currentProfile('user-b'),
      throwsA(isA<SocketException>()),
    );
  });

  test('authorization and permission failures never use cached roles',
      () async {
    remote.profileRow = _profileRow('user-a', role: 'admin');
    await repository.currentProfile('user-a');

    remote.error = const AuthException('denied');
    await expectLater(
      repository.currentProfile('user-a'),
      throwsA(isA<AuthException>()),
    );

    remote.error = const PostgrestException(
      message: 'permission denied',
      code: '42501',
    );
    await expectLater(
      repository.currentProfile('user-a'),
      throwsA(isA<PostgrestException>()),
    );
  });

  test('malformed remote profile never falls back to a cached role', () async {
    remote.profileRow = _profileRow('user-a', role: 'admin');
    await repository.currentProfile('user-a');
    remote.profileRow = {
      ..._profileRow('user-a', role: 'admin'),
      'role': 99,
    };

    await expectLater(
      repository.currentProfile('user-a'),
      throwsA(anyOf(isA<TypeError>(), isA<FormatException>())),
    );
  });

  test('successful missing profile removes stale cached authorization',
      () async {
    remote.profileRow = _profileRow('user-a', role: 'admin');
    await repository.currentProfile('user-a');
    remote.profileRow = null;

    expect(await repository.currentProfile('user-a'), isNull);

    remote.error = const SocketException('offline');
    await expectLater(
      repository.currentProfile('user-a'),
      throwsA(isA<SocketException>()),
    );
  });

  test('account profile serialization contains only approved fields', () {
    final profile = AccountProfile.fromMap(_profileRow('user-a'));

    expect(profile.toMap(), {
      'id': 'user-a',
      'full_name': 'User A',
      'email': 'user-a@example.com',
      'role': 'customer',
      'status': 'active',
    });
  });
}

Map<String, Object?> _profileRow(
  String userId, {
  String role = 'customer',
}) =>
    {
      'id': userId,
      'full_name': 'User ${userId.split('-').last.toUpperCase()}',
      'email': '$userId@example.com',
      'role': role,
      'status': 'active',
    };

class _FakeAccountRemote implements AccountRemoteStore {
  Map<String, Object?>? profileRow;
  Object? error;

  @override
  Future<Map<String, Object?>?> currentProfile(String userId) async {
    final failure = error;
    if (failure != null) throw failure;
    final row = profileRow;
    return row == null ? null : Map<String, Object?>.from(row);
  }
}
