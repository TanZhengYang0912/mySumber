import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/worker_account.dart';

class WorkerRepository {
  WorkerRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<WorkerAccount>> listWorkers() async {
    final rows = await _client
        .from('profiles')
        .select('id, full_name, email, status')
        .eq('role', 'worker')
        .order('full_name');
    return rows.map((row) => WorkerAccount.fromMap(row)).toList();
  }

  Future<void> manage({
    required String action,
    String? workerId,
    String? fullName,
    String? email,
  }) async {
    final response = await _client.functions.invoke('manage-worker', body: {
      'action': action,
      if (workerId != null) 'workerId': workerId,
      if (fullName != null) 'fullName': fullName,
      if (email != null) 'email': email,
    });
    if (response.status < 200 || response.status >= 300) {
      final data = response.data;
      throw StateError(data is Map ? '${data['error']}' : 'Worker action failed');
    }
  }
}
