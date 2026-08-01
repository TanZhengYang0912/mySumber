import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../theme/tokens.dart';
import '../../leakage/models/alert.dart';
import '../../leakage/state/app_state.dart';

class MyReportsScreen extends StatelessWidget {
  const MyReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final resolved = context.watch<AppState>().solvedAlerts();

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _header(),
          if (resolved.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 40, 16, 0),
              child: Center(
                child: Text(
                  'No resolved reports yet.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: SectionLabel('RESOLVED REPORTS'),
            ),
            for (final alert in resolved)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _ResolvedReportCard(alert: alert),
              ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.adminPrimary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.description_outlined,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('mySumber · CUSTOMER',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                  SizedBox(height: 2),
                  Text('My Reports',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResolvedReportCard extends StatelessWidget {
  final Alert alert;

  const _ResolvedReportCard({required this.alert});

  @override
  Widget build(BuildContext context) {
    final isWater = alert.utility == Utility.water;
    final accent =
        isWater ? AppColors.waterAccent : AppColors.electricityAccent;
    final typeLabel = isWater ? 'Water Repair' : 'Electricity Repair';
    final date = DateFormat('d MMM yyyy').format(alert.detectedAt);
    final facility = alert.facilityName;
    final equipment = alert.equipmentName;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 72,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        alert.state,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const Pill('Resolved', color: AppColors.success),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$typeLabel · $date',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 6),
                if (facility != null || equipment != null)
                  Text(
                    [facility, equipment]
                        .whereType<String>()
                        .where((value) => value.trim().isNotEmpty)
                        .join(' · '),
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: accent),
                  )
                else
                  Text(
                    _issueLabel(alert),
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: accent),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _issueLabel(Alert alert) {
    switch (alert.alertType) {
      case AlertType.household:
        return 'Household water leak resolved';
      case AlertType.nrwHotspot:
        return 'Water network issue resolved';
      case AlertType.electricityHotspot:
        return 'Electricity distribution issue resolved';
      case AlertType.electricityTampering:
        return 'Electricity irregularity resolved';
      default:
        return 'Issue resolved';
    }
  }
}
