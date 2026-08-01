import 'package:flutter/material.dart';

bool usesCustomerPhoneLandscape(Size viewport) {
  return viewport.shortestSide < 600 && viewport.width > viewport.height;
}
