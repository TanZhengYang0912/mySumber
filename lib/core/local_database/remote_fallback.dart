import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'cache_status.dart';

Future<T> remoteFirst<T>({
  required Future<T> Function() remote,
  required Future<T> Function() local,
  required bool Function(T value) hasLocalData,
  required CacheStatus status,
  Future<DateTime?> Function()? lastSync,
}) async {
  try {
    final value = await remote();
    status.markOnline();
    return value;
  } catch (error, stackTrace) {
    if (!_isConnectivityFailure(error)) {
      Error.throwWithStackTrace(error, stackTrace);
    }

    final cached = await local();
    if (!hasLocalData(cached)) {
      Error.throwWithStackTrace(error, stackTrace);
    }

    status.markOffline(await lastSync?.call());
    return cached;
  }
}

bool _isConnectivityFailure(Object error) =>
    error is SocketException ||
    error is TimeoutException ||
    error is http.ClientException ||
    _isSupabaseServiceFailure(error);

bool _isSupabaseServiceFailure(Object error) {
  if (error is! PostgrestException) return false;
  final code = error.code;
  final statusCode = int.tryParse(code ?? '');
  return (statusCode != null && statusCode >= 500 && statusCode < 600) ||
      (code?.startsWith('PGRST00') ?? false);
}

Future<void> cacheBestEffort(
  String scope,
  Future<void> Function() write,
) async {
  try {
    await write();
  } catch (_) {
    debugPrint('Could not update the local $scope cache.');
  }
}
