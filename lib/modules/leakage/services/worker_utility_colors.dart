import 'package:flutter/material.dart';

import '../../../theme/tokens.dart';
import '../models/alert.dart';

Color workerUtilityPrimary(Utility utility) {
  return utility == Utility.electricity
      ? AppColors.electricityAccent
      : AppColors.workerPrimary;
}

Color workerUtilitySurface(Utility utility) {
  return utility == Utility.electricity
      ? AppColors.electricitySurface
      : AppColors.workerSurface;
}
