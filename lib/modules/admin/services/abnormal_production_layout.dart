import 'package:flutter/material.dart';

import 'admin_tablet_layout.dart';

bool usesAbnormalProductionSplitView(Size viewport) {
  return adminLayoutModeFor(viewport) == AdminLayoutMode.tabletLandscape;
}
