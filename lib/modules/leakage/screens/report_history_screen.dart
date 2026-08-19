import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../theme/segmented_chips.dart';
import '../../../theme/tokens.dart';
import '../../auth/state/auth_state.dart';
import '../models/alert.dart';
import '../models/report.dart';
import '../state/app_state.dart';
import 'report_view_screen.dart';

class ReportHistoryScreen extends StatefulWidget {
  final Utility utility;
  const ReportHistoryScreen({super.key, this.utility = Utility.water});

  @override
  State<ReportHistoryScreen> createState() => _ReportHistoryScreenState();
}

class _ReportHistoryScreenState extends State<ReportHistoryScreen> {
  String _filter = 'all';
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final all = app.reportsFor(widget.utility);
    final dateFormat = DateFormat('d MMM y, HH:mm');

    final reports = all.where((r) {
      if (_filter == 'fixed' && !r.isFixed) return false;
      if (_filter == 'notFixed' && r.isFixed) return false;
      if (_searchQuery.isNotEmpty) {
        final alert = app.alerts.where((a) => a.id == r.alertId).firstOrNull;
        final title = (alert?.title ?? '').toLowerCase();
        final findings = r.findings.toLowerCase();
        if (!title.contains(_searchQuery) && !findings.contains(_searchQuery)) {
          return false;
        }
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.workerPrimary,
        foregroundColor: Colors.white,
        leading: const BackButton(),
        titleSpacing: 0,
        title: const Text(
          'mySumber · WORKER',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => context.read<RoleState>().logout(),
            icon: const Icon(Icons.logout, color: Colors.white, size: 16),
            label: const Text('Logout',
                style: TextStyle(color: Colors.white, fontSize: 13)),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(38),
          child: const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              'Report History',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          _searchBar(),
          _filterBar(all),
          Expanded(
            child: reports.isEmpty
                ? const Center(
                    child: Text('No reports match.',
                        style: TextStyle(color: AppColors.textSecondary)))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                    itemCount: reports.length,
                    itemBuilder: (context, index) =>
                        _reportCard(context, app, reports[index], dateFormat),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: TextField(
        controller: _searchCtrl,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search location or description',
          hintStyle:
              const TextStyle(fontSize: 14, color: AppColors.textTertiary),
          prefixIcon:
              const Icon(Icons.search, size: 20, color: AppColors.textTertiary),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close,
                      size: 18, color: AppColors.textTertiary),
                  onPressed: () => _searchCtrl.clear(),
                )
              : null,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          filled: true,
          fillColor: AppColors.canvas,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.divider),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.divider),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColors.workerPrimary),
          ),
        ),
      ),
    );
  }

  Widget _filterBar(List<Report> all) {
    final fixedCount = all.where((r) => r.isFixed).length;
    final notFixedCount = all.where((r) => !r.isFixed).length;

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: SegmentedChipRow(
        spacing: 8,
        children: [
          SegmentedChip(
            label: 'All',
            count: all.length,
            selected: _filter == 'all',
            onTap: () => setState(() => _filter = 'all'),
            color: AppColors.workerPrimary,
          ),
          SegmentedChip(
            label: 'Fixed',
            count: fixedCount,
            selected: _filter == 'fixed',
            onTap: () => setState(() => _filter = 'fixed'),
            color: AppColors.success,
          ),
          SegmentedChip(
            label: 'Not Fixed',
            count: notFixedCount,
            selected: _filter == 'notFixed',
            onTap: () => setState(() => _filter = 'notFixed'),
            color: AppColors.critical,
          ),
        ],
      ),
    );
  }

  Widget _reportCard(BuildContext context, AppState app, Report report,
      DateFormat dateFormat) {
    final matches = app.alerts.where((a) => a.id == report.alertId);
    final alert = matches.isEmpty ? null : matches.first;
    final title = alert?.title ?? 'Alert #${report.alertId}';
    final isFixed = report.isFixed;
    final outcomColor = isFixed ? AppColors.success : AppColors.critical;
    final outcomeLabel = ReportOutcome.label(report.outcome);
    final utilityColor = alert?.isElectricity == true
        ? AppColors.electricityAccent
        : AppColors.workerPrimary;
    final utilityLabel = alert?.isElectricity == true ? 'Electricity' : 'Water';

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ReportViewScreen(report: report))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: outcomColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isFixed
                    ? Icons.check_circle_outline
                    : Icons.warning_amber_rounded,
                color: outcomColor,
                size: 20,
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
                        child: Text(title,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary)),
                      ),
                      const SizedBox(width: 6),
                      Pill(outcomeLabel, color: outcomColor),
                      const SizedBox(width: 6),
                      Pill(
                        utilityLabel,
                        color: utilityColor,
                        icon: alert?.isElectricity == true
                            ? Icons.electric_bolt
                            : Icons.water_drop,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    report.findings.isEmpty ? 'No findings' : report.findings,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${dateFormat.format(report.updatedAt)} · By ${report.workerName}',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textTertiary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
