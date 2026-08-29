import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/tokens.dart';
import '../../leakage/screens/alert_detail_content.dart';
import '../../leakage/screens/style.dart';
import '../../leakage/state/app_state.dart';

/// Admin's view of one alert: full evidence, AI analysis, and linked
/// investigation reports. Opened from both Oversight's Alert Queue and the
/// Anomalies review queue.
///
/// For an alert still awaiting review it also carries Approve / Fault
/// controls; for anything already in the worker queue it stays read-only,
/// because Admin cannot investigate, write a report, or resolve an alert.
class AdminAlertDetailScreen extends StatefulWidget {
  final int alertId;
  const AdminAlertDetailScreen({super.key, required this.alertId});

  @override
  State<AdminAlertDetailScreen> createState() => _AdminAlertDetailScreenState();
}

class _AdminAlertDetailScreenState extends State<AdminAlertDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final match = app.alerts.where((alert) => alert.id == widget.alertId);
    if (match.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Alert'),
          backgroundColor: AppColors.adminPrimary,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('This alert is no longer available.')),
      );
    }

    final alert = match.first;
    final reports = app.reports
        .where((report) => report.alertId == widget.alertId)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Text(alert.title),
        backgroundColor: AppColors.adminPrimary,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBar: AppState.awaitingDecision(alert)
          ? Material(
              color: AppColors.surface,
              elevation: 8,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: AlertDecisionBar(alert: alert, popOnDecision: true),
                ),
              ),
            )
          : null,
      body: AlertDetailContent(
        app: app,
        alert: alert,
        reports: reports,
        primary: AppColors.adminPrimary,
        canGenerateAi: true,
      ),
    );
  }
}
