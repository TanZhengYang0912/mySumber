import 'package:flutter/foundation.dart';

class CacheStatus extends ChangeNotifier {
  bool _isOffline = false;
  DateTime? _lastSuccessfulSync;

  bool get isOffline => _isOffline;
  DateTime? get lastSuccessfulSync => _lastSuccessfulSync;

  void markOnline([DateTime? syncedAt]) {
    _isOffline = false;
    _lastSuccessfulSync = (syncedAt ?? DateTime.now()).toUtc();
    notifyListeners();
  }

  void markOffline([DateTime? lastSync]) {
    _isOffline = true;
    if (lastSync != null) {
      _lastSuccessfulSync = lastSync.toUtc();
    }
    notifyListeners();
  }
}
