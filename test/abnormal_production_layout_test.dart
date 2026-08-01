import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysumber/modules/admin/services/abnormal_production_layout.dart';

void main() {
  test('uses the split workspace only on landscape tablets', () {
    expect(
      usesAbnormalProductionSplitView(const Size(1024, 768)),
      isTrue,
    );
    expect(
      usesAbnormalProductionSplitView(const Size(768, 1024)),
      isFalse,
    );
    expect(
      usesAbnormalProductionSplitView(const Size(914, 411)),
      isFalse,
    );
  });
}
