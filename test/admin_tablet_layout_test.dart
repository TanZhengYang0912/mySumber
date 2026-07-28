import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysumber/modules/admin/services/admin_tablet_layout.dart';

void main() {
  test('classifies every approved Admin viewport mode', () {
    expect(
      adminLayoutModeFor(const Size(914, 411)),
      AdminLayoutMode.phoneLandscape,
    );
    expect(
      adminLayoutModeFor(const Size(411, 914)),
      AdminLayoutMode.phonePortrait,
    );
    expect(
      adminLayoutModeFor(const Size(768, 1024)),
      AdminLayoutMode.tabletPortrait,
    );
    expect(
      adminLayoutModeFor(const Size(1024, 768)),
      AdminLayoutMode.tabletLandscape,
    );
  });
}
