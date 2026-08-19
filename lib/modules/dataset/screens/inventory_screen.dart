import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/tokens.dart';
import '../../auth/state/auth_state.dart';
import '../../admin/services/admin_tablet_layout.dart';
import '../../../theme/page_header.dart';
import '../../../theme/filter_controls.dart';
import '../../../theme/segmented_chips.dart';
import '../../leakage/models/alert.dart';
import '../../admin/widgets/landscape_filter_menu.dart';
import '../state/dataset_state.dart';
import '../models/models.dart';
import '../services/equipment_import.dart';
import '../services/equipment_identity.dart';
import '../services/inventory_filter.dart';
import 'equipment_detail_screen.dart';
import 'node_form_screen.dart';
import '../widgets/equipment_import_preview_dialog.dart';

class InventoryScreen extends StatefulWidget {
  final String? initialState;

  const InventoryScreen({super.key, this.initialState});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String _searchQuery = '';
  String _selectedUtility = 'All';
  String _selectedStatus = 'All';
  late String _selectedState;
  String _selectedFacility = 'All';
  final _searchController = TextEditingController();
  final _inventoryScrollController = ScrollController();
  double _savedInventoryOffset = 0;
  bool _shouldRestoreInventoryOffset = false;

  @override
  void initState() {
    super.initState();
    _selectedState = widget.initialState ?? 'All';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DatasetState>().loadNodes();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _inventoryScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DatasetState>();
    final nodes = state.nodes;
    final stateOptions = _stateOptions(nodes);
    final facilityOptions = [
      'All',
      ...facilitiesForState(nodes, _selectedState),
    ];

    final filterResult = filterEquipmentNodes(
      nodes: nodes,
      state: _selectedState,
      facility: _selectedFacility,
      utility: _selectedUtility,
      status: _selectedStatus,
      query: _searchQuery,
    );
    final locationCount = filterResult.utilityCounts.values
        .fold<int>(0, (sum, count) => sum + count);
    final displayNodes = filterResult.nodes;
    final isPhoneLandscape = adminLayoutModeFor(MediaQuery.sizeOf(context)) ==
        AdminLayoutMode.phoneLandscape;

    if (!state.isLoading && _shouldRestoreInventoryOffset) {
      _restoreInventoryPosition();
    }

    if (isPhoneLandscape && !state.isLoading) {
      return _phoneLandscapeLayout(
        context: context,
        state: state,
        stateOptions: stateOptions,
        facilityOptions: facilityOptions,
        locationCount: locationCount,
        displayNodes: displayNodes,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _header(context),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: FilterSearchField(
                    controller: _searchController,
                    hint: 'Search equipment…',
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: UtilityChips(
                    selected: _utilityFilter,
                    onChanged: _setUtilityFilter,
                    allCount: locationCount,
                    waterCount: filterResult.utilityCounts['Water'] ?? 0,
                    electricityCount:
                        filterResult.utilityCounts['Electricity'] ?? 0,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilterDropdown(
                          caption: 'State / Federal Territory',
                          value:
                              _selectedState == 'All' ? null : _selectedState,
                          allLabel: 'All States',
                          options: stateOptions
                              .where((s) => s != 'All')
                              .toList(growable: false),
                          onChanged: (value) {
                            setState(() {
                              _selectedState = value ?? 'All';
                              _selectedFacility = 'All';
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilterDropdown(
                          caption: 'Shopping Mall',
                          value: _selectedFacility == 'All'
                              ? null
                              : _selectedFacility,
                          allLabel: 'All Shopping Malls',
                          options: facilityOptions
                              .where((f) => f != 'All')
                              .toList(growable: false),
                          onChanged: (value) => setState(
                              () => _selectedFacility = value ?? 'All'),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: _statusFilterChips(filterResult.statusCounts),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _clearFilters,
                    child: const Text('Clear filters'),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: displayNodes.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(
                              vertical: 32, horizontal: 16),
                          child: Center(
                            child: Text(
                              'No equipment found matching your criteria.\nAdjust filters or tap + to deploy.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _inventoryScrollController,
                          padding: const EdgeInsets.only(bottom: 24),
                          itemCount: displayNodes.length,
                          itemBuilder: (context, index) => Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                            child: _equipmentCard(displayNodes[index], state),
                          ),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.adminPrimary,
        foregroundColor: Colors.white,
        onPressed: () => _openNodeForm(),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _saveInventoryPosition() {
    if (_inventoryScrollController.hasClients) {
      _savedInventoryOffset = _inventoryScrollController.offset;
      _shouldRestoreInventoryOffset = true;
    }
  }

  Future<void> _openNodeForm({EquipmentNode? node}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => NodeFormScreen(node: node)),
    );
    if (!mounted || saved != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          node == null
              ? 'Deployment saved successfully'
              : 'Deployment updated successfully',
        ),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _restoreInventoryPosition() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !_shouldRestoreInventoryOffset ||
          !_inventoryScrollController.hasClients) {
        return;
      }

      final position = _inventoryScrollController.position;
      final target = _savedInventoryOffset.clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      _inventoryScrollController.jumpTo(target);
      _shouldRestoreInventoryOffset = false;
    });
  }

  Widget _phoneLandscapeLayout({
    required BuildContext context,
    required DatasetState state,
    required List<String> stateOptions,
    required List<String> facilityOptions,
    required int locationCount,
    required List<EquipmentNode> displayNodes,
  }) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        key: const PageStorageKey('phone-landscape-inventory'),
        children: [
          PageHeader(
            title: 'Inventory',
            icon: Icons.inventory_2_outlined,
            compact: true,
            onLogout: () => context.read<RoleState>().logout(),
            titleAccessory: Text(
              '$locationCount equipment',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            action: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                LandscapeFilterMenu(
                  tooltip: 'Filter equipment',
                  activeCount: _activeLandscapeFilterCount,
                  compact: true,
                  child: _landscapeFilterControls(
                    stateOptions: stateOptions,
                    facilityOptions: facilityOptions,
                  ),
                ),
                const SizedBox(width: 8),
                MenuAnchor(
                  menuChildren: [
                    MenuItemButton(
                      leadingIcon: const Icon(Icons.upload_outlined),
                      onPressed: _importData,
                      child: const Text('Import'),
                    ),
                  ],
                  builder: (context, controller, _) => AdminHeaderIconButton(
                    tooltip: 'More inventory actions',
                    onPressed:
                        controller.isOpen ? controller.close : controller.open,
                    icon: Icons.more_horiz,
                  ),
                ),
                const SizedBox(width: 8),
                AdminHeaderIconButton(
                  tooltip: 'Add equipment',
                  onPressed: () => _openNodeForm(),
                  icon: Icons.add,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: _inventoryScrollController,
              padding: const EdgeInsets.fromLTRB(
                adminLandscapeHorizontalInset,
                12,
                adminLandscapeHorizontalInset,
                16,
              ),
              children: [
                FilterSearchField(
                  controller: _searchController,
                  hint: 'Search equipment…',
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
                const SizedBox(height: 12),
                Text(
                  _landscapeListLabel(),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                if (displayNodes.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        'No equipment found matching your criteria.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  )
                else
                  ...displayNodes.map((node) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _equipmentCard(node, state),
                      )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int get _activeLandscapeFilterCount {
    var count = 0;
    if (_selectedUtility != 'All') count++;
    if (_selectedState != 'All') count++;
    if (_selectedFacility != 'All') count++;
    if (_selectedStatus != 'All') count++;
    return count;
  }

  String _landscapeListLabel() {
    if (_selectedStatus != 'All') return '$_selectedStatus equipment';
    return 'All equipment';
  }

  Widget _landscapeFilterControls({
    required List<String> stateOptions,
    required List<String> facilityOptions,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: SectionLabel('Filter equipment')),
          ],
        ),
        const SizedBox(height: 8),
        const Text('Utility', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ['All', 'Water', 'Electricity']
              .map((value) => ChoiceChip(
                    label: Text(value),
                    selected: _selectedUtility == value,
                    onSelected: (_) => setState(() => _selectedUtility = value),
                  ))
              .toList(),
        ),
        const SizedBox(height: 12),
        FilterDropdown(
          caption: 'State / Federal Territory',
          value: _selectedState == 'All' ? null : _selectedState,
          allLabel: 'All States',
          options:
              stateOptions.where((s) => s != 'All').toList(growable: false),
          onChanged: (value) => setState(() {
            _selectedState = value ?? 'All';
            _selectedFacility = 'All';
          }),
        ),
        const SizedBox(height: 10),
        FilterDropdown(
          caption: 'Shopping Mall',
          value: _selectedFacility == 'All' ? null : _selectedFacility,
          allLabel: 'All Shopping Malls',
          options:
              facilityOptions.where((f) => f != 'All').toList(growable: false),
          onChanged: (value) =>
              setState(() => _selectedFacility = value ?? 'All'),
        ),
        const SizedBox(height: 12),
        const Text('Status', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: inventoryStatusFilters
              .map((value) => ChoiceChip(
                    label: Text(value),
                    selected: _selectedStatus == value,
                    onSelected: (_) => setState(() => _selectedStatus = value),
                  ))
              .toList(),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _clearFilters,
            child: const Text('Clear filters'),
          ),
        ),
      ],
    );
  }

  Widget _header(BuildContext context) {
    return PageHeader(
      title: 'Inventory',
      icon: Icons.inventory_2_outlined,
      onLogout: () => context.read<RoleState>().logout(),
      action: AdminHeaderAction(
        icon: Icons.upload_outlined,
        label: 'Import',
        secondary: true,
        onPressed: _importData,
      ),
    );
  }

  Future<void> _importData() async {
    final state = context.read<DatasetState>();
    final selection = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (!mounted || selection == null) return;

    final file = selection;
    late final List<int> bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (error) {
      _showImportError('Could not read ${file.name}: $error');
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

    final shouldImport = await _showImportPreview(
      fileName: file.name,
      result: result,
      existingAssetTags: state.nodes
          .map((node) => node.assetTag)
          .whereType<String>()
          .map((tag) => tag.toUpperCase())
          .toSet(),
    );
    if (!mounted || shouldImport != true) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await state.importRows(result.rows);
      if (!mounted) return;
      final skipped =
          result.issues.map((issue) => issue.sourceRow).toSet().length;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Imported ${result.rows.length} equipment nodes'
            '${skipped == 0 ? '.' : '; skipped $skipped invalid row(s).'}',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (error) {
      _showImportError('Import failed. No records were confirmed: $error');
    }
  }

  Future<bool?> _showImportPreview({
    required String fileName,
    required EquipmentImportResult result,
    required Set<String> existingAssetTags,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => EquipmentImportPreviewDialog(
        fileName: fileName,
        result: result,
        existingAssetTags: existingAssetTags,
      ),
    );
  }

  void _showImportError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.critical),
    );
  }

  Utility? get _utilityFilter => switch (_selectedUtility) {
        'Water' => Utility.water,
        'Electricity' => Utility.electricity,
        _ => null,
      };

  void _setUtilityFilter(Utility? utility) {
    setState(() {
      _selectedUtility = switch (utility) {
        Utility.water => 'Water',
        Utility.electricity => 'Electricity',
        null => 'All',
      };
    });
  }

  List<String> _stateOptions(List<EquipmentNode> nodes) {
    final states = nodes
        .map((node) => node.zoneId)
        .whereType<String>()
        .toSet()
        .toList()
      ..sort();
    if (_selectedState != 'All' && !states.contains(_selectedState)) {
      states.insert(0, _selectedState);
    }
    return ['All', ...states];
  }

  Widget _statusFilterChips(Map<String, int> counts) {
    final total = counts.values.fold<int>(0, (sum, count) => sum + count);
    return SegmentedChipRow(
      spacing: 8,
      children: inventoryStatusFilters
          .map((status) => SegmentedChip(
                label: status,
                count: status == 'All' ? total : counts[status] ?? 0,
                selected: _selectedStatus == status,
                onTap: () => setState(() => _selectedStatus = status),
                color: AppColors.adminPrimary,
              ))
          .toList(growable: false),
    );
  }

  void _clearFilters() {
    setState(() {
      _selectedState = 'All';
      _selectedFacility = 'All';
      _selectedUtility = 'All';
      _selectedStatus = 'All';
      _searchQuery = '';
      _searchController.clear();
    });
  }

  Widget _equipmentCard(EquipmentNode node, DatasetState state) {
    final isWater = node.utilityType == 'Water';
    final accent =
        isWater ? AppColors.waterAccent : AppColors.electricityAccent;
    final surface =
        isWater ? AppColors.waterSurface : AppColors.electricitySurface;

    Color statusColor;
    if (node.status == 'Active') {
      statusColor = AppColors.success;
    } else if (node.status == 'Critical') {
      statusColor = AppColors.critical;
    } else {
      statusColor = AppColors.warning;
    }

    return Dismissible(
      key: Key(node.nodeId ?? node.nodeName),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: AppColors.critical,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete equipment'),
            content: Text('Delete "${node.nodeName}"? This cannot be undone.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style:
                      TextButton.styleFrom(foregroundColor: AppColors.critical),
                  child: const Text('Delete')),
            ],
          ),
        );
      },
      onDismissed: (_) {
        if (node.nodeId != null) state.deleteNode(node.nodeId!);
      },
      child: GestureDetector(
        onTap: () {
          _saveInventoryPosition();
          state.selectNode(node);
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const EquipmentDetailScreen()),
          );
        },
        child: Stack(
          children: [
            Container(
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  void onEdit() => _openNodeForm(node: node);

                  if (constraints.maxWidth >= 720) {
                    return _wideEquipmentCardContent(
                      node: node,
                      accent: accent,
                      surface: surface,
                      statusColor: statusColor,
                      onEdit: onEdit,
                    );
                  }
                  return _compactEquipmentCardContent(
                    node: node,
                    accent: accent,
                    surface: surface,
                    statusColor: statusColor,
                    onEdit: onEdit,
                  );
                },
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 4,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _wideEquipmentCardContent({
    required EquipmentNode node,
    required Color accent,
    required Color surface,
    required Color statusColor,
    required VoidCallback onEdit,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 58,
          child: Center(
            child: _equipmentIcon(
              node: node,
              accent: accent,
              surface: surface,
              statusColor: statusColor,
            ),
          ),
        ),
        _cardDivider(),
        const SizedBox(width: 16),
        Expanded(flex: 6, child: _equipmentDetails(node)),
        _cardDivider(),
        SizedBox(
          width: 84,
          child: _labelledMetric(
            label: 'Status',
            value: node.status,
            color: statusColor,
          ),
        ),
        _cardDivider(),
        SizedBox(
          width: 128,
          child: _healthMetric(node.healthScore, statusColor),
        ),
        _cardDivider(),
        SizedBox(
          width: 64,
          child: _operationMetric(onEdit),
        ),
      ],
    );
  }

  Widget _compactEquipmentCardContent({
    required EquipmentNode node,
    required Color accent,
    required Color surface,
    required Color statusColor,
    required VoidCallback onEdit,
  }) {
    return Row(
      children: [
        _equipmentIcon(
          node: node,
          accent: accent,
          surface: surface,
          statusColor: statusColor,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _equipmentDetails(node),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    node.status,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${node.healthScore}%',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              _healthBar(node.healthScore, statusColor),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Edit equipment',
          icon: const Icon(Icons.edit_outlined, size: 18),
          color: AppColors.textSecondary,
          onPressed: onEdit,
        ),
      ],
    );
  }

  Widget _equipmentIcon({
    required EquipmentNode node,
    required Color accent,
    required Color surface,
    required Color statusColor,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            node.utilityType == 'Water'
                ? Icons.water_drop_outlined
                : Icons.electric_bolt,
            color: accent,
          ),
        ),
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.surface, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _equipmentDetails(EquipmentNode node) {
    final assetTag = normalizedAssetTag(node.assetTag);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          node.facilityName ?? 'Unassigned facility',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.adminPrimary,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          equipmentDisplayName(node),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        if (assetTag != null)
          Text(
            assetTag,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        const SizedBox(height: 2),
        Text(
          '${node.zoneId ?? '—'} · ${node.facilityCity ?? '—'} · ${node.manufacturer ?? 'Unknown'}',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _labelledMetric({
    required String label,
    required String value,
    required Color color,
  }) {
    return _metricColumn(
      label: label,
      value: Text(
        value,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  Widget _healthMetric(int score, Color color) {
    return _metricColumn(
      label: 'Health',
      value: Text(
        '$score%',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
      footer: SizedBox(
        width: double.infinity,
        child: _healthBar(score, color),
      ),
    );
  }

  Widget _operationMetric(VoidCallback onEdit) {
    return _metricColumn(
      label: 'Operation',
      value: IconButton(
        tooltip: 'Edit equipment',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 28, height: 28),
        icon: const Icon(Icons.edit_outlined, size: 18),
        color: AppColors.textSecondary,
        onPressed: onEdit,
      ),
    );
  }

  Widget _metricColumn({
    required String label,
    required Widget value,
    Widget? footer,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          height: 18,
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(height: 28, child: Center(child: value)),
        const SizedBox(height: 4),
        SizedBox(height: 6, child: footer ?? const SizedBox.shrink()),
      ],
    );
  }

  Widget _healthBar(int score, Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: (score / 100).clamp(0.0, 1.0),
        minHeight: 6,
        backgroundColor: color.withValues(alpha: 0.15),
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }

  Widget _cardDivider() {
    return Container(
      width: 1,
      height: 56,
      color: AppColors.divider,
    );
  }
}
