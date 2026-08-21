import '../../leakage/models/alert.dart';

/// Search + narrowing for the admin review queue. Kept free of Flutter types
/// so the filtering rules can be tested without pumping a widget.
class ReviewQueueFilter {
  static bool matches({
    required String query,
    required Alert alert,
    String? selectedState,
    String? selectedSeverity,
    String? selectedStatus,
  }) {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isNotEmpty) {
      final haystack = [
        alert.state,
        alert.title,
        alert.facilityName,
        alert.equipmentName,
      ].whereType<String>().join(' ').toLowerCase();
      if (!haystack.contains(trimmed)) return false;
    }
    if (selectedState != null && alert.state != selectedState) return false;
    if (selectedSeverity != null && alert.severity != selectedSeverity) {
      return false;
    }
    if (selectedStatus != null && alert.status != selectedStatus) return false;
    return true;
  }
}
