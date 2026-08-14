import 'package:flutter/material.dart';

import '../../../theme/tokens.dart';
import '../services/equipment_import.dart';

class EquipmentImportPreviewDialog extends StatelessWidget {
  final String fileName;
  final EquipmentImportResult result;
  final Set<String> existingAssetTags;

  const EquipmentImportPreviewDialog({
    super.key,
    required this.fileName,
    required this.result,
    this.existingAssetTags = const <String>{},
  });

  @override
  Widget build(BuildContext context) {
    final issueRows = result.issues.map((issue) => issue.sourceRow).toSet();
    final previewHeight = (MediaQuery.sizeOf(context).height * .42)
        .clamp(220.0, 420.0)
        .toDouble();

    return AlertDialog(
      title: const Text('Review equipment import'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                fileName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SummaryChip(
                    label: 'Valid ${result.rows.length}',
                    color: AppColors.success,
                    surface: AppColors.successSurface,
                  ),
                  _SummaryChip(
                    label: 'New ${result.newCount}',
                    color: AppColors.success,
                    surface: AppColors.successSurface,
                  ),
                  _SummaryChip(
                    label: 'Updates ${result.updateCount}',
                    color: AppColors.warning,
                    surface: AppColors.warningSurface,
                  ),
                  if (issueRows.isNotEmpty)
                    _SummaryChip(
                      label: 'Skipped ${issueRows.length}',
                      color: AppColors.critical,
                      surface: AppColors.criticalSurface,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'What will be imported',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              if (result.rows.isEmpty)
                const Text('No valid equipment rows can be imported.')
              else
                SizedBox(
                  height: previewHeight,
                  child: ListView.separated(
                    itemCount: result.rows.length,
                    itemBuilder: (context, index) => _ImportRowCard(
                      row: result.rows[index],
                      isUpdate: existingAssetTags.contains(
                        result.rows[index].assetTag.toUpperCase(),
                      ),
                    ),
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                  ),
                ),
              if (issueRows.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Rows that will be skipped',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.critical,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                ...result.issues.take(8).map(
                      (issue) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          'Row ${issue.sourceRow} · ${issue.column}: ${issue.message}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                if (result.issues.length > 8)
                  Text('+ ${result.issues.length - 8} more issue(s).'),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.adminPrimary,
          ),
          onPressed: result.rows.isEmpty
              ? null
              : () => Navigator.of(context).pop(true),
          child: Text('Confirm import (${result.rows.length})'),
        ),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color surface;

  const _SummaryChip({
    required this.label,
    required this.color,
    required this.surface,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _ImportRowCard extends StatelessWidget {
  final EquipmentImportRow row;
  final bool isUpdate;

  const _ImportRowCard({required this.row, required this.isUpdate});

  @override
  Widget build(BuildContext context) {
    final accent = isUpdate ? AppColors.warning : AppColors.success;
    final surface = isUpdate
        ? AppColors.warningSurface
        : AppColors.successSurface;
    final ip = row.ipAddress == null
        ? _ipAssignmentLabel(row.ipAssignment)
        : '${_ipAssignmentLabel(row.ipAssignment)} · ${row.ipAddress}';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  row.assetTag,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              _SummaryChip(
                label: isUpdate ? 'Update' : 'New',
                color: accent,
                surface: surface,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${row.equipmentType} · ${row.utilityType}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text('${row.facility.name} · ${row.facility.city}, ${row.facility.state}'),
          Text('${row.manufacturer} · ${row.model}'),
          Text('IP: $ip · Firmware: ${row.firmwareVersion}'),
          Text('Status: ${row.status}'),
        ],
      ),
    );
  }
}

String _ipAssignmentLabel(IpAssignment assignment) {
  switch (assignment) {
    case IpAssignment.staticIp:
      return 'Static';
    case IpAssignment.dhcp:
      return 'DHCP';
    case IpAssignment.notAssigned:
      return 'Not assigned';
  }
}
