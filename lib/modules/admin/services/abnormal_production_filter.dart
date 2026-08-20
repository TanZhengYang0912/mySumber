class AnomalyReportingStatus {
  static const reported = 'reported';
  static const unreported = 'unreported';
  static const all = [reported, unreported];

  static String label(String value) =>
      value == reported ? 'Reported' : 'Unreported';
}

class AbnormalProductionFilter {
  static bool matches({
    required String query,
    required String searchableText,
    required String state,
    required String severity,
    required bool reported,
    String? selectedState,
    String? selectedSeverity,
    String? selectedReportingStatus,
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isNotEmpty &&
        !searchableText.toLowerCase().contains(normalizedQuery)) {
      return false;
    }
    if (selectedState != null && state != selectedState) return false;
    if (selectedSeverity != null && severity != selectedSeverity) return false;
    final reportingStatus = reported
        ? AnomalyReportingStatus.reported
        : AnomalyReportingStatus.unreported;
    return selectedReportingStatus == null ||
        reportingStatus == selectedReportingStatus;
  }
}
