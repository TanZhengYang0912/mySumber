import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'equipment access policies limit reads to active staff and writes to active admins',
      () {
    final migrations = Directory('supabase/migrations')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.sql'))
        .where((file) =>
            file.path.contains('restrict_equipment_access_to_active_staff'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    expect(migrations, hasLength(1));
    final sql = migrations.single.readAsStringSync();

    const tables = {
      'equipment_nodes': (
        label: 'equipment nodes',
        legacyManage: 'Admins can manage equipment nodes',
      ),
      'equipment_usage_logs': (
        label: 'equipment usage logs',
        legacyManage: 'Authenticated users can manage equipment usage logs',
      ),
      'facilities': (
        label: 'facilities',
        legacyManage: 'Authenticated users can manage facilities',
      ),
      'manufacturers': (
        label: 'manufacturers',
        legacyManage: 'Authenticated users can manage manufacturers',
      ),
      'equipment_models': (
        label: 'equipment models',
        legacyManage: 'Authenticated users can manage equipment models',
      ),
      'firmware_catalog': (
        label: 'firmware catalog',
        legacyManage: 'Authenticated users can manage firmware catalog',
      ),
    };

    for (final entry in tables.entries) {
      final policy = entry.value;
      expect(
        sql,
        contains(
            'drop policy if exists "Authenticated users can read ${policy.label}"'),
      );
      expect(
        sql,
        contains('drop policy if exists "${policy.legacyManage}"'),
      );
      expect(
        sql,
        contains('create policy "Active staff can read ${policy.label}"'),
      );
      expect(
        sql,
        contains('create policy "Active admins can manage ${policy.label}"'),
      );
    }
  });
}
