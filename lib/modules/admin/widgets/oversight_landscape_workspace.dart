import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../theme/tokens.dart';
import '../../leakage/models/alert.dart';
import '../../leakage/screens/style.dart';
import 'admin_page_header.dart';

class OversightLandscapeWorkspace extends StatelessWidget {
  const OversightLandscapeWorkspace({
    super.key,
    required this.sectionIndex,
    required this.pendingCount,
    required this.queueLabel,
    required this.alerts,
    required this.alertController,
    required this.filterMenu,
    required this.onSectionChanged,
    required this.onAlertTap,
    required this.onClearFilters,
    required this.onReportState,
    required this.onLogout,
    required this.reportsBody,
  });

  final int sectionIndex;
  final int pendingCount;
  final String queueLabel;
  final List<Alert> alerts;
  final ScrollController alertController;
  final Widget filterMenu;
  final ValueChanged<int> onSectionChanged;
  final ValueChanged<Alert> onAlertTap;
  final VoidCallback onClearFilters;
  final VoidCallback onReportState;
  final VoidCallback onLogout;
  final Widget reportsBody;

  @override
  Widget build(BuildContext context) {
    final showingAlerts = sectionIndex == 0;
    return Column(
      children: [
        _CompactTopBar(
          pendingCount: pendingCount,
          filterMenu: filterMenu,
          showReportState: showingAlerts,
          onReportState: onReportState,
          onLogout: onLogout,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            adminLandscapeHorizontalInset,
            6,
            adminLandscapeHorizontalInset,
            0,
          ),
          child: _SectionSegmentedControl(
            selectedIndex: sectionIndex,
            onChanged: onSectionChanged,
          ),
        ),
        Expanded(
          child: showingAlerts
              ? _AlertQueue(
                  queueLabel: queueLabel,
                  alerts: alerts,
                  controller: alertController,
                  onTap: onAlertTap,
                  onClearFilters: onClearFilters,
                )
              : reportsBody,
        ),
      ],
    );
  }
}

class _CompactTopBar extends StatelessWidget {
  const _CompactTopBar({
    required this.pendingCount,
    required this.filterMenu,
    required this.showReportState,
    required this.onReportState,
    required this.onLogout,
  });

  final int pendingCount;
  final Widget filterMenu;
  final bool showReportState;
  final VoidCallback onReportState;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) => AdminPageHeader(
        title: 'Oversight',
        icon: Icons.shield_outlined,
        compact: true,
        onLogout: onLogout,
        titleAccessory: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            '$pendingCount pending',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        action: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showReportState)
              AdminHeaderIconButton(
                tooltip: 'Report State',
                onPressed: onReportState,
                icon: Icons.add_alert_outlined,
              ),
            if (showReportState) const SizedBox(width: 8),
            filterMenu,
          ],
        ),
      );
}

class _SectionSegmentedControl extends StatelessWidget {
  const _SectionSegmentedControl({
    required this.selectedIndex,
    required this.onChanged,
  });

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => SegmentedButton<int>(
        segments: const [
          ButtonSegment(value: 0, label: Text('Alerts')),
          ButtonSegment(value: 1, label: Text('Reports')),
        ],
        selected: {selectedIndex},
        showSelectedIcon: false,
        style: const ButtonStyle(
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
        onSelectionChanged: (selection) => onChanged(selection.first),
      );
}

class _AlertQueue extends StatelessWidget {
  const _AlertQueue({
    required this.queueLabel,
    required this.alerts,
    required this.controller,
    required this.onTap,
    required this.onClearFilters,
  });

  final String queueLabel;
  final List<Alert> alerts;
  final ScrollController controller;
  final ValueChanged<Alert> onTap;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.filter_alt_off_outlined,
                color: AppColors.textTertiary),
            const SizedBox(height: 8),
            const Text(
              'No alerts match these filters.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            TextButton(
              onPressed: onClearFilters,
              child: const Text('Clear filters'),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            adminLandscapeHorizontalInset,
            10,
            adminLandscapeHorizontalInset,
            6,
          ),
          child: Text(
            queueLabel,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            key: const PageStorageKey('oversight-phone-landscape-alerts'),
            controller: controller,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            itemCount: alerts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) => _AlertRow(
              alert: alerts[index],
              onTap: () => onTap(alerts[index]),
            ),
          ),
        ),
      ],
    );
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({required this.alert, required this.onTap});

  final Alert alert;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isWater = alert.utility == Utility.water;
    final utilityLabel = isWater ? 'Water' : 'Electricity';
    final date = DateFormat('d MMM').format(alert.detectedAt);
    final severity = severityColor(alert.severity);

    return SizedBox(
      height: 68,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Row(
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: severity,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(12),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        alert.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$utilityLabel · ${alert.signature} · $date',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: severity.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  Severity.label(alert.severity).replaceFirst(' Severity', ''),
                  style: TextStyle(
                    color: severity,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
