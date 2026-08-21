import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../theme/tokens.dart';
import '../services/state_csv_import.dart';

/// What a state CSV contains, shown before the operator confirms. The import
/// is read-only, so confirmation reports the parse result and stores nothing.
class StateCsvPreviewDialog extends StatelessWidget {
  final String fileName;
  final StateCsvResult result;

  const StateCsvPreviewDialog({
    super.key,
    required this.fileName,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final range = result.earliest == null
        ? '—'
        : '${DateFormat('MMM y').format(result.earliest!)} – '
            '${DateFormat('MMM y').format(result.latest!)}';

    return AlertDialog(
      title: Text(result.kind.label),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(fileName,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 14),
            _stat('Rows read', '${result.rows.length}'),
            _stat('States', '${result.stateCount}'),
            _stat('Period', range),
            if (result.errors.isNotEmpty)
              _stat('Skipped rows', '${result.errors.length}',
                  color: AppColors.critical),
            if (result.errors.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('First problems',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
              const SizedBox(height: 4),
              ...result.errors.take(3).map(
                    (error) => Text('• $error',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.critical)),
                  ),
            ],
            const SizedBox(height: 16),
            const Text(
              'Preview only — this reads the file and reports what it found. '
              'No records are stored.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed:
              result.rows.isEmpty ? null : () => Navigator.pop(context, true),
          style:
              FilledButton.styleFrom(backgroundColor: AppColors.adminPrimary),
          child: const Text('Import'),
        ),
      ],
    );
  }

  Widget _stat(String label, String value, {Color? color}) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
            Text(value,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color ?? AppColors.textPrimary)),
          ],
        ),
      );
}
