import '../models/alert.dart';

/// Common site findings, offered as one-tap chips on the report form.
List<String> findingsPresets(Utility utility) =>
    utility == Utility.electricity
        ? const [
            'Transformer running over rated load.',
            'Cable joint insulation degraded.',
            'Meter shows signs of interference.',
            'No fault found on site.',
          ]
        : const [
            'Pipe burst at main junction.',
            'Valve seal leaking steadily.',
            'No visible leak on site.',
            'Meter reading does not match flow.',
          ];

/// Common remedial actions, offered as one-tap chips on the report form.
List<String> actionPresets(Utility utility) => utility == Utility.electricity
    ? const [
        'Cable joint replaced.',
        'Meter recalibrated.',
        'Readings verified against billing records.',
        'Flagged for re-inspection next cycle.',
      ]
    : const [
        'Temporary bypass installed.',
        'Valve replaced.',
        'Pressure test completed.',
        'Meter recalibration completed.',
      ];

/// Adds [preset] to whatever the worker has already typed, so chips compose
/// into a full description instead of overwriting each other.
String appendPreset(String current, String preset) {
  final existing = current.trimRight();
  return existing.isEmpty ? preset : '$existing $preset';
}
