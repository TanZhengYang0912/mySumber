import '../../leakage/models/alert.dart';
import 'mall_summary.dart';

typedef MallStatusCounts = ({
  int total,
  int active,
  int warning,
  int maintenance,
  int critical,
});

typedef AnomalyCounts = ({
  int toReview,
  int ongoing,
  int resolved,
  int rejected,
});

MallStatusCounts mallStatusCounts(List<MallSummary> malls) {
  int at(String status) =>
      malls.where((mall) => mall.worstStatus == status).length;

  return (
    total: malls.length,
    active: at('Active'),
    warning: at('Warning'),
    maintenance: at('Maintenance'),
    critical: at('Critical'),
  );
}

AnomalyCounts anomalyCounts(List<Alert> alerts) {
  int matching(bool Function(Alert) test) => alerts.where(test).length;

  return (
    toReview: matching((alert) => alert.status == AlertStatus.pendingReview),
    ongoing: matching((alert) => AlertStatus.unresolved.contains(alert.status)),
    resolved: matching((alert) => alert.status == AlertStatus.resolved),
    rejected: matching((alert) =>
        alert.status == AlertStatus.faults ||
        alert.status == AlertStatus.dismissed),
  );
}
