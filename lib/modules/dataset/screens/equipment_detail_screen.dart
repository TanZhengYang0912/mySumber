import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../state/dataset_state.dart';
import '../models/models.dart';
import '../services/equipment_identity.dart';

class EquipmentDetailScreen extends StatefulWidget {
  const EquipmentDetailScreen({super.key});

  @override
  State<EquipmentDetailScreen> createState() => _EquipmentDetailScreenState();
}

class _EquipmentDetailScreenState extends State<EquipmentDetailScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Equipment Details'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
      ),
      body: Consumer<DatasetState>(
        builder: (context, state, child) {
          final node = state.selectedNode;
          if (node == null) {
            return const Center(child: Text('No Node Selected'));
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeaderInfo(node),
                _buildChartSection(state),
                _buildSpecsSection(node),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderInfo(EquipmentNode node) {
    final assetTag = normalizedAssetTag(node.assetTag);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                node.utilityType == 'Water'
                    ? Icons.water_drop
                    : Icons.electric_bolt,
                color: node.utilityType == 'Water' ? Colors.blue : Colors.amber,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      equipmentDisplayName(node),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    if (assetTag != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Asset Tag: $assetTag',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.blueGrey,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _buildStatusBadge(node.status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${node.zoneId ?? 'Unknown region'} • ${node.facilityCity ?? 'Unknown city'}',
            style: const TextStyle(fontSize: 16, color: Colors.blueGrey),
          ),
          if (node.facilityName != null) ...[
            const SizedBox(height: 4),
            Text(
              'Facility: ${node.facilityName}',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.teal,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            node.manufacturer ?? 'Unknown Manufacturer',
            style: const TextStyle(fontSize: 14, color: Colors.blueGrey),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = Colors.orange;
    if (status == 'Active') {
      color = Colors.green;
    } else if (status == 'Critical') {
      color = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildChartSection(DatasetState state) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Usage & AI Anomaly Detection',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'The AI algorithm computes Z-scores in real-time. Spikes >2.5σ are flagged in red.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 250,
            child: state.currentLogs.isEmpty
                ? const Center(child: Text('No historical data available.'))
                : _buildLineChart(state),
          ),
        ],
      ),
    );
  }

  Widget _buildLineChart(DatasetState state) {
    final logs = state.currentLogs;
    final spots = <FlSpot>[];
    final anomalyIndices = <int>[];

    for (int i = 0; i < logs.length; i++) {
      spots.add(FlSpot(i.toDouble(), logs[i].usageValue));
      if (logs[i].isAnomaly) {
        anomalyIndices.add(i);
      }
    }

    return LineChart(
      LineChartData(
        minY: 0,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.blueAccent,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                if (anomalyIndices.contains(index)) {
                  return FlDotCirclePainter(
                    radius: 6,
                    color: Colors.red,
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  );
                }
                return FlDotCirclePainter(
                  radius: 3,
                  color: Colors.blueAccent,
                  strokeWidth: 1,
                  strokeColor: Colors.white,
                );
              },
            ),
          ),
        ],
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(show: true),
        borderData: FlBorderData(
            show: true, border: Border.all(color: Colors.grey.shade200)),
      ),
    );
  }

  Widget _buildSpecsSection(EquipmentNode node) {
    final dateFormat = DateFormat.yMMMd();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Hardware Specifications',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildSpecRow(
              'IP Address', node.ipAddress ?? 'N/A', Icons.network_wifi),
          const Divider(),
          _buildSpecRow(
              'Firmware', node.firmwareVersion ?? 'N/A', Icons.memory),
          const Divider(),
          _buildSpecRow(
              'Installed',
              node.installationDate != null
                  ? dateFormat.format(node.installationDate!)
                  : 'N/A',
              Icons.event),
          const Divider(),
          _buildSpecRow(
              'Last Maintenance',
              node.lastMaintenanceDate != null
                  ? dateFormat.format(node.lastMaintenanceDate!)
                  : 'N/A',
              Icons.build),
        ],
      ),
    );
  }

  Widget _buildSpecRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.blueGrey, size: 20),
          const SizedBox(width: 12),
          Text(label,
              style: const TextStyle(color: Colors.blueGrey, fontSize: 16)),
          const Spacer(),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}
