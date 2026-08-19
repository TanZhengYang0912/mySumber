import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysumber/core/local_database/cache_status.dart';
import 'package:mysumber/core/local_database/local_database.dart';
import 'package:mysumber/modules/auth/data/account_repository.dart';
import 'package:mysumber/modules/auth/state/auth_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late LocalDatabase database;
  late CacheStatus cacheStatus;
  late _OfflineCapableAccountRemote remote;
  late AccountRepository repository;

  setUp(() {
    database = LocalDatabase.forTesting(NativeDatabase.memory());
    cacheStatus = CacheStatus();
    remote = _OfflineCapableAccountRemote();
    repository = AccountRepository.withRemote(
      remote: remote,
      database: database,
      cacheStatus: cacheStatus,
    );
  });

  tearDown(() => database.close());

  test('valid restored session uses cached profile during offline cold start',
      () async {
    await repository.currentProfile('user-a');
    remote.offline = true;
    final roleState = RoleState(
      accountRepository: repository,
      currentSession: () => _session(
        userId: 'user-a',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      ),
      authStateChanges: const Stream<AuthState>.empty(),
    );
    addTearDown(roleState.dispose);

    await roleState.checkExistingSession();

    expect(roleState.isLoggedIn, isTrue);
    expect(roleState.userRole, 'admin');
    expect(roleState.errorMessage, isNull);
    expect(cacheStatus.isOffline, isTrue);
  });

  test('expired session cannot unlock a cached profile', () async {
    await repository.currentProfile('user-a');
    remote.offline = true;
    final roleState = RoleState(
      accountRepository: repository,
      currentSession: () => _session(
        userId: 'user-a',
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      authStateChanges: const Stream<AuthState>.empty(),
    );
    addTearDown(roleState.dispose);

    await roleState.checkExistingSession();

    expect(roleState.isLoggedIn, isFalse);
    expect(cacheStatus.isOffline, isFalse);
  });

  test('missing session cannot unlock a cached profile', () async {
    await repository.currentProfile('user-a');
    remote.offline = true;
    final roleState = RoleState(
      accountRepository: repository,
      currentSession: () => null,
      authStateChanges: const Stream<AuthState>.empty(),
    );
    addTearDown(roleState.dispose);

    await roleState.checkExistingSession();

    expect(roleState.isLoggedIn, isFalse);
    expect(cacheStatus.isOffline, isFalse);
  });
}

Session _session({
  required String userId,
  required DateTime expiresAt,
}) {
  final header = base64Url.encode(utf8.encode('{"alg":"none"}'));
  final payload = base64Url.encode(
    utf8.encode('{"exp":${expiresAt.millisecondsSinceEpoch ~/ 1000}}'),
  );
  return Session(
    accessToken: '$header.$payload.signature',
    tokenType: 'bearer',
    user: User(
      id: userId,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      email: '$userId@example.com',
      createdAt: DateTime.utc(2026, 8, 19).toIso8601String(),
    ),
  );
}

class _OfflineCapableAccountRemote implements AccountRemoteStore {
  bool offline = false;

  @override
  Future<Map<String, Object?>?> currentProfile(String userId) async {
    if (offline) throw const SocketException('offline');
    return {
      'id': userId,
      'full_name': 'Admin A',
      'email': '$userId@example.com',
      'role': 'admin',
      'status': 'active',
    };
  }
}
