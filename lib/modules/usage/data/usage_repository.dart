import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/local_database/cache_status.dart';
import '../../../core/local_database/local_database.dart';
import '../../../core/local_database/remote_fallback.dart';
import '../models/utility_entry.dart';

abstract class UsageRemoteStore {
  Future<List<Map<String, Object?>>> entriesFor(UtilityType utility);
  Future<Map<String, Object?>> upsertEntry({
    required UtilityType utility,
    required DateTime periodMonth,
    required double value,
  });
}

class SupabaseUsageRemoteStore implements UsageRemoteStore {
  const SupabaseUsageRemoteStore(this.client);

  final SupabaseClient client;

  @override
  Future<List<Map<String, Object?>>> entriesFor(UtilityType utility) async {
    final rows = await client
        .from('customer_utility_entries')
        .select()
        .eq('utility', utility.key)
        .order('period_month', ascending: true);
    return rows.map((row) => Map<String, Object?>.from(row)).toList();
  }

  @override
  Future<Map<String, Object?>> upsertEntry({
    required UtilityType utility,
    required DateTime periodMonth,
    required double value,
  }) async {
    final row = await client
        .from('customer_utility_entries')
        .upsert(
          {
            'utility': utility.key,
            'period_month': periodMonth.toIso8601String().split('T').first,
            'value': value,
          },
          onConflict: 'user_id,utility,period_month',
        )
        .select()
        .single();
    return Map<String, Object?>.from(row);
  }
}

class UsageRepository {
  UsageRepository([SupabaseClient? client])
      : this._(
          remote: SupabaseUsageRemoteStore(
            client ?? Supabase.instance.client,
          ),
          currentUserId: () =>
              (client ?? Supabase.instance.client).auth.currentUser?.id,
        );

  UsageRepository.cached({
    required SupabaseClient client,
    required LocalDatabase database,
    required CacheStatus cacheStatus,
  }) : this._(
          remote: SupabaseUsageRemoteStore(client),
          currentUserId: () => client.auth.currentUser?.id,
          database: database,
          cacheStatus: cacheStatus,
        );

  UsageRepository.withRemote({
    required UsageRemoteStore remote,
    required String? Function() currentUserId,
    required LocalDatabase database,
    required CacheStatus cacheStatus,
  }) : this._(
          remote: remote,
          currentUserId: currentUserId,
          database: database,
          cacheStatus: cacheStatus,
        );

  UsageRepository._({
    required UsageRemoteStore remote,
    required String? Function() currentUserId,
    LocalDatabase? database,
    CacheStatus? cacheStatus,
  })  : _remote = remote,
        _currentUserId = currentUserId,
        _database = database,
        _cacheStatus = cacheStatus ?? CacheStatus();

  final UsageRemoteStore _remote;
  final String? Function() _currentUserId;
  final LocalDatabase? _database;
  final CacheStatus _cacheStatus;

  Future<List<UtilityEntry>> entriesFor(UtilityType utility) async {
    final userId = _requireUserId();
    final database = _database;
    if (database == null) {
      return _entriesFromRows(await _remote.entriesFor(utility));
    }
    final scope = 'customer_usage:$userId:${utility.key}';
    return remoteFirst(
      remote: () async {
        final rows = await _remote.entriesFor(utility);
        await database.replaceCustomerEntries(
          userId: userId,
          utility: utility.key,
          rows: rows,
        );
        await database.setLastSync(scope, DateTime.now());
        return _entriesFromRows(rows);
      },
      local: () async => _entriesFromRows(
        await database.customerEntries(userId, utility.key),
      ),
      hasLocalData: (rows) => rows.isNotEmpty,
      lastSync: () => database.lastSync(scope),
      status: _cacheStatus,
    );
  }

  Future<UtilityEntry> upsertEntry({
    required UtilityType utility,
    required DateTime month,
    required double value,
  }) async {
    final userId = _requireUserId();
    final periodMonth = DateTime(month.year, month.month, 1);
    final row = await _remote.upsertEntry(
      utility: utility,
      periodMonth: periodMonth,
      value: value,
    );
    await _database?.upsertCustomerEntry(userId, row);
    _cacheStatus.markOnline();
    return UtilityEntry.fromMap(row);
  }

  String _requireUserId() {
    final userId = _currentUserId();
    if (userId == null) throw const AuthException('Sign in required');
    return userId;
  }

  List<UtilityEntry> _entriesFromRows(List<Map<String, Object?>> rows) =>
      rows.map(UtilityEntry.fromMap).toList();
}
