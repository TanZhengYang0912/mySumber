import 'package:flutter_test/flutter_test.dart';

import 'package:mysumber/modules/leakage/models/alert.dart';
import 'package:mysumber/modules/leakage/screens/style.dart';
import 'package:mysumber/modules/leakage/services/report_presets.dart';

Alert _alert({required String alertType, required String signature}) => Alert(
      alertType: alertType,
      state: 'Selangor',
      detectedAt: DateTime(2026, 8, 1),
      signature: signature,
      severity: Severity.high,
      explanation: 'Test alert',
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

  test('resolved alerts label when the work was finished', () {
    expect(
      resolvedLabel(AlertStatus.resolved, DateTime(2026, 8, 3, 14, 20)),
      'Resolved at 3 Aug 2026, 14:20',
    );
  });

  test('no resolution line for unresolved alerts or missing reports', () {
    expect(
      resolvedLabel(AlertStatus.investigating, DateTime(2026, 8, 3, 14, 20)),
      isNull,
    );
    expect(resolvedLabel(AlertStatus.resolved, null), isNull);
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
}
