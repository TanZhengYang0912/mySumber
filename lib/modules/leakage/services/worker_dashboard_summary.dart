import '../models/alert.dart';

/// A read-only summary of the work that matters most to a field worker.
///
/// The summary deliberately consumes the existing alert model so Water and
/// Electricity can share the same dashboard structure without sharing data.
class WorkerDashboardSummary {
  final Utility utility;
  final Alert? priorityAlert;
  final int pendingCount;
  final int investigatingCount;
  final int followUpCount;
  final int resolvedCount;

  const WorkerDashboardSummary({
    required this.utility,
    required this.priorityAlert,
    required this.pendingCount,
    required this.investigatingCount,
    required this.followUpCount,
    required this.resolvedCount,
  });

  int get activeCount => pendingCount + investigatingCount + followUpCount;
}

WorkerDashboardSummary summarizeWorkerDashboard({
  required Iterable<Alert> alerts,
  required Utility utility,
}) {
  final utilityAlerts = alerts.where((alert) => alert.utility == utility);
  final active = utilityAlerts.where((alert) => alert.isUnresolved).toList();

  final priority = [...active]..sort(_comparePriority);

  return WorkerDashboardSummary(
    utility: utility,
    priorityAlert: priority.isEmpty ? null : priority.first,
    pendingCount: utilityAlerts
        .where((alert) => alert.status == AlertStatus.pending)
        .length,
    investigatingCount: utilityAlerts
        .where((alert) => alert.status == AlertStatus.investigating)
        .length,
    followUpCount: utilityAlerts
        .where((alert) => alert.status == AlertStatus.notFixed)
        .length,
    resolvedCount: utilityAlerts
        .where((alert) => alert.status == AlertStatus.resolved)
        .length,
  );
}

int _comparePriority(Alert a, Alert b) {
  final severity =
      _severityRank(b.severity).compareTo(_severityRank(a.severity));
  if (severity != 0) return severity;

  final status = _statusRank(b.status).compareTo(_statusRank(a.status));
  if (status != 0) return status;

  // Older alerts stay ahead of newer alerts so work cannot silently age in
  // the queue when severity and status are equal.
  return a.detectedAt.compareTo(b.detectedAt);
}

int _severityRank(String severity) {
  switch (severity) {
    case Severity.high:
      return 3;
    case Severity.medium:
      return 2;
    case Severity.low:
      return 1;
    default:
      return 0;
  }
}

int _statusRank(String status) {
  switch (status) {
    case AlertStatus.notFixed:
      return 3;
    case AlertStatus.pending:
      return 2;
    case AlertStatus.investigating:
      return 1;
    default:
      return 0;
  }
}
