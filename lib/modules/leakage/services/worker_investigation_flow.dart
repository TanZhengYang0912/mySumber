import '../models/alert.dart';

/// A newly accepted alert should take the worker to its evidence and actions.
bool shouldOpenAlertDetailsAfterInvestigationStart(String status) =>
    status == AlertStatus.pending;
