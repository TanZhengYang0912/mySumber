import '../../leakage/models/alert.dart';

class AnomalyReviewQuery {
  final Set<String> statuses;
  final bool highSeverityOnly;
  final Utility? utility;
  final String? state;
  final String? facilityName;
  final String? equipmentName;

  const AnomalyReviewQuery({
    this.statuses = const {AlertStatus.pending},
    this.highSeverityOnly = false,
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
  static const _statusRank = {
    AlertStatus.pending: 2,
    AlertStatus.investigating: 1,
    AlertStatus.notFixed: 1,
  };

  static List<Alert> apply(
    Iterable<Alert> alerts,
    AnomalyReviewQuery query,
  ) {
    final result = alerts.where((alert) {
      if (!query.statuses.contains(alert.status)) return false;
      if (query.highSeverityOnly && alert.severity != Severity.high) {
        return false;
      }
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

    result.sort(_compareForReview);
    return result;
  }

  static int _compareForReview(Alert a, Alert b) {
    final bySeverity = (_severityRank[b.severity] ?? 0)
        .compareTo(_severityRank[a.severity] ?? 0);
    if (bySeverity != 0) return bySeverity;
    final byStatus =
        (_statusRank[b.status] ?? 0).compareTo(_statusRank[a.status] ?? 0);
    if (byStatus != 0) return byStatus;
    final byDate = b.detectedAt.compareTo(a.detectedAt);
    if (byDate != 0) return byDate;
    return (a.id ?? -1).compareTo(b.id ?? -1);
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

  static String? normalizeOption(
    String? selected,
    Iterable<String> availableOptions,
  ) {
    if (selected == null || availableOptions.contains(selected)) {
      return selected;
    }
    return null;
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
