import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/filter_controls.dart';
import '../../../theme/page_header.dart';
import '../../../theme/tokens.dart';
import '../../auth/state/auth_state.dart';
import '../models/alert.dart';
import '../models/report.dart';
import '../state/app_state.dart';
import 'report_view_screen.dart';
import 'style.dart';

/// The Worker's report history, covering both Water and Electricity — one
/// list with a Utility filter, same shape as Admin's Oversight Reports tab.
class ReportHistoryScreen extends StatefulWidget {
  const ReportHistoryScreen({super.key});

  @override
  State<ReportHistoryScreen> createState() => _ReportHistoryScreenState();
}

class _ReportHistoryScreenState extends State<ReportHistoryScreen> {
  final _search = TextEditingController();
  String? _state;
  String? _outcome;
  Utility? _utility;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final alertById = {
      for (final a in app.alerts)
        if (a.id != null) a.id!: a,
    };
    final query = _search.text.trim().toLowerCase();

    bool matchesQuery(Report r) {
      if (query.isEmpty) return true;
      final alert = alertById[r.alertId];
      final state = alert?.state.toLowerCase() ?? '';
      return state.contains(query) ||
          r.findings.toLowerCase().contains(query) ||
          r.actionTaken.toLowerCase().contains(query);
    }

    List<Report> excluding({bool state = true, bool outcome = true, bool utility = true}) {
      return app.reportsFiltered(
        state: state ? _state : null,
        outcome: outcome ? _outcome : null,
        utility: utility ? _utility : null,
      ).where(matchesQuery).toList();
    }

    final reports = excluding();
    final states = app.alerts.map((a) => a.state).toSet().toList()..sort();
    final stateCounts =
        countBy(excluding(state: false), (r) => alertById[r.alertId]?.state ?? '');
    final outcomeCounts = countBy(excluding(outcome: false), (r) => r.outcome);
    final utilityCounts = countBy(
        excluding(utility: false),
        (r) => alertById[r.alertId]?.utility == Utility.electricity
            ? 'electricity'
            : 'water');

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          PageHeader(
            title: 'Report History',
            color: AppColors.workerPrimary,
            brand: 'mySumber · WORKER',
            icon: Icons.description_outlined,
            onLogout: () => context.read<RoleState>().logout(),
          ),
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              children: [
                FilterSearchField(
                  controller: _search,
                  hint: 'Search location or alert',
                  accent: AppColors.workerPrimary,
                  onChanged: (_) => setState(() {}),
                  onClear: () => setState(_search.clear),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilterDropdown(
                        value: _state,
                        allLabel: 'All States',
                        options: states,
                        counts: stateCounts,
                        onChanged: (v) => setState(() => _state = v),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilterDropdown(
                        value: _outcome,
                        allLabel: 'All Outcomes',
                        options: const [ReportOutcome.fixed, ReportOutcome.notFixed],
                        labelFor: ReportOutcome.label,
                        counts: outcomeCounts,
                        onChanged: (v) => setState(() => _outcome = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                UtilityChips(
                  color: AppColors.workerPrimary,
                  selected: _utility,
                  allCount: utilityCounts.values.fold<int>(0, (a, b) => a + b),
                  waterCount: utilityCounts['water'] ?? 0,
                  electricityCount: utilityCounts['electricity'] ?? 0,
                  onChanged: (u) => setState(() => _utility = u),
                ),
              ],
            ),
          ),
          Expanded(
            child: reports.isEmpty
                ? const Center(
                    child: Text('No reports match these filters.',
                        style: TextStyle(color: AppColors.textSecondary)))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                    itemCount: reports.length,
                    itemBuilder: (context, index) {
                      final report = reports[index];
                      final alert = alertById[report.alertId];
                      return ReportCard(
                        report: report,
                        locationLabel: alert?.title ?? 'Alert #${report.alertId}',
                        utility: alert?.utility,
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => ReportViewScreen(report: report))),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
