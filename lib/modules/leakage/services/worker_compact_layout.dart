import 'package:flutter/material.dart';

/// Worker navigation becomes a rail only on a phone held horizontally.
/// Tablet and portrait layouts keep their existing navigation patterns.
bool usesWorkerPhoneLandscape(Size viewport) {
  return viewport.shortestSide < 600 && viewport.width > viewport.height;
}
