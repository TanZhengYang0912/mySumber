import '../../dataset/models/models.dart';
import '../models/alert.dart';
import '../models/reading.dart';
import 'detection_engine.dart';
import 'nrw_service.dart';

class Explainer {
  String describeNrw(NrwResult r, double nationalPct) {
    final pct = r.lossPct.toStringAsFixed(1);
    final national = nationalPct.toStringAsFixed(1);
    return '${r.state} loses $pct% of treated water in ${r.year}, '
        'above the national average of $national%. A loss this high points to '
        'distribution-network leakage rather than metering error. '
        'Recommend a field inspection of the district network.';
  }

  String describeElectricityLoss(NrwResult r, double nationalPct) {
    final pct = r.lossPct.toStringAsFixed(1);
    final national = nationalPct.toStringAsFixed(1);
    return '${r.state} shows $pct% of supplied electricity unaccounted for in '
        '${r.year}, above the national average of $national%. A gap this large '
        'between supply and metered consumption points to distribution losses '
        'or meter tampering. Recommend a field audit of the distribution grid.';
  }

  /// Legacy display text for equipment needing attention. New Mall alerts are
  /// created by the baseline usage trigger, which includes its measured
  /// baseline and multiple in the stored explanation.
  String describeEquipmentAnomaly(EquipmentNode node) {
    final facility = node.facilityName ?? 'an unlinked facility';
    final flagged = node.status == 'Critical'
        ? 'flagged Critical during maintenance inspection'
        : 'placed under maintenance';
    return '${node.nodeName} at $facility was $flagged. Equipment in this '
        'state risks unmetered loss until serviced. Recommend an on-site '
        'inspection of the unit.';
  }

  String describeTampering(int year, double lossPct, double lossKwh) {
    final pct = lossPct.toStringAsFixed(1);
    final kwh = lossKwh.round();
    return 'National electricity losses spiked to $pct% of supply '
        '($kwh kWh) in this period of $year — a statistically abnormal jump '
        '(z-score above the tampering threshold) versus the surrounding months. '
        'Consistent with large-scale meter tampering or an unmetered draw. '
        'Recommend a grid-level investigation.';
  }

  String describe(Reading reading, DetectionResult result) {
    final ratioText = result.ratio.toStringAsFixed(1);
    final actual = result.actualL.round();
    final baseline = result.baselineL.round();
    final base =
        'Household ${reading.householdId} in ${reading.state} used $actual L/day '
        'against an expected $baseline L/day (${ratioText}x the state average).';

    switch (result.signature) {
      case LeakSignature.suddenBurst:
        return '$base The usage jumped sharply in a single day, consistent with '
            'a burst pipe or major fitting failure. Recommend urgent on-site inspection.';
      case LeakSignature.continuousLeak:
        return '$base Overnight flow stayed high when usage should fall to near '
            'zero, indicating a continuous underground leak rather than normal use. '
            'Recommend on-site inspection.';
      case LeakSignature.creepingLeak:
        return '$base Usage has been rising steadily over several days, consistent '
            'with a slow leak such as a running toilet or dripping cistern. '
            'Recommend follow-up inspection.';
      case LeakSignature.seasonalSpike:
        return '$base Usage is moderately elevated but stable and may reflect '
            'seasonal demand (hot weather, gardening). Flagged as low severity for review.';
      default:
        return base;
    }
  }
}
