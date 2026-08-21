import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/page_header.dart';
import '../../../theme/tokens.dart';
import '../../auth/state/auth_state.dart';
import '../../leakage/models/ai_anomaly_analysis.dart';
import '../../leakage/services/anomaly_ai_service.dart';
import '../models/models.dart';
import '../services/equipment_identity.dart';
import '../services/equipment_import.dart';
import '../services/mall_summary.dart';
import '../state/dataset_state.dart';
import '../widgets/equipment_import_preview_dialog.dart';
import 'equipment_detail_screen.dart';
import 'node_form_screen.dart';

class MallDetailScreen extends StatefulWidget {
  final String facilityName;

  const MallDetailScreen({super.key, required this.facilityName});

  @override
  State<MallDetailScreen> createState() => _MallDetailScreenState();
}

class _MallDetailScreenState extends State<MallDetailScreen> {
  AiAnomalyAnalysis? _suggestion;
  bool _isGeneratingSuggestion = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DatasetState>();
    final summaries = buildMallSummaries(
      state.nodes,
      state.latestUsageByNode,
      state.latestUsageAtByNode,
    );
    final mall =
        summaries.where((item) => item.name == widget.facilityName).firstOrNull;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: mall == null
          ? Column(children: [
              PageHeader(
                title: 'Mall',
                icon: Icons.location_city_outlined,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                onLogout: () => context.read<RoleState>().logout(),
              ),
              const Expanded(
                child: Center(child: Text('This mall is no longer available.')),
              ),
            ])
          : Column(
              children: [
                PageHeader(
                  title: mall.name,
                  icon: Icons.location_city_outlined,
                  leading: IconButton(
                    tooltip: 'Back to Mall',
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  onLogout: () => context.read<RoleState>().logout(),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    children: [
                      _overview(mall),
                      const SizedBox(height: 18),
                      _sectionTitle('AI maintenance suggestion'),
                      const SizedBox(height: 8),
                      _aiSuggestionCard(mall),
                      const SizedBox(height: 18),
                      _sectionTitle('Equipment (${mall.nodes.length})'),
                      const SizedBox(height: 8),
                      ...mall.nodes.map((node) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _equipmentRow(state, node),
                          )),
                      const SizedBox(height: 10),
                      _sectionTitle('Manage equipment'),
                      const SizedBox(height: 8),
                      _manageCard(mall),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _sectionTitle(String value) => Text(
        value,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w800,
          fontSize: 16,
        ),
      );

  Widget _overview(MallSummary mall) => AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              mall.city == null ? mall.state : '${mall.city}, ${mall.state}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Row(children: [
              if (mall.hasWater)
                Expanded(
                  child: _usageTile(
                    label: 'Water',
                    value: mall.waterUsage,
                    unit: 'm³',
                    status: mall.waterStatus,
                    color: AppColors.waterAccent,
                  ),
                ),
              if (mall.hasWater && mall.hasElectricity)
                const SizedBox(width: 10),
              if (mall.hasElectricity)
                Expanded(
                  child: _usageTile(
                    label: 'Electricity',
                    value: mall.electricityUsage,
                    unit: 'kWh',
                    status: mall.electricityStatus,
                    color: AppColors.electricityAccent,
                  ),
                ),
            ]),
            if (mall.attentionCount > 0) ...[
              const SizedBox(height: 12),
              Pill('${mall.attentionCount} equipment need attention',
                  color: AppColors.critical, outlined: true),
            ],
          ],
        ),
      );

  Widget _usageTile({
    required String label,
    required double value,
    required String unit,
    required String status,
    required Color color,
  }) =>
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 4),
            Text('${value.toStringAsFixed(1)} $unit',
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 6),
            Pill(status, color: _statusColor(status), outlined: true),
          ],
        ),
      );

  Widget _aiSuggestionCard(MallSummary mall) => AppCard(
        child: _isGeneratingSuggestion
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator()),
              )
            : _suggestion == null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Generate a mock maintenance suggestion from this mall’s '
                        'current equipment and usage roll-up.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () => _generateSuggestion(mall),
                        icon: const Icon(Icons.auto_awesome_outlined),
                        label: const Text('Generate suggestion'),
                        style: FilledButton.styleFrom(
                            backgroundColor: AppColors.adminPrimary),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_suggestion!.summary,
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              height: 1.35)),
                      const SizedBox(height: 10),
                      if (_suggestion!.possibleCause != null)
                        _analysisLine(
                            'Possible cause', _suggestion!.possibleCause!),
                      if (_suggestion!.severityAssessment != null)
                        _analysisLine(
                            'Severity', _suggestion!.severityAssessment!),
                      _analysisLine(
                          'Recommendation', _suggestion!.recommendation),
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: () => _generateSuggestion(mall),
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Generate again'),
                      ),
                    ],
                  ),
      );

  Widget _analysisLine(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: RichText(
          text: TextSpan(
            style: const TextStyle(color: AppColors.textSecondary, height: 1.3),
            children: [
              TextSpan(
                  text: '$label: ',
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700)),
              TextSpan(text: value),
            ],
          ),
        ),
      );

  Future<void> _generateSuggestion(MallSummary mall) async {
    setState(() => _isGeneratingSuggestion = true);
    final equipment = mall.nodes
        .map((node) => '${node.nodeName} (${node.utilityType}, ${node.status})')
        .join(', ');
    try {
      final suggestion = await AnomalyAiService().previewMall({
        'state': mall.state,
        'facility_name': mall.name,
        'facility_city': mall.city,
        'equipment_name': equipment,
        'alert_type': 'mall_usage_review',
        'signature': 'Mall usage roll-up',
        'severity': mall.attentionCount > 0 ? 'medium' : 'low',
        'utility_type': 'electricity',
        'explanation':
            'Mock monitoring totals: water ${mall.waterUsage.toStringAsFixed(1)} m³ '
                '(${mall.waterStatus}); electricity ${mall.electricityUsage.toStringAsFixed(1)} '
                'kWh (${mall.electricityStatus}). Equipment: $equipment',
      });
      if (mounted) setState(() => _suggestion = suggestion);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('AI suggestion is unavailable. Please try again.'),
          backgroundColor: AppColors.critical,
        ));
      }
    } finally {
      if (mounted) setState(() => _isGeneratingSuggestion = false);
    }
  }

  Widget _equipmentRow(DatasetState state, EquipmentNode node) => AppCard(
        onTap: () => _openEquipmentDetail(state, node),
        child: Row(children: [
          Icon(
            node.utilityType == 'Water'
                ? Icons.water_drop_outlined
                : Icons.electric_bolt_outlined,
            color: node.utilityType == 'Water'
                ? AppColors.waterAccent
                : AppColors.electricityAccent,
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(equipmentDisplayName(node),
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text('${node.equipmentType} · ${node.utilityType}',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
            ]),
          ),
          Pill(node.status, color: _statusColor(node.status), outlined: true),
          IconButton(
            tooltip: 'Edit equipment',
            onPressed: () => _openNodeForm(node: node),
            icon: const Icon(Icons.edit_outlined, size: 20),
          ),
          IconButton(
            tooltip: 'Delete equipment',
            color: AppColors.critical,
            onPressed: node.nodeId == null ? null : () => _deleteNode(node),
            icon: const Icon(Icons.delete_outline, size: 20),
          ),
        ]),
      );

  Widget _manageCard(MallSummary mall) => AppCard(
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: () => _openNodeForm(),
              icon: const Icon(Icons.add),
              label: const Text('Add equipment'),
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.adminPrimary),
            ),
            OutlinedButton.icon(
              onPressed: _importData,
              icon: const Icon(Icons.upload_outlined),
              label: const Text('Import CSV'),
            ),
          ],
        ),
      );

  Future<void> _openEquipmentDetail(
      DatasetState state, EquipmentNode node) async {
    await state.selectNode(node);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const EquipmentDetailScreen()),
    );
  }

  Future<void> _openNodeForm({EquipmentNode? node}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => NodeFormScreen(
          node: node,
          initialFacilityName: node == null ? widget.facilityName : null,
        ),
      ),
    );
    if (!mounted || saved != true) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(node == null ? 'Equipment added.' : 'Equipment updated.'),
      backgroundColor: AppColors.success,
    ));
  }

  Future<void> _deleteNode(EquipmentNode node) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete equipment'),
        content: Text(
            'Delete "${equipmentDisplayName(node)}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.critical),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || node.nodeId == null || !mounted) return;
    try {
      await context.read<DatasetState>().deleteNode(node.nodeId!);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not delete this equipment.'),
          backgroundColor: AppColors.critical,
        ));
      }
    }
  }

  Future<void> _importData() async {
    final state = context.read<DatasetState>();
    final selection = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (!mounted || selection == null) return;

    late final List<int> bytes;
    try {
      bytes = await selection.readAsBytes();
    } catch (error) {
      _showImportError('Could not read ${selection.name}: $error');
      return;
    }

    late final String csv;
    try {
      csv = utf8.decode(bytes);
    } on FormatException {
      _showImportError('The selected file is not valid UTF-8 CSV.');
      return;
    }

    final result = parseEquipmentCsv(
      csv,
      catalog: state.importCatalog,
      existingAssetTags:
          state.nodes.map((node) => node.assetTag).whereType<String>().toSet(),
    );
    if (!mounted) return;
    final shouldImport = await showDialog<bool>(
      context: context,
      builder: (_) => EquipmentImportPreviewDialog(
        fileName: selection.name,
        result: result,
        existingAssetTags: state.nodes
            .map((node) => node.assetTag)
            .whereType<String>()
            .map((tag) => tag.toUpperCase())
            .toSet(),
      ),
    );
    if (!mounted || shouldImport != true) return;

    try {
      await state.importRows(result.rows);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Imported ${result.rows.length} equipment nodes.'),
        backgroundColor: AppColors.success,
      ));
    } catch (error) {
      _showImportError('Import failed: $error');
    }
  }

  void _showImportError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.critical),
    );
  }
}

Color _statusColor(String status) => switch (status) {
      'Critical' => AppColors.critical,
      'Warning' => AppColors.warning,
      'Maintenance' => AppColors.textSecondary,
      _ => AppColors.success,
    };
