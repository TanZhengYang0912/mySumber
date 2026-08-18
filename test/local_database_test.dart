import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysumber/core/local_database/local_database.dart';

void main() {
  late LocalDatabase database;

  setUp(() {
    database = LocalDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test('replaces equipment snapshots and preserves map values', () async {
    await database.replaceEquipmentNodes([
      {
        'node_id': 'node-1',
        'node_name': 'Main Pump',
        'utility_type': 'Water',
        'facility_name': 'Suria KLCC',
        'status': 'Active',
      },
    ]);

    expect(await database.equipmentNodes(), [
      containsPair('node_name', 'Main Pump'),
    ]);

    await database.replaceEquipmentNodes([
      {
        'node_id': 'node-2',
        'node_name': 'Transformer',
        'utility_type': 'Electricity',
        'facility_name': 'Pavilion Kuala Lumpur',
        'status': 'Active',
      },
    ]);

    final rows = await database.equipmentNodes();
    expect(rows, hasLength(1));
    expect(rows.single['node_id'], 'node-2');
  });

  test('replaces usage logs only inside the selected node scope', () async {
    await database.replaceEquipmentLogs('node-1', [
      {
        'log_id': 'log-1',
        'node_id': 'node-1',
        'timestamp': '2026-08-01T00:00:00.000Z',
        'usage_value': 10.0,
        'is_anomaly': false,
      },
    ]);
    await database.replaceEquipmentLogs('node-2', [
      {
        'log_id': 'log-2',
        'node_id': 'node-2',
        'timestamp': '2026-08-01T00:00:00.000Z',
        'usage_value': 20.0,
        'is_anomaly': true,
      },
    ]);

    await database.replaceEquipmentLogs('node-1', [
      {
        'log_id': 'log-3',
        'node_id': 'node-1',
        'timestamp': '2026-08-02T00:00:00.000Z',
        'usage_value': 11.0,
        'is_anomaly': false,
      },
    ]);

    expect((await database.equipmentLogs('node-1')).single['log_id'], 'log-3');
    expect((await database.equipmentLogs('node-2')).single['log_id'], 'log-2');
  });

  test('isolates cached customer entries by user and utility', () async {
    await database.replaceCustomerEntries(
      userId: 'customer-a',
      utility: 'water',
      rows: [
        {
          'id': 1,
          'user_id': 'customer-a',
          'utility': 'water',
          'period_month': '2026-08-01',
          'value': 12.5,
        },
      ],
    );

    expect(await database.customerEntries('customer-b', 'water'), isEmpty);
    expect(
        await database.customerEntries('customer-a', 'electricity'), isEmpty);
    expect(await database.customerEntries('customer-a', 'water'), hasLength(1));
  });

  test('stores operational snapshots and sync timestamps', () async {
    await database.upsertReading({
      'id': 1,
      'household_id': 'H-001',
      'reading_date': '2026-08-01T00:00:00.000Z',
    });
    await database.replaceAlerts([
      {
        'id': 2,
        'status': 'pending',
        'is_deleted': false,
        'detected_at': '2026-08-02T00:00:00.000Z',
      },
    ]);
    await database.replaceReports([
      {
        'id': 3,
        'is_deleted': false,
        'updated_at': '2026-08-03T00:00:00.000Z',
      },
    ]);
    final syncedAt = DateTime.utc(2026, 8, 4);
    await database.setLastSync('alerts', syncedAt);

    expect(await database.readings(), hasLength(1));
    expect(await database.alerts(), hasLength(1));
    expect(await database.reports(), hasLength(1));
    expect(await database.lastSync('alerts'), syncedAt);
  });

  test('stores, isolates, updates, and deletes verified account profiles',
      () async {
    final firstVerifiedAt = DateTime.utc(2026, 8, 19, 1);
    await database.upsertAccountProfile({
      'id': 'user-a',
      'full_name': 'Admin A',
      'email': 'a@example.com',
      'role': 'admin',
      'status': 'active',
    }, firstVerifiedAt);
    await database.upsertAccountProfile({
      'id': 'user-b',
      'full_name': 'Worker B',
      'email': 'b@example.com',
      'role': 'worker',
      'status': 'active',
    }, DateTime.utc(2026, 8, 19, 2));

    expect((await database.accountProfile('user-a'))?['role'], 'admin');
    expect((await database.accountProfile('user-a'))?['verified_at'],
        firstVerifiedAt);
    expect((await database.accountProfile('user-b'))?['role'], 'worker');
    expect(await database.accountProfile('user-c'), isNull);

    await database.upsertAccountProfile({
      'id': 'user-a',
      'full_name': 'Admin A Updated',
      'email': 'a@example.com',
      'role': 'admin',
      'status': 'inactive',
    }, DateTime.utc(2026, 8, 19, 3));

    expect((await database.accountProfile('user-a'))?['status'], 'inactive');
    expect((await database.accountProfile('user-b'))?['status'], 'active');

    await database.deleteAccountProfile('user-a');

    expect(await database.accountProfile('user-a'), isNull);
    expect(await database.accountProfile('user-b'), isNotNull);
  });
}
