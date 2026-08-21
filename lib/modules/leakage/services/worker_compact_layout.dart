import 'package:flutter/material.dart';

import '../models/alert.dart';

/// Worker navigation becomes a rail only on a phone held horizontally.
/// Tablet and portrait layouts keep their existing navigation patterns.
bool usesWorkerPhoneLandscape(Size viewport) {
  return viewport.shortestSide < 600 && viewport.width > viewport.height;
}

/// How many filters are currently narrowing Worker's Alert Queue, for the
/// landscape burger's badge. The queue spells "unfiltered" as the string
/// 'all'; Report History uses null, hence the separate counter below.
int activeAlertFilterCount({
  required String query,
  required String severity,
  required String state,
  required String status,
}) {
  var count = 0;
  if (query.trim().isNotEmpty) count++;
  if (severity != 'all') count++;
  if (state != 'all') count++;
  if (status != 'all') count++;
  return count;
}

/// The Report History equivalent, where an unset dropdown is null rather than
/// the string 'all'.
int activeReportFilterCount({
  required String query,
  String? state,
  String? outcome,
  Utility? utility,
}) {
  var count = 0;
  if (query.trim().isNotEmpty) count++;
  if (state != null) count++;
  if (outcome != null) count++;
  if (utility != null) count++;
  return count;
}
