import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

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
    error is http.ClientException;
