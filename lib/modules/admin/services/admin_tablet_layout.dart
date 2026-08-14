import 'package:flutter/material.dart';

enum AdminLayoutMode {
  phonePortrait,
  phoneLandscape,
  tabletPortrait,
  tabletLandscape,
}

AdminLayoutMode adminLayoutModeFor(Size viewport) {
  if (viewport.shortestSide < 600) {
    return viewport.width > viewport.height
        ? AdminLayoutMode.phoneLandscape
        : AdminLayoutMode.phonePortrait;
  }

  return viewport.width >= 840
      ? AdminLayoutMode.tabletLandscape
      : AdminLayoutMode.tabletPortrait;
}

bool usesAdminCompactHeader(Size viewport) {
  return adminLayoutModeFor(viewport) == AdminLayoutMode.phoneLandscape;
}
