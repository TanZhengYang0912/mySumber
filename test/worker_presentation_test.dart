import 'package:flutter_test/flutter_test.dart';

import 'package:mysumber/modules/dataset/models/models.dart';
import 'package:mysumber/modules/leakage/models/alert.dart';
import 'package:mysumber/modules/leakage/models/report.dart';
import 'package:mysumber/modules/leakage/screens/style.dart';
import 'package:mysumber/modules/leakage/services/report_presets.dart';
import 'package:mysumber/modules/leakage/state/app_state.dart';

Alert _alert({
  required String alertType,
  required String signature,
  String status = AlertStatus.pending,
  String? handledBy,
}) =>
    Alert(
      alertType: alertType,
      state: 'Selangor',
      detectedAt: DateTime(2026, 8, 1),
      signature: signature,
      severity: Severity.high,
      explanation: 'Test alert',
      status: status,
      handledBy: handledBy,
    );

void main() {
  test('household alerts show their detection signature, not the word Household',
      () {
    final label = alertReasonLabel(_alert(
      alertType: AlertType.household,
      signature: LeakSignature.suddenBurst,
    ));

    expect(label, 'Sudden burst');
    expect(label, isNot(contains('Household')));
  });

  test('network alerts keep their own type wording', () {
    expect(
      alertReasonLabel(_alert(
        alertType: AlertType.nrwHotspot,
        signature: LeakSignature.nrwHotspot,
      )),
      'NRW hotspot',
    );
    expect(
      alertReasonLabel(_alert(
        alertType: AlertType.electricityTampering,
        signature: LeakSignature.electricityTampering,
      )),
      'Potential tampering',
    );
  });

  test('appending a preset to an empty field yields just the preset', () {
    expect(appendPreset('', 'Pipe burst at main junction.'),
        'Pipe burst at main junction.');
    expect(appendPreset('   ', 'Pipe burst at main junction.'),
        'Pipe burst at main junction.');
  });

  test('appending a preset keeps what the worker already typed', () {
    expect(
      appendPreset('Arrived 09:00.', 'Pipe burst at main junction.'),
      'Arrived 09:00. Pipe burst at main junction.',
    );
  });

  test('appending never doubles the separating space', () {
    expect(
      appendPreset('Arrived 09:00. ', 'Pipe burst at main junction.'),
      'Arrived 09:00. Pipe burst at main junction.',
    );
  });

  test('presets differ per utility and are never empty', () {
    expect(findingsPresets(Utility.water), isNotEmpty);
    expect(actionPresets(Utility.electricity), isNotEmpty);
    expect(
      findingsPresets(Utility.water),
      isNot(equals(findingsPresets(Utility.electricity))),
    );
  });

  test('handledLabel is null for a pending alert', () {
    expect(
      handledLabel(
        _alert(
          alertType: AlertType.household,
          signature: LeakSignature.suddenBurst,
          status: AlertStatus.pending,
        ),
        'Aisyah',
      ),
      isNull,
    );
  });

  test('handledLabel is null when the resolved name is empty', () {
    expect(
      handledLabel(
        _alert(
          alertType: AlertType.household,
          signature: LeakSignature.suddenBurst,
          status: AlertStatus.investigating,
        ),
        null,
      ),
      isNull,
    );
  });

  test('handledLabel names who is investigating, undated', () {
    expect(
      handledLabel(
        _alert(
          alertType: AlertType.household,
          signature: LeakSignature.suddenBurst,
          status: AlertStatus.investigating,
        ),
        'Aisyah',
      ),
      'Investigating by Aisyah',
    );
  });

  test('handledLabel dates a resolved alert when a closing timestamp is given',
      () {
    expect(
      handledLabel(
        _alert(
          alertType: AlertType.household,
          signature: LeakSignature.suddenBurst,
          status: AlertStatus.resolved,
        ),
        'Aisyah',
        DateTime(2026, 8, 3, 14, 20),
      ),
      'Resolved by Aisyah · 3 Aug 2026, 14:20',
    );
  });

  test('reportByline names the worker and the update time', () {
    final report = Report(
      alertId: 1,
      workerName: 'Aisyah',
      findings: 'Leak found',
      actionTaken: 'Patched',
      outcome: ReportOutcome.fixed,
      createdAt: DateTime(2026, 8, 3, 14, 0),
      updatedAt: DateTime(2026, 8, 3, 14, 20),
    );

    expect(reportByline(report, 'Aisyah'), 'By Aisyah · 3 Aug 2026, 14:20');
  });

  test('an investigating alert with no owner is not locked', () {
    expect(
      alertLockedForUser(
        _alert(
          alertType: AlertType.household,
          signature: LeakSignature.suddenBurst,
          status: AlertStatus.investigating,
        ),
        'viewer-id',
      ),
      isFalse,
    );
  });

  test('an investigating alert is locked for a different worker', () {
    final alert = _alert(
      alertType: AlertType.household,
      signature: LeakSignature.suddenBurst,
      status: AlertStatus.investigating,
      handledBy: 'X',
    ).copyWith(handledById: 'owner-id');
    expect(alertLockedForUser(alert, 'viewer-id'), isTrue);
  });

  test('an investigating alert is not locked for its own owner', () {
    final alert = _alert(
      alertType: AlertType.household,
      signature: LeakSignature.suddenBurst,
      status: AlertStatus.investigating,
      handledBy: 'X',
    ).copyWith(handledById: 'owner-id');
    expect(alertLockedForUser(alert, 'owner-id'), isFalse);
  });

  test('a not-fixed alert is never locked — reopening is open to anyone', () {
    final alert = _alert(
      alertType: AlertType.household,
      signature: LeakSignature.suddenBurst,
      status: AlertStatus.notFixed,
      handledBy: 'X',
    ).copyWith(handledById: 'owner-id');
    expect(alertLockedForUser(alert, 'viewer-id'), isFalse);
  });

  test('a resolved alert no longer counts as "already reported"', () {
    bool isActiveReport(Alert alert) =>
        alert.status != AlertStatus.resolved &&
        alert.status != AlertStatus.dismissed;

    final resolved = _alert(
      alertType: AlertType.nrwHotspot,
      signature: LeakSignature.nrwHotspot,
      status: AlertStatus.resolved,
    );
    final pending = _alert(
      alertType: AlertType.nrwHotspot,
      signature: LeakSignature.nrwHotspot,
      status: AlertStatus.pending,
    );

    expect(isActiveReport(resolved), isFalse);
    expect(isActiveReport(pending), isTrue);
  });

  EquipmentNode node(String status) => EquipmentNode(
        nodeName: 'Test Pump',
        utilityType: 'Water',
        status: status,
        ipAssignment: 'DHCP',
      );

  test('needsAttention flags Critical, Warning, and Maintenance', () {
    expect(AppState.needsAttention(node('Critical')), isTrue);
    expect(AppState.needsAttention(node('Warning')), isTrue);
    expect(AppState.needsAttention(node('Maintenance')), isTrue);
    expect(AppState.needsAttention(node('Active')), isFalse);
  });

  test('equipmentSeverity maps status to alert severity', () {
    expect(AppState.equipmentSeverity('Critical'), Severity.high);
    expect(AppState.equipmentSeverity('Warning'), Severity.medium);
    expect(AppState.equipmentSeverity('Maintenance'), Severity.low);
    expect(AppState.equipmentSeverity('Active'), Severity.low);
  });
}
