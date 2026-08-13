import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/tokens.dart';
import '../../auth/state/auth_state.dart';
import '../../admin/services/admin_tablet_layout.dart';
import '../../admin/widgets/landscape_filter_menu.dart';
import '../state/dataset_state.dart';
import '../models/models.dart';
import '../services/inventory_filter.dart';
import 'equipment_detail_screen.dart';
import 'node_form_screen.dart';

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
          : ListView(
              controller: _inventoryScrollController,
              padding: EdgeInsets.zero,
              children: [
                _header(context),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _searchField(),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _filterChips(
                    locationCount,
                    filterResult.utilityCounts['Water'] ?? 0,
                    filterResult.utilityCounts['Electricity'] ?? 0,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: _locationDropdown(
                          label: 'State / Federal Territory',
                          value: _selectedState,
                          items: stateOptions,
                          displayAll: 'All States',
                          showFloatingLabel: false,
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
                        child: _locationDropdown(
                          label: 'Shopping Mall',
                          value: _selectedFacility,
                          items: facilityOptions,
                          displayAll: 'All Shopping Malls',
                          showFloatingLabel: false,
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
                if (displayNodes.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                    child: Center(
                      child: Text(
                        'No equipment found matching your criteria.\nAdjust filters or tap + to deploy.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  )
                else
                  ...displayNodes.map((n) => Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: _equipmentCard(n, state),
                      )),
                const SizedBox(height: 24),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.adminPrimary,
        foregroundColor: Colors.white,
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NodeFormScreen()),
          );
        },
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
      body: SafeArea(
        child: Column(
          key: const PageStorageKey('phone-landscape-inventory'),
          children: [
            SizedBox(
              height: 60,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Text(
                      'Inventory',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$locationCount equipment',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    LandscapeFilterMenu(
                      tooltip: 'Filter equipment',
                      activeCount: _activeLandscapeFilterCount,
                      child: _landscapeFilterControls(
                        stateOptions: stateOptions,
                        facilityOptions: facilityOptions,
                      ),
                    ),
                    MenuAnchor(
                      menuChildren: [
                        MenuItemButton(
                          leadingIcon: const Icon(Icons.upload_outlined),
                          onPressed: () => _importData(context),
                          child: const Text('Import'),
                        ),
                      ],
                      builder: (context, controller, _) => IconButton(
                        tooltip: 'More inventory actions',
                        onPressed: controller.isOpen
                            ? controller.close
                            : controller.open,
                        icon: const Icon(Icons.more_horiz),
                      ),
                    ),
                    IconButton.filled(
                      tooltip: 'Add equipment',
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.adminPrimary,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const NodeFormScreen()),
                      ),
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: _inventoryScrollController,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                children: [
                  _searchField(),
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
        _locationDropdown(
          label: 'State / Federal Territory',
          value: _selectedState,
          items: stateOptions,
          displayAll: 'All States',
          showFloatingLabel: false,
          onChanged: (value) => setState(() {
            _selectedState = value ?? 'All';
            _selectedFacility = 'All';
          }),
        ),
        const SizedBox(height: 10),
        _locationDropdown(
          label: 'Shopping Mall',
          value: _selectedFacility,
          items: facilityOptions,
          displayAll: 'All Shopping Malls',
          showFloatingLabel: false,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'mySumber · ADMIN',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => context.read<RoleState>().logout(),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.logout, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text('Logout',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Expanded(
                  child: Text(
                    'Inventory',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                ),
                headerActionButton(
                  icon: Icons.upload_outlined,
                  label: 'Import',
                  onTap: () => _importData(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _importData(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import Equipment Data'),
        content: const Text(
            'Bulk-import 4 predefined equipment records from the sample data?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.adminPrimary,
              minimumSize: const Size(80, 40),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              _processImport();
            },
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }

  void _processImport() {
    final state = context.read<DatasetState>();
    const csvString =
        '''node_name,utility_type,zone_id,facility_city,facility_name,manufacturer,status
Smart Water Meter X1,Water,Johor,Johor Bahru,Mid Valley Southkey,AquaTech,Active
High-Voltage Transformer,Electricity,Selangor,Petaling Jaya,1 Utama Shopping Centre,Siemens,Critical
Main Valve B,Water,Kedah,Alor Setar,Aman Central,FlowMaster,Warning
Backup Generator 2,Electricity,Kelantan,Kota Bharu,AEON Mall Kota Bharu,Honda,Active''';

    final lines = csvString.split('\n');
    int count = 0;
    for (int i = 1; i < lines.length; i++) {
      final parts = lines[i].split(',');
      if (parts.length >= 7) {
        state.addOrUpdateNode(EquipmentNode(
          nodeName: parts[0],
          utilityType: parts[1],
          zoneId: parts[2],
          facilityCity: parts[3],
          facilityName: parts[4],
          manufacturer: parts[5],
          status: parts[6],
          installationDate: DateTime.now(),
        ));
        count++;
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Successfully imported $count equipment nodes.'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Widget _searchField() {
    return TextField(
      controller: _searchController,
      onChanged: (v) => setState(() => _searchQuery = v),
      decoration: const InputDecoration(
        hintText: 'Search equipment…',
        hintStyle: TextStyle(color: AppColors.textTertiary),
        prefixIcon: Icon(Icons.search, color: AppColors.textTertiary),
        contentPadding: EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }

  Widget _filterChips(int total, int water, int elec) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip('All ($total)', 'All'),
          const SizedBox(width: 8),
          _chip('Water ($water)', 'Water', icon: Icons.water_drop_outlined),
          const SizedBox(width: 8),
          _chip('Electricity ($elec)', 'Electricity',
              icon: Icons.electric_bolt_outlined),
        ],
      ),
    );
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

  Widget _locationDropdown({
    required String label,
    required String value,
    required List<String> items,
    required String displayAll,
    required ValueChanged<String?> onChanged,
    bool showFloatingLabel = true,
  }) {
    final dropdown = DropdownButtonFormField<String>(
      key: ValueKey('$label-$value'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: showFloatingLabel ? label : null,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      items: items
          .map((item) => DropdownMenuItem<String>(
                value: item,
                child: Text(
                  item == 'All' ? displayAll : item,
                  overflow: TextOverflow.ellipsis,
                ),
              ))
          .toList(),
      onChanged: onChanged,
    );
    if (showFloatingLabel) return dropdown;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary)),
        const SizedBox(height: 5),
        dropdown,
      ],
    );
  }

  Widget _chip(String label, String value, {IconData? icon}) {
    final selected = _selectedUtility == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedUtility = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.adminPrimary : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.adminPrimary : AppColors.divider,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 14,
                  color: selected ? Colors.white : AppColors.textPrimary),
              const SizedBox(width: 4),
            ],
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }

  Widget _statusFilterChips(Map<String, int> counts) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: inventoryStatusFilters.map((status) {
          final label =
              '$status (${status == 'All' ? counts.values.fold<int>(0, (sum, count) => sum + count) : counts[status] ?? 0})';
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _statusChip(label, status),
          );
        }).toList(),
      ),
    );
  }

  Widget _statusChip(String label, String value) {
    final selected = _selectedStatus == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedStatus = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.adminPrimary : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.adminPrimary : AppColors.divider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
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
                  void onEdit() {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => NodeFormScreen(node: node),
                      ),
                    );
                  }

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
          node.nodeName,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
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
