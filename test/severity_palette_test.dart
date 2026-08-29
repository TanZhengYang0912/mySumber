import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mysumber/modules/leakage/models/alert.dart';
import 'package:mysumber/modules/leakage/screens/style.dart';
import 'package:mysumber/modules/leakage/state/app_state.dart';
import 'package:mysumber/theme/tokens.dart';

void main() {
  test('equipment status and alert severity render off one palette', () {
    expect(
      equipmentStatusColor('Critical'),
      severityColor(AppState.equipmentSeverity('Critical')),
    );
    expect(
      equipmentStatusColor('Warning'),
      severityColor(AppState.equipmentSeverity('Warning')),
    );
  });

  test('medium severity is orange rather than amber', () {
    expect(severityColor(Severity.medium), const Color(0xFFEA580C));
    expect(equipmentStatusColor('Warning'), const Color(0xFFEA580C));
  });

  test('water and electricity no longer share one colour', () {
    expect(AppColors.electricityAccent, isNot(AppColors.waterAccent));
    expect(AppColors.electricitySurface, isNot(AppColors.waterSurface));
  });

  // Bright yellow was chosen over the darker amber deliberately, with the
  // knowledge that it reads at roughly 2:1 on white as pill text. Pinned
  // here so a later "accessibility fix" is a decision, not a drive-by.
  test('electricity is yellow-500 on a yellow-100 surface', () {
    expect(AppColors.electricityAccent, const Color(0xFFEAB308));
    expect(AppColors.electricitySurface, const Color(0xFFFEF9C3));
  });
}
