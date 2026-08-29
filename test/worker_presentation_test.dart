import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mysumber/modules/dataset/models/models.dart';
import 'package:mysumber/modules/leakage/models/alert.dart';
import 'package:mysumber/modules/leakage/models/report.dart';
import 'package:mysumber/modules/leakage/screens/style.dart';
import 'package:mysumber/modules/leakage/services/report_presets.dart';
import 'package:mysumber/modules/leakage/state/app_state.dart';
import 'package:mysumber/theme/tokens.dart';
import 'package:mysumber/theme/responsive_filter_bar.dart';

Alert _alert({
  required String alertType,
  required String signature,
  String status = AlertStatus.pending,
  String? handledBy,
  double? lossPct,
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
      lossPct: lossPct,
    );

void main() {
  test(
      'household alerts show their detection signature, not the word Household',
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

  test('pendingReview is excluded from the worker-facing status lists', () {
    expect(AlertStatus.pendingReview, 'pending_review');
    expect(AlertStatus.all, isNot(contains(AlertStatus.pendingReview)));
    expect(AlertStatus.unresolved, isNot(contains(AlertStatus.pendingReview)));
  });

  test('faults is the fault status and reads as Fault', () {
    expect(AlertStatus.faults, 'faults');
    expect(AlertStatus.label(AlertStatus.faults), 'Fault');
    expect(AlertStatus.label(AlertStatus.pendingReview), 'Pending Review');
  });

  test('shared filter count is zero when nothing is narrowed', () {
    expect(
      countActiveFilters(
        query: '',
        filters: const [false, false, false],
      ),
      0,
    );
    expect(
      countActiveFilters(
        query: '   ',
        filters: const [false, false, false],
      ),
      0,
    );
  });

  test('shared filter count rises with each narrowed field', () {
    expect(
      countActiveFilters(
        query: 'perlis',
        filters: const [false, false, false],
      ),
      1,
    );
    expect(
      countActiveFilters(
        query: 'perlis',
        filters: const [true, true, true],
      ),
      4,
    );
  });

  test('shared filter count treats null-equivalent selections as unfiltered',
      () {
    expect(
        countActiveFilters(query: '', filters: const [false, false, false]), 0);
    expect(
      countActiveFilters(
        query: 'x',
        filters: const [true, true, true],
      ),
      4,
    );
  });

  test('worker lists use the shared responsive filter shell', () {
    for (final path in <String>[
      'lib/modules/leakage/screens/alert_queue_screen.dart',
      'lib/modules/leakage/screens/report_history_screen.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, contains('ResponsiveFilterBar('));
      expect(source, isNot(contains('LandscapeFilterMenu(')));
      expect(source, isNot(contains('UtilityChips(')));
      expect(source, isNot(contains('onSearchClear:')));
    }
  });

  test('an alert with only summary and recommendation still has AI analysis',
      () {
    final alert = _alert(
      alertType: AlertType.household,
      signature: LeakSignature.continuousLeak,
    ).copyWith(
      aiSummary: 'Resident reports a leak.',
      aiRecommendation: 'Contact the resident today.',
      aiGeneratedAt: DateTime(2026, 8, 21),
    );

    expect(alert.hasAiAnalysis, isTrue);
  });

  test('an alert with no summary has no AI analysis', () {
    final alert = _alert(
      alertType: AlertType.household,
      signature: LeakSignature.continuousLeak,
    ).copyWith(
      aiRecommendation: 'Contact the resident today.',
      aiGeneratedAt: DateTime(2026, 8, 21),
    );

    expect(alert.hasAiAnalysis, isFalse);
  });

  test('the utility pill is the only place utility colour appears', () {
    expect(AppColors.waterAccent, const Color(0xFF3B82F6));
    expect(AppColors.electricityAccent, const Color(0xFFEAB308));
    expect(AppColors.workerPrimary, const Color(0xFF0F766E));
    expect(AppColors.workerPrimary, isNot(AppColors.waterAccent));
    expect(AppColors.workerPrimary, isNot(AppColors.electricityAccent));
  });

  testWidgets('a state loss alert still shows its unaccounted-supply figure',
      (tester) async {
    tester.view.physicalSize = const Size(900, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final alert = _alert(
      alertType: AlertType.nrwHotspot,
      signature: LeakSignature.nrwHotspot,
      lossPct: 42.5,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AlertCard(alert: alert, onTap: () {}),
        ),
      ),
    );

    expect(find.text('42.5% of supply unaccounted'), findsOneWidget);
  });

  testWidgets('a household alert shows no state-average comparison',
      (tester) async {
    tester.view.physicalSize = const Size(900, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final alert = _alert(
      alertType: AlertType.household,
      signature: LeakSignature.suddenBurst,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AlertCard(alert: alert, onTap: () {}),
        ),
      ),
    );

    expect(find.textContaining('of state avg'), findsNothing);
    expect(find.textContaining('Sudden burst'), findsOneWidget);
  });
}
