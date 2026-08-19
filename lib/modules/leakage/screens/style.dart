import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/alert.dart';

Color severityColor(String severity) {
  switch (severity) {
    case Severity.high:
      return Colors.red.shade600;
    case Severity.medium:
      return Colors.orange.shade700;
    case Severity.low:
      return Colors.teal.shade600;
    default:
      return Colors.blueGrey;
  }
}

Color statusColor(String status) {
  switch (status) {
    case AlertStatus.pending:
      return Colors.blueGrey.shade500;
    case AlertStatus.investigating:
      return Colors.blue.shade600;
    case AlertStatus.resolved:
      return Colors.green.shade600;
    case AlertStatus.notFixed:
      return Colors.red.shade600;
    case AlertStatus.dismissed:
      return Colors.grey;
    case AlertStatus.faults:
      return Colors.deepOrange.shade400;
    default:
      return Colors.blueGrey;
  }
}

/// What kind of anomaly this is, in worker-facing words. Household alerts show
/// their detection signature (Sudden burst, Creeping leak, ...) because the
/// H-### code in the title already says it is a household.
String alertReasonLabel(Alert alert) {
  switch (alert.alertType) {
    case AlertType.nrwHotspot:
      return 'NRW hotspot';
    case AlertType.electricityHotspot:
      return 'Electricity loss';
    case AlertType.electricityTampering:
      return 'Potential tampering';
    default:
      return alert.signature;
  }
}

/// When the work actually closed. Null unless the alert is resolved AND a
/// report exists to date it — alerts carry no resolved_at column, so a status
/// changed by hand has no timestamp to show.
String? resolvedLabel(String status, DateTime? resolvedAt) {
  if (status != AlertStatus.resolved || resolvedAt == null) return null;
  return 'Resolved at ${DateFormat('d MMM y, HH:mm').format(resolvedAt)}';
}

Widget pill(String text, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
    ),
  );
}
