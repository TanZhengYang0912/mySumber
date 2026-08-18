import 'package:flutter/foundation.dart';

import '../../electricity/models/electricity_models.dart';
import '../../electricity/services/electricity_data_service.dart';
import '../data/leakage_repository.dart';
import '../models/ai_anomaly_analysis.dart';
import '../models/alert.dart';
import '../models/report.dart';
import '../services/baseline_service.dart';
import '../services/anomaly_ai_service.dart';
import '../services/electricity_loss_service.dart';
import '../services/explainer.dart';
import '../services/nrw_service.dart';
import '../services/simulation_service.dart';

class AnomalyAiGenerationResult {
  final AiAnomalyAnalysis analysis;
  final bool persisted;

  const AnomalyAiGenerationResult({
    required this.analysis,
    required this.persisted,
  });
}

class AppState extends ChangeNotifier {
  final BaselineService baseline;
  final NrwService nrw;
  final ElectricityLossService electricityLoss;
  final ElectricityDataService electricityData;
  final LeakageRepository repository;
  final SimulationService simulation;
  final Explainer explainer;
  AnomalyAiService? _anomalyAi;

  List<Alert> _alerts = [];
  List<Report> _reports = [];
  List<ElectricityRecord> _electricityRecords = [];
  bool _loading = true;
  final Set<int> _generatingAnomalyIds = {};

  AppState({
    required this.baseline,
    required this.nrw,
    required this.repository,
    required this.simulation,
    ElectricityLossService? electricityLoss,
    ElectricityDataService? electricityData,
    Explainer? explainer,
    AnomalyAiService? anomalyAi,
  })  : electricityLoss = electricityLoss ?? ElectricityLossService(),
        electricityData = electricityData ?? ElectricityDataService(),
        explainer = explainer ?? Explainer(),
        _anomalyAi = anomalyAi;

  AnomalyAiService get anomalyAi => _anomalyAi ??= AnomalyAiService();

  String get workerName => 'Worker X';
  List<Alert> get alerts => _alerts;
  List<Report> get reports => _reports;
  bool get loading => _loading;

  bool isGeneratingAnomalyAnalysis(int alertId) =>
      _generatingAnomalyIds.contains(alertId);

  Future<AnomalyAiGenerationResult> generateAnomalyAnalysis(Alert alert) async {
    final alertId = alert.id;
    if (alertId == null) {
      throw StateError('Cannot analyze an alert without an id.');
    }
    if (!_generatingAnomalyIds.add(alertId)) {
      throw const AnomalyAiException(
        AnomalyAiFailure.alreadyRunning,
        'Anomaly analysis is already running.',
      );
    }
    notifyListeners();

    try {
      final analysis = await anomalyAi.generate(alert);
      final index = _alerts.indexWhere((item) => item.id == alertId);
      if (index != -1) {
        _alerts[index] = _alerts[index].copyWith(
          aiSummary: analysis.summary,
          aiPossibleCause: analysis.possibleCause,
          aiSeverityAssessment: analysis.severityAssessment,
          aiRecommendation: analysis.recommendation,
          aiConfidence: analysis.confidence,
          aiGeneratedAt: analysis.generatedAt,
        );
        notifyListeners();
      }

      return AnomalyAiGenerationResult(
        analysis: analysis,
        persisted: true,
      );
    } finally {
      _generatingAnomalyIds.remove(alertId);
      notifyListeners();
    }
  }

  // --- Per-utility queues, used by the worker Water / Electricity tabs ---
  List<Alert> unresolvedFor(Utility u) =>
      _bySeverity(_alerts.where((a) => a.utility == u && a.isUnresolved));
  List<Alert> resolvedFor(Utility u) => _bySeverity(
      _alerts.where((a) => a.utility == u && a.status == AlertStatus.resolved));

  /// When an alert was actually closed out. Alerts carry no `resolved_at`
  /// column, so the timestamp comes from the newest report filed against it —
  /// which is the moment a worker submitted the outcome that changed the
  /// status. Null when no report exists (status was changed by hand).
  DateTime? resolvedAtFor(int alertId) {
    final filed =
        _reports.where((r) => r.alertId == alertId).toList(growable: false);
    if (filed.isEmpty) return null;
    return filed
        .map((r) => r.createdAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);
  }

  List<Report> reportsFor(Utility u) {
    final ids = _alerts
        .where((a) => a.utility == u)
        .map((a) => a.id)
        .whereType<int>()
        .toSet();
    return _reports.where((r) => ids.contains(r.alertId)).toList();
  }

  // --- Admin Oversight status groups: optional utility filter, null = all ---
  bool _matchesUtility(Alert a, Utility? utility) =>
      utility == null || a.utility == utility;

  List<Alert> pendingAlerts([Utility? utility]) => _bySeverity(_alerts.where(
      (a) => a.status == AlertStatus.pending && _matchesUtility(a, utility)));

  List<Alert> investigatingAlerts([Utility? utility]) => _bySeverity(
      _alerts.where((a) =>
          a.status == AlertStatus.investigating && _matchesUtility(a, utility)));

  List<Alert> notFixedAlerts([Utility? utility]) => _bySeverity(_alerts.where(
      (a) => a.status == AlertStatus.notFixed && _matchesUtility(a, utility)));

  List<Alert> solvedAlerts([Utility? utility]) => _bySeverity(_alerts.where(
      (a) => a.status == AlertStatus.resolved && _matchesUtility(a, utility)));

  List<Alert> faultAlerts([Utility? utility]) => _bySeverity(_alerts.where(
      (a) => a.status == AlertStatus.faults && _matchesUtility(a, utility)));

  /// Reports for the admin Oversight Reports tab, filtered by the alert's
  /// utility/state and the report's own outcome.
  List<Report> reportsFiltered(
      {Utility? utility, String? state, String? outcome}) {
    final alertById = {
      for (final a in _alerts)
        if (a.id != null) a.id!: a,
    };
    return _reports.where((r) {
      final alert = alertById[r.alertId];
      if (utility != null && (alert == null || alert.utility != utility)) {
        return false;
      }
      if (state != null && (alert == null || alert.state != state)) {
        return false;
      }
      if (outcome != null && r.outcome != outcome) return false;
      return true;
    }).toList();
  }

  // --- "Already reported" sets for the admin Abnormal Production screen ---
  Set<String> get reportedWaterStates =>
      _alerts.where((a) => a.isNrw).map((a) => a.state).toSet();
  Set<String> get reportedElectricityStates =>
      _alerts.where((a) => a.isElectricityHotspot).map((a) => a.state).toSet();
  Set<String> get reportedTamperingKeys => _alerts
      .where((a) => a.isElectricityTampering)
      .map((a) => monthKey(a.detectedAt))
      .toSet();

  List<ElectricityRecord> get tamperingCandidates =>
      _electricityRecords.where((r) => r.isAnomaly).toList();

  static String monthKey(DateTime d) => '${d.year}-${d.month}';

  static const _severityRank = {
    Severity.high: 3,
    Severity.medium: 2,
    Severity.low: 1,
  };

  /// Default queue order: latest first, then severity (high → low),
  /// then state name A–Z.
  List<Alert> _bySeverity(Iterable<Alert> source) {
    final list = source.toList();
    list.sort((a, b) {
      final byDate = b.detectedAt.compareTo(a.detectedAt);
      if (byDate != 0) return byDate;
      final bySeverity = (_severityRank[b.severity] ?? 0)
          .compareTo(_severityRank[a.severity] ?? 0);
      if (bySeverity != 0) return bySeverity;
      return a.state.compareTo(b.state);
    });
    return list;
  }

  Future<void> init() async {
    await baseline.load();
    await nrw.load();
    await electricityLoss.load();
    _electricityRecords = await electricityData.loadRecords();
    await refresh();
    await _seedDemoDataIfNeeded();
    _loading = false;
    notifyListeners();
  }

  Future<void> _seedDemoDataIfNeeded() async {
    await _seedWaterIfNeeded();
    await _seedElectricityIfNeeded();
  }

  Future<void> _seedWaterIfNeeded() async {
    final waterAlerts = _alerts.where((a) => !a.isElectricity).toList();
    final waterAlertIds = waterAlerts.map((a) => a.id).whereType<int>().toSet();
    final hasWaterReports =
        _reports.any((r) => waterAlertIds.contains(r.alertId));
    if (hasWaterReports) return;

    final now = DateTime.now();

    Future<int> aid(int idx, Alert Function() build) async {
      final desired = build();
      if (idx < waterAlerts.length && waterAlerts[idx].id != null) {
        final existing = waterAlerts[idx];
        if (existing.facilityName == null || existing.equipmentName == null) {
          await repository.updateAlertLocation(
            id: existing.id!,
            equipmentNodeId: desired.equipmentNodeId,
            facilityName: desired.facilityName,
            facilityCity: desired.facilityCity,
            equipmentName: desired.equipmentName,
          );
        }
        return existing.id!;
      }
      return repository.insertAlert(desired);
    }

    final w1 = await aid(
        0,
        () => Alert(
              alertType: AlertType.nrwHotspot,
              state: 'Selangor',
              detectedAt: now.subtract(const Duration(days: 1)),
              signature: LeakSignature.nrwHotspot,
              severity: Severity.high,
              explanation:
                  'High NRW detected in Selangor water distribution network.',
              status: AlertStatus.pending,
              facilityName: '1 Utama Shopping Centre',
              facilityCity: 'Petaling Jaya',
              equipmentName: 'Main Water Pump A1',
              producedMld: 3200,
              billedMld: 2100,
              lossMld: 1100,
              lossPct: 34.4,
              dataYear: 2024,
            ));
    await repository.insertReport(Report(
      alertId: w1,
      workerName: 'Worker',
      findings: 'Pipe burst detected at main junction.',
      actionTaken: 'Temporary bypass installed at Km 12.',
      outcome: ReportOutcome.notFixed,
      createdAt: now.subtract(const Duration(days: 1)),
      updatedAt: now.subtract(const Duration(days: 1)),
    ));

    final w2 = await aid(
        1,
        () => Alert(
              alertType: AlertType.nrwHotspot,
              state: 'Kedah',
              detectedAt: now.subtract(const Duration(days: 3)),
              signature: LeakSignature.nrwHotspot,
              severity: Severity.medium,
              explanation: 'NRW loss above threshold in Kedah.',
              status: AlertStatus.resolved,
              facilityName: 'Aman Central',
              facilityCity: 'Alor Setar',
              equipmentName: 'Cooling Tower Valve',
              producedMld: 1800,
              billedMld: 1500,
              lossMld: 300,
              lossPct: 16.7,
              dataYear: 2024,
            ));
    await repository.insertReport(Report(
      alertId: w2,
      workerName: 'Admin',
      findings: 'Leaking valve replaced at distribution point B.',
      actionTaken: 'Valve replaced and pressure test completed.',
      outcome: ReportOutcome.fixed,
      createdAt: now.subtract(const Duration(days: 3)),
      updatedAt: now.subtract(const Duration(days: 3)),
    ));

    final w3 = await aid(
        2,
        () => Alert(
              alertType: AlertType.nrwHotspot,
              state: 'Johor',
              detectedAt: now.subtract(const Duration(days: 5)),
              signature: LeakSignature.nrwHotspot,
              severity: Severity.low,
              explanation: 'Minor NRW variance detected in Johor.',
              status: AlertStatus.resolved,
              facilityName: 'Mid Valley Southkey',
              facilityCity: 'Johor Bahru',
              equipmentName: 'Main Water Pump A1',
              producedMld: 2500,
              billedMld: 2350,
              lossMld: 150,
              lossPct: 6.0,
              dataYear: 2024,
            ));
    await repository.insertReport(Report(
      alertId: w3,
      workerName: 'Worker',
      findings: 'No visible leak found. Meter recalibrated.',
      actionTaken: 'Meter recalibration completed.',
      outcome: ReportOutcome.fixed,
      createdAt: now.subtract(const Duration(days: 5)),
      updatedAt: now.subtract(const Duration(days: 5)),
    ));

    await refresh();
  }

  Future<void> _seedElectricityIfNeeded() async {
    final elecAlerts = _alerts.where((a) => a.isElectricity).toList();
    final elecAlertIds = elecAlerts.map((a) => a.id).whereType<int>().toSet();
    final hasElecReports =
        _reports.any((r) => elecAlertIds.contains(r.alertId));
    if (hasElecReports) return;

    final now = DateTime.now();

    Future<int> aid(int idx, Alert Function() build) async {
      final desired = build();
      if (idx < elecAlerts.length && elecAlerts[idx].id != null) {
        final existing = elecAlerts[idx];
        if (existing.facilityName == null || existing.equipmentName == null) {
          await repository.updateAlertLocation(
            id: existing.id!,
            equipmentNodeId: desired.equipmentNodeId,
            facilityName: desired.facilityName,
            facilityCity: desired.facilityCity,
            equipmentName: desired.equipmentName,
          );
        }
        return existing.id!;
      }
      return repository.insertAlert(desired);
    }

    final e1 = await aid(
        0,
        () => Alert(
              alertType: AlertType.electricityHotspot,
              state: 'Kelantan',
              detectedAt: now.subtract(const Duration(days: 2)),
              signature: LeakSignature.electricityHotspot,
              severity: Severity.medium,
              explanation:
                  'Above-average electricity loss detected in Kelantan grid.',
              status: AlertStatus.resolved,
              facilityName: 'AEON Mall Kota Bharu',
              facilityCity: 'Kota Bharu',
              equipmentName: 'Sub-Transformer B2',
              producedMld: 8500,
              billedMld: 7200,
              lossMld: 1300,
              lossPct: 15.3,
              dataYear: 2024,
            ));
    await repository.insertReport(Report(
      alertId: e1,
      workerName: 'Admin',
      findings: 'No findings after on-site check.',
      actionTaken: 'Meter readings verified against billing records.',
      outcome: ReportOutcome.fixed,
      createdAt: now.subtract(const Duration(days: 2)),
      updatedAt: now.subtract(const Duration(days: 2)),
    ));

    final e2 = await aid(
        1,
        () => Alert(
              alertType: AlertType.electricityHotspot,
              state: 'Kelantan',
              detectedAt: now.subtract(const Duration(days: 2)),
              signature: LeakSignature.electricityHotspot,
              severity: Severity.high,
              explanation:
                  'Suspected meter tampering pattern in Kelantan substation.',
              status: AlertStatus.notFixed,
              facilityName: 'AEON Mall Kota Bharu',
              facilityCity: 'Kota Bharu',
              equipmentName: 'Sub-Transformer B2',
              producedMld: 9200,
              billedMld: 7000,
              lossMld: 2200,
              lossPct: 23.9,
              dataYear: 2024,
            ));
    await repository.insertReport(Report(
      alertId: e2,
      workerName: 'Worker',
      findings: 'extrcityuyhj — logged by field worker.',
      actionTaken: 'Flagged for re-inspection next cycle.',
      outcome: ReportOutcome.notFixed,
      createdAt: now.subtract(const Duration(days: 2)),
      updatedAt: now.subtract(const Duration(days: 2)),
    ));

    final e3 = await aid(
        2,
        () => Alert(
              alertType: AlertType.electricityHotspot,
              state: 'Terengganu',
              detectedAt: now.subtract(const Duration(days: 4)),
              signature: LeakSignature.electricityHotspot,
              severity: Severity.low,
              explanation: 'Minor distribution loss in Terengganu zone.',
              status: AlertStatus.resolved,
              facilityName: 'Paya Bunga Square',
              facilityCity: 'Kuala Terengganu',
              equipmentName: 'Sub-Transformer B2',
              producedMld: 7100,
              billedMld: 6600,
              lossMld: 500,
              lossPct: 7.0,
              dataYear: 2024,
            ));
    await repository.insertReport(Report(
      alertId: e3,
      workerName: 'Worker',
      findings: 'Replaced faulty valve at station 3.',
      actionTaken: 'Distribution cable splice repaired at substation.',
      outcome: ReportOutcome.fixed,
      createdAt: now.subtract(const Duration(days: 4)),
      updatedAt: now.subtract(const Duration(days: 4)),
    ));

    await refresh();
  }

  Future<void> refresh() async {
    _alerts = await repository.alerts();
    _reports = await repository.reports();
    notifyListeners();
  }

  Future<bool> reportCustomerElectricityIssue({
    required String scenarioLabel,
    required bool isTampering,
    required String state,
  }) async {
    final alert = Alert(
      alertType: isTampering
          ? AlertType.electricityTampering
          : AlertType.electricityHotspot,
      state: state,
      detectedAt: DateTime.now(),
      signature: isTampering
          ? LeakSignature.electricityTampering
          : LeakSignature.electricityHotspot,
      severity: isTampering ? Severity.high : Severity.medium,
      explanation: isTampering
          ? 'Consumer reported suspected meter tampering in $state. Recommend meter audit and site inspection.'
          : 'Consumer reported: $scenarioLabel in $state. Recommend inspection of the distribution point.',
      producedMld: 0,
      billedMld: 0,
      lossMld: 0,
      lossPct: 0,
      dataYear: DateTime.now().year,
    );
    await repository.insertAlert(alert);
    await refresh();
    return true;
  }

  // --- Water: admin reports a per-state NRW hotspot ---
  Future<bool> reportAbnormalState(NrwResult result) async {
    if (reportedWaterStates.contains(result.state)) return false;
    final alert = Alert(
      alertType: AlertType.nrwHotspot,
      state: result.state,
      detectedAt: DateTime.now(),
      signature: LeakSignature.nrwHotspot,
      severity: result.severity,
      explanation: explainer.describeNrw(result, nrw.nationalLossPct),
      producedMld: result.producedMld,
      billedMld: result.billedMld,
      lossMld: result.lossMld,
      lossPct: result.lossPct,
      dataYear: result.year,
    );
    await repository.insertAlert(alert);
    await refresh();
    return true;
  }

  // --- Electricity: admin reports a per-state loss hotspot ---
  Future<bool> reportElectricityState(NrwResult result) async {
    if (reportedElectricityStates.contains(result.state)) return false;
    final alert = Alert(
      alertType: AlertType.electricityHotspot,
      state: result.state,
      detectedAt: DateTime.now(),
      signature: LeakSignature.electricityHotspot,
      severity: result.severity,
      explanation: explainer.describeElectricityLoss(
          result, electricityLoss.nationalLossPct),
      producedMld: result.producedMld,
      billedMld: result.billedMld,
      lossMld: result.lossMld,
      lossPct: result.lossPct,
      dataYear: result.year,
    );
    await repository.insertAlert(alert);
    await refresh();
    return true;
  }

  // --- Electricity: admin reports a national tampering spike (a month) ---
  Future<bool> reportElectricityTampering(ElectricityRecord record) async {
    if (reportedTamperingKeys.contains(monthKey(record.date))) return false;
    final lossPct =
        record.supply == 0 ? 0.0 : record.losses / record.supply * 100;
    final alert = Alert(
      alertType: AlertType.electricityTampering,
      state: 'Malaysia',
      detectedAt: record.date,
      signature: LeakSignature.electricityTampering,
      severity: _tamperingSeverity(lossPct),
      explanation:
          explainer.describeTampering(record.date.year, lossPct, record.losses),
      producedMld: record.supply,
      billedMld: record.consumption,
      lossMld: record.losses,
      lossPct: lossPct,
      dataYear: record.date.year,
    );
    await repository.insertAlert(alert);
    await refresh();
    return true;
  }

  String _tamperingSeverity(double lossPct) {
    if (lossPct > 10) return Severity.high;
    if (lossPct > 6) return Severity.medium;
    return Severity.low;
  }

  Future<SimulationOutcome> simulate(
      LeakScenario scenario, String state) async {
    final outcome = await simulation.run(scenario, state);
    await refresh();
    return outcome;
  }

  Future<void> updateAlertStatus(int alertId, String status) async {
    await repository.updateAlertStatus(alertId, status);
    await refresh();
  }

  Future<void> saveReport(Report report) async {
    await repository.insertReport(report);
    await refresh();
  }

  /// All reports including hidden ones, for the admin oversight screen.
  Future<List<Report>> allReportsForOversight() =>
      repository.reports(includeDeleted: true);

  Future<void> setReportHidden(int reportId, bool hidden) async {
    await repository.setReportDeleted(reportId, hidden);
    await refresh();
  }
}
