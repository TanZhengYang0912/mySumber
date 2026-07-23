import '../../leakage/models/alert.dart';

class AnomalyReviewQuery {
  final Set<String> statuses;
  final Utility? utility;
  final String? state;
  final String? facilityName;
  final String? equipmentName;

  const AnomalyReviewQuery({
    this.statuses = const {
      AlertStatus.pending,
      AlertStatus.investigating,
      AlertStatus.notFixed,
    },
    this.utility,
    this.state,
    this.facilityName,
    this.equipmentName,
  });
}

class AnomalyReviewFilter {
  static const _severityRank = {
    Severity.high: 3,
    Severity.medium: 2,
    Severity.low: 1,
  };

  static List<Alert> apply(
    Iterable<Alert> alerts,
    AnomalyReviewQuery query,
  ) {
    final result = alerts.where((alert) {
      if (!query.statuses.contains(alert.status)) return false;
      if (query.utility != null && alert.utility != query.utility) return false;
      if (query.state != null && alert.state != query.state) return false;
      if (query.facilityName != null &&
          alert.facilityName != query.facilityName) {
        return false;
      }
      if (query.equipmentName != null &&
          alert.equipmentName != query.equipmentName) {
        return false;
      }
      return true;
    }).toList();

    result.sort((a, b) {
      final byDate = b.detectedAt.compareTo(a.detectedAt);
      if (byDate != 0) return byDate;
      final bySeverity = (_severityRank[b.severity] ?? 0)
          .compareTo(_severityRank[a.severity] ?? 0);
      if (bySeverity != 0) return bySeverity;
      final byState = a.state.compareTo(b.state);
      if (byState != 0) return byState;
      return (a.facilityName ?? '').compareTo(b.facilityName ?? '');
    });
    return result;
  }

  static List<String> states(Iterable<Alert> alerts) => _unique(
        alerts.map((alert) => alert.state),
      );

  static List<String> facilities(
    Iterable<Alert> alerts, {
    String? state,
  }) {
    return _unique(
      alerts
          .where((alert) => state == null || alert.state == state)
          .map((alert) => alert.facilityName)
          .whereType<String>(),
    );
  }

  static List<String> equipment(
    Iterable<Alert> alerts, {
    String? state,
    String? facilityName,
  }) {
    return _unique(
      alerts
          .where((alert) => state == null || alert.state == state)
          .where((alert) =>
              facilityName == null || alert.facilityName == facilityName)
          .map((alert) => alert.equipmentName)
          .whereType<String>(),
    );
  }

  static List<String> _unique(Iterable<String> values) {
    final result = values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
    result.sort();
    return result;
  }
}
