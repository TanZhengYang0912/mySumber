import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/tokens.dart';
import '../../auth/state/auth_state.dart';
import '../models/alert.dart';
import '../state/app_state.dart';
import 'alert_detail_content.dart';
import 'network_error.dart';
import 'report_form_screen.dart';
import 'style.dart';

/// Worker's view of one approved alert. Its information content is identical
/// to Admin's detail view; only the role-specific workflow action differs.
class AlertDetailScreen extends StatelessWidget {
  final int alertId;
  const AlertDetailScreen({super.key, required this.alertId});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final match = app.alerts.where((alert) => alert.id == alertId);
    if (match.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Alert'),
          backgroundColor: AppColors.workerPrimary,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('This alert is no longer available.')),
      );
    }

    final alert = match.first;
    final reports =
        app.reports.where((report) => report.alertId == alertId).toList();
    const primary = AppColors.workerPrimary;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Text(alert.title),
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBar: _workerBottomBar(context, app, alert, primary),
      body: AlertDetailContent(
        app: app,
        alert: alert,
        reports: reports,
        primary: primary,
        canGenerateAi: false,
      ),
    );
  }

  Widget? _workerBottomBar(
    BuildContext context,
    AppState app,
    Alert alert,
    Color primary,
  ) {
    final action = _workerAction(context, app, alert, primary);
    if (action == null) return null;

    return Material(
      key: const ValueKey('worker-alert-action-panel'),
      color: AppColors.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: action,
        ),
      ),
    );
  }

  Widget? _workerAction(
    BuildContext context,
    AppState app,
    Alert alert,
    Color primary,
  ) {
    if (alert.status == AlertStatus.pending) {
      return _primaryBtn(
        'Start Investigation',
        Icons.play_arrow,
        primary,
        () => _updateStatus(
          context,
          app,
          alert.id!,
          AlertStatus.investigating,
        ),
      );
    }

    if (alert.status == AlertStatus.investigating) {
      final currentUserId = context.read<RoleState>().userId;
      if (alertLockedForUser(alert, currentUserId)) {
        return Row(
          children: [
            const Icon(
              Icons.lock_outline,
              size: 18,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Being investigated by '
                '${app.workerNames[alert.handledById] ?? alert.handledBy} — '
                'only they can submit a report.',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        );
      }

      return _primaryBtn(
        'Write Report',
        Icons.edit_note,
        primary,
        () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ReportFormScreen(alert: alert)),
        ),
      );
    }

    if (alert.status == AlertStatus.notFixed) {
      return _primaryBtn(
        'Re-Investigate',
        Icons.refresh,
        primary,
        () => _updateStatus(
          context,
          app,
          alert.id!,
          AlertStatus.investigating,
        ),
      );
    }

    return null;
  }

  Future<void> _updateStatus(
    BuildContext context,
    AppState app,
    int alertId,
    String status,
  ) async {
    final role = context.read<RoleState>();
    try {
      await app.updateAlertStatus(
        alertId,
        status,
        handledBy: role.displayName,
        handledById: role.userId,
      );
    } catch (_) {
      if (context.mounted) showNetworkErrorSnackBar(context);
    }
  }

  Widget _primaryBtn(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return FilledButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: color,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}
