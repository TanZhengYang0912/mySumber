import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/local_database/cache_status.dart';
import '../../../core/local_database/local_database.dart';
import '../../../core/local_database/remote_fallback.dart';
import '../models/account_profile.dart';

abstract class AccountRemoteStore {
  Future<Map<String, Object?>?> currentProfile(String userId);
}

class SupabaseAccountRemoteStore implements AccountRemoteStore {
  const SupabaseAccountRemoteStore(this.client);

  final SupabaseClient client;

  @override
  Future<Map<String, Object?>?> currentProfile(String userId) async {
    final row = await client
        .from('profiles')
        .select('id, full_name, email, role, status')
        .eq('id', userId)
        .maybeSingle();
    return row == null ? null : Map<String, Object?>.from(row);
  }
}

class AccountRepository {
  AccountRepository({SupabaseClient? client})
      : this._(
          remote: SupabaseAccountRemoteStore(
            client ?? Supabase.instance.client,
          ),
        );

  AccountRepository.cached({
    required SupabaseClient client,
    required LocalDatabase database,
    required CacheStatus cacheStatus,
  }) : this._(
          remote: SupabaseAccountRemoteStore(client),
          database: database,
          cacheStatus: cacheStatus,
        );

  AccountRepository.withRemote({
    required AccountRemoteStore remote,
    required LocalDatabase database,
    required CacheStatus cacheStatus,
  }) : this._(
          remote: remote,
          database: database,
          cacheStatus: cacheStatus,
        );

  AccountRepository._({
    required AccountRemoteStore remote,
    LocalDatabase? database,
    CacheStatus? cacheStatus,
  })  : _remote = remote,
        _database = database,
        _cacheStatus = cacheStatus ?? CacheStatus();

  final AccountRemoteStore _remote;
  final LocalDatabase? _database;
  final CacheStatus _cacheStatus;

  Future<AccountProfile?> currentProfile(String userId) async {
    final database = _database;
    if (database == null) {
      final row = await _remote.currentProfile(userId);
      return row == null ? null : AccountProfile.fromMap(row);
    }
    final scope = 'account_profile:$userId';
    return remoteFirst<AccountProfile?>(
      remote: () async {
        final row = await _remote.currentProfile(userId);
        final profile = row == null ? null : AccountProfile.fromMap(row);
        await cacheBestEffort('account profile', () async {
          if (profile == null) {
            await database.deleteAccountProfile(userId);
          } else {
            final syncedAt = DateTime.now();
            await database.upsertAccountProfile(profile.toMap(), syncedAt);
            await database.setLastSync(scope, syncedAt);
          }
        });
        return profile;
      },
      local: () async {
        final row = await database.accountProfile(userId);
        return row == null ? null : AccountProfile.fromMap(row);
      },
      hasLocalData: (profile) => profile != null,
      lastSync: () => database.lastSync(scope),
      status: _cacheStatus,
    );
  }
}
