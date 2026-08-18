// dart format width=80
// ignore_for_file: unused_local_variable, unused_import
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:mysumber/core/local_database/local_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'generated/schema.dart';

import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  group('simple database migrations', () {
    // These simple tests verify all possible schema updates with a simple (no
    // data) migration. This is a quick way to ensure that written database
    // migrations properly alter the schema.
    const versions = GeneratedHelper.versions;
    for (final (i, fromVersion) in versions.indexed) {
      group('from $fromVersion', () {
        for (final toVersion in versions.skip(i + 1)) {
          test('to $toVersion', () async {
            final schema = await verifier.schemaAt(fromVersion);
            final db = LocalDatabase(schema.newConnection());
            await verifier.migrateAndValidate(db, toVersion);
            await db.close();
          });
        }
      });
    }
  });

  test('migration from v1 to v2 does not corrupt data', () async {
    final oldLocalEquipmentNodesData = [
      const v1.LocalEquipmentNodesData(
        nodeId: 'node-1',
        facilityName: 'Suria KLCC',
        nodeName: 'Main Water Pump A1',
        payload: '{"node_id":"node-1"}',
      ),
    ];
    final expectedNewLocalEquipmentNodesData = [
      const v2.LocalEquipmentNodesData(
        nodeId: 'node-1',
        facilityName: 'Suria KLCC',
        nodeName: 'Main Water Pump A1',
        payload: '{"node_id":"node-1"}',
      ),
    ];

    final oldLocalEquipmentUsageLogsData = <v1.LocalEquipmentUsageLogsData>[];
    final expectedNewLocalEquipmentUsageLogsData =
        <v2.LocalEquipmentUsageLogsData>[];

    final oldLocalReadingsData = <v1.LocalReadingsData>[];
    final expectedNewLocalReadingsData = <v2.LocalReadingsData>[];

    final oldLocalAlertsData = <v1.LocalAlertsData>[];
    final expectedNewLocalAlertsData = <v2.LocalAlertsData>[];

    final oldLocalReportsData = <v1.LocalReportsData>[];
    final expectedNewLocalReportsData = <v2.LocalReportsData>[];

    final oldLocalCustomerUtilityEntriesData =
        <v1.LocalCustomerUtilityEntriesData>[];
    final expectedNewLocalCustomerUtilityEntriesData =
        <v2.LocalCustomerUtilityEntriesData>[];

    final oldLocalSyncMetadataData = <v1.LocalSyncMetadataData>[];
    final expectedNewLocalSyncMetadataData = <v2.LocalSyncMetadataData>[];

    await verifier.testWithDataIntegrity(
      oldVersion: 1,
      newVersion: 2,
      createOld: v1.DatabaseAtV1.new,
      createNew: v2.DatabaseAtV2.new,
      openTestedDatabase: LocalDatabase.new,
      createItems: (batch, oldDb) {
        batch.insertAll(oldDb.localEquipmentNodes, oldLocalEquipmentNodesData);
        batch.insertAll(
            oldDb.localEquipmentUsageLogs, oldLocalEquipmentUsageLogsData);
        batch.insertAll(oldDb.localReadings, oldLocalReadingsData);
        batch.insertAll(oldDb.localAlerts, oldLocalAlertsData);
        batch.insertAll(oldDb.localReports, oldLocalReportsData);
        batch.insertAll(oldDb.localCustomerUtilityEntries,
            oldLocalCustomerUtilityEntriesData);
        batch.insertAll(oldDb.localSyncMetadata, oldLocalSyncMetadataData);
      },
      validateItems: (newDb) async {
        expect(expectedNewLocalEquipmentNodesData,
            await newDb.select(newDb.localEquipmentNodes).get());
        expect(expectedNewLocalEquipmentUsageLogsData,
            await newDb.select(newDb.localEquipmentUsageLogs).get());
        expect(expectedNewLocalReadingsData,
            await newDb.select(newDb.localReadings).get());
        expect(expectedNewLocalAlertsData,
            await newDb.select(newDb.localAlerts).get());
        expect(expectedNewLocalReportsData,
            await newDb.select(newDb.localReports).get());
        expect(expectedNewLocalCustomerUtilityEntriesData,
            await newDb.select(newDb.localCustomerUtilityEntries).get());
        expect(expectedNewLocalSyncMetadataData,
            await newDb.select(newDb.localSyncMetadata).get());
      },
    );
  });
}
