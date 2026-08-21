import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../theme/filter_controls.dart';
import '../../../theme/page_header.dart';
import '../../../theme/tokens.dart';
import '../../auth/state/auth_state.dart';
import '../services/mall_summary.dart';
import '../state/dataset_state.dart';
import 'mall_detail_screen.dart';

class InventoryScreen extends StatefulWidget {
  final String? initialState;

  const InventoryScreen({super.key, this.initialState});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  late String _selectedState;
  final _searchController = TextEditingController();
  String _searchQuery = '';

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DatasetState>();
    final stateOptions = _stateOptions(state);
    final allMalls = buildMallSummaries(
      state.nodes,
      state.latestUsageByNode,
      state.latestUsageAtByNode,
    );
    final query = _searchQuery.trim().toLowerCase();
    final malls = allMalls.where((mall) {
      if (_selectedState != 'All' && mall.state != _selectedState) {
        return false;
      }
      return query.isEmpty ||
          '${mall.name} ${mall.city ?? ''} ${mall.state}'
              .toLowerCase()
              .contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                PageHeader(
                  title: 'Mall',
                  icon: Icons.location_city_outlined,
                  onLogout: () => context.read<RoleState>().logout(),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: FilterSearchField(
                    controller: _searchController,
                    hint: 'Search shopping malls',
                    onChanged: (value) => setState(() => _searchQuery = value),
                    onClear: () => setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                    }),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: FilterDropdown(
                    caption: 'State / Federal Territory',
                    value: _selectedState == 'All' ? null : _selectedState,
                    allLabel: 'All malls',
                    options:
                        stateOptions.where((state) => state != 'All').toList(),
                    onChanged: (value) =>
                        setState(() => _selectedState = value ?? 'All'),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _clearFilters,
                    child: const Text('Clear filters'),
                  ),
                ),
                Expanded(
                  child: malls.isEmpty
                      ? const Center(
                          child: Text(
                            'No shopping malls match your filters.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: malls.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, index) => _mallCard(malls[index]),
                        ),
                ),
              ],
            ),
    );
  }

  List<String> _stateOptions(DatasetState state) {
    final states = state.nodes
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

  void _clearFilters() {
    setState(() {
      _selectedState = 'All';
      _searchQuery = '';
      _searchController.clear();
    });
  }

  Widget _mallCard(MallSummary mall) {
    return AppCard(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: context.read<DatasetState>(),
          child: MallDetailScreen(facilityName: mall.name),
        ),
      )),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(
                mall.name,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (mall.attentionCount > 0)
              Pill(
                '${mall.attentionCount} need attention',
                color: AppColors.critical,
                outlined: true,
              ),
          ]),
          const SizedBox(height: 4),
          Text(
            mall.city == null ? mall.state : '${mall.city}, ${mall.state}',
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(children: [
            if (mall.hasWater)
              Expanded(
                child: _utilityTile(
                  label: 'Water',
                  usage: mall.waterUsage,
                  status: mall.waterStatus,
                  unit: 'm³',
                  color: AppColors.waterAccent,
                ),
              ),
            if (mall.hasWater && mall.hasElectricity) const SizedBox(width: 10),
            if (mall.hasElectricity)
              Expanded(
                child: _utilityTile(
                  label: 'Electricity',
                  usage: mall.electricityUsage,
                  status: mall.electricityStatus,
                  unit: 'kWh',
                  color: AppColors.electricityAccent,
                ),
              ),
          ]),
          if (mall.lastUpdated != null) ...[
            const SizedBox(height: 10),
            Text(
              'Updated ${DateFormat('d MMM y, HH:mm').format(mall.lastUpdated!)}',
              style:
                  const TextStyle(color: AppColors.textTertiary, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _utilityTile({
    required String label,
    required double usage,
    required String status,
    required String unit,
    required Color color,
  }) {
    return Container(
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
                  color: AppColors.textSecondary, fontSize: 11)),
          const SizedBox(height: 4),
          Text(
            '${usage.toStringAsFixed(1)} $unit',
            style: TextStyle(
                color: color, fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Pill(status, color: equipmentStatusColor(status), outlined: true),
        ],
      ),
    );
  }
}

Color equipmentStatusColor(String status) => switch (status) {
      'Critical' => AppColors.critical,
      'Warning' => AppColors.warning,
      'Maintenance' => AppColors.textSecondary,
      _ => AppColors.success,
    };
