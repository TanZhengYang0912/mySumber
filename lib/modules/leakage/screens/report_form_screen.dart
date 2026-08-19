import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../theme/tokens.dart';
import '../../auth/state/auth_state.dart';
import '../models/alert.dart';
import '../models/report.dart';
import '../services/report_presets.dart';
import '../state/app_state.dart';
import 'network_error.dart';

class ReportFormScreen extends StatefulWidget {
  final Alert alert;
  const ReportFormScreen({super.key, required this.alert});

  @override
  State<ReportFormScreen> createState() => _ReportFormScreenState();
}

class _ReportFormScreenState extends State<ReportFormScreen> {
  final _findings = TextEditingController();
  final _action = TextEditingController();
  String? _outcome;

  bool get _isElectricity => widget.alert.isElectricity;
  Color get _primary =>
      _isElectricity ? AppColors.electricityAccent : AppColors.workerPrimary;

  @override
  void dispose() {
    _findings.dispose();
    _action.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final started = DateFormat('d MMM y, HH:mm').format(DateTime.now());

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Investigation Report'),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('ALERT'),
                const SizedBox(height: 4),
                Text(widget.alert.title,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text('${context.read<RoleState>().displayName} · started $started',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('FINDINGS'),
                const SizedBox(height: 8),
                _presetChips(findingsPresets(widget.alert.utility), _findings),
                const SizedBox(height: 10),
                TextField(
                  controller: _findings,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'What did you find on site?',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('ACTION TAKEN'),
                const SizedBox(height: 8),
                _presetChips(actionPresets(widget.alert.utility), _action),
                const SizedBox(height: 10),
                TextField(
                  controller: _action,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'What did you do about it?',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('OUTCOME'),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: _outcomeButton(
                          ReportOutcome.fixed, 'Fixed',
                          Icons.check_circle_outline, AppColors.success)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _outcomeButton(
                          ReportOutcome.notFixed, 'Not Fixed',
                          Icons.cancel_outlined, AppColors.critical)),
                ]),
                const SizedBox(height: 10),
                const Text(
                  'Fixed → Resolved. Not Fixed → returned to queue for follow-up.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _primary,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save Report'),
            onPressed: () => _save(app),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _presetChips(List<String> presets, TextEditingController controller) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: presets
          .map((preset) => ActionChip(
                label: Text(preset, style: const TextStyle(fontSize: 12)),
                onPressed: () => setState(() {
                  controller.text = appendPreset(controller.text, preset);
                }),
                side: const BorderSide(color: AppColors.divider),
                backgroundColor: AppColors.canvas,
              ))
          .toList(),
    );
  }

  Widget _outcomeButton(
      String value, String label, IconData icon, Color color) {
    final selected = _outcome == value;
    return GestureDetector(
      onTap: () => setState(() => _outcome = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? color : AppColors.divider, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: selected ? color : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: selected ? color : AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Future<void> _save(AppState app) async {
    if (_outcome == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Select an outcome before saving.')));
      return;
    }
    final now = DateTime.now();
    final worker = context.read<RoleState>().displayName;
    final report = Report(
      alertId: widget.alert.id!,
      workerName: worker,
      findings: _findings.text.trim(),
      actionTaken: _action.text.trim(),
      outcome: _outcome!,
      createdAt: now,
      updatedAt: now,
    );
    try {
      await app.saveReport(report);
      await app.updateAlertStatus(
        widget.alert.id!,
        _outcome == ReportOutcome.fixed
            ? AlertStatus.resolved
            : AlertStatus.notFixed,
        handledBy: worker,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) showNetworkErrorSnackBar(context);
    }
  }
}
