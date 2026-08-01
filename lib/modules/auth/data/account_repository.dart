import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/account_profile.dart';

class AccountRepository {
  AccountRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<AccountProfile?> currentProfile(String userId) async {
    final row = await _client
        .from('profiles')
        .select('id, full_name, email, role, status')
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return null;
    return AccountProfile.fromMap(row);
  }
}
