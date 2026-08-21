import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../dataset/models/models.dart';
import '../../electricity/models/electricity_models.dart';
import '../../electricity/services/electricity_data_service.dart';
import '../data/leakage_repository.dart';
import '../models/ai_anomaly_analysis.dart';
import '../models/alert.dart';
import '../models/anomaly_case.dart';
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

class AppState extends ChangeNotifier with WidgetsBindingObserver {
  final BaselineService baseline;
  final NrwService nrw;
  final ElectricityLossService electricityLoss;
  final ElectricityDataService electricityData;
  final LeakageRepository repository;
  final SimulationService simulation;
  final Explainer explainer;
  AnomalyAiService? _anomalyAi;

  List<Alert> _alerts = [];
  List<AnomalyCase> _anomalyCases = [];
  List<Report> _reports = [];
  Map<String, String> _workerNames = {};
  List<ElectricityRecord> _electricityRecords = [];
  bool _loading = true;
  final Set<int> _generatingAnomalyIds = {};
  final Set<String> _generatingAnomalyCaseIds = {};
  Timer? _pollTimer;

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
  List<AnomalyCase> get anomalyCases => _anomalyCases;
  List<Report> get reports => _reports;
  Map<String, String> get workerNames => _workerNames;
  bool get loading => _loading;

  bool isGeneratingAnomalyAnalysis(int alertId) =>
      _generatingAnomalyIds.contains(alertId);

  bool isGeneratingAnomalyCaseAnalysis(String caseId) =>
      _generatingAnomalyCaseIds.contains(caseId);

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

  Future<AnomalyAiGenerationResult> generateAnomalyCaseAnalysis(
      AnomalyCase anomalyCase) async {
    final caseId = anomalyCase.id;
    if (caseId == null) {
      throw StateError('Cannot analyze a case without an id.');
    }
    if (!_generatingAnomalyCaseIds.add(caseId)) {
      throw const AnomalyAiException(
        AnomalyAiFailure.alreadyRunning,
        'Anomaly analysis is already running.',
      );
    }
    notifyListeners();

    try {
      final analysis = await anomalyAi.generateCase(anomalyCase);
      final index = _anomalyCases.indexWhere((item) => item.id == caseId);
      if (index != -1) {
        _anomalyCases[index] = _anomalyCases[index].copyWith(
          aiSummary: analysis.summary,
          aiPossibleCause: analysis.possibleCause,
          aiSeverityAssessment: analysis.severityAssessment,
          aiRecommendation: analysis.recommendation,
          aiConfidence: analysis.confidence,
          aiGeneratedAt: analysis.generatedAt,
        );
        notifyListeners();
      }
      return AnomalyAiGenerationResult(analysis: analysis, persisted: true);
    } finally {
      _generatingAnomalyCaseIds.remove(caseId);
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
    return filed.map((r) => r.createdAt).reduce((a, b) => a.isAfter(b) ? a : b);
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

  List<Alert> investigatingAlerts([Utility? utility]) =>
      _bySeverity(_alerts.where((a) =>
          a.status == AlertStatus.investigating &&
          _matchesUtility(a, utility)));

  List<Alert> notFixedAlerts([Utility? utility]) => _bySeverity(_alerts.where(
      (a) => a.status == AlertStatus.notFixed && _matchesUtility(a, utility)));

  List<Alert> solvedAlerts([Utility? utility]) => _bySeverity(_alerts.where(
      (a) => a.status == AlertStatus.resolved && _matchesUtility(a, utility)));

  /// Alerts for the admin Oversight Alert Queue tab. Mirrors
  /// [reportsFiltered]: each argument narrows the list, null means "all".
  List<Alert> alertsFiltered({
    Utility? utility,
    String? state,
    String? status,
    String? severity,
  }) {
    return _bySeverity(_alerts.where((a) {
      if (!_matchesUtility(a, utility)) return false;
      if (state != null && a.state != state) return false;
      if (status != null && a.status != status) return false;
      if (severity != null && a.severity != severity) return false;
      return true;
    }));
  }

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

  // --- Admin review queue ---
  //
  // An alert only appears once its AI write-up has been saved, so the admin
  // never decides without the analysis in front of them. That makes a loading
  // state unnecessary: an alert mid-generation simply is not in the list yet.
  static bool awaitingDecision(Alert alert) =>
      alert.status == AlertStatus.pendingReview && alert.aiGeneratedAt != null;

  static bool inReviewQueue(Alert alert) =>
      awaitingDecision(alert) || alert.status == AlertStatus.faults;

  List<Alert> reviewQueue({String? sourceScope}) => _bySeverity(_alerts.where(
      (a) =>
          inReviewQueue(a) &&
          (sourceScope == null || a.sourceScope == sourceScope)));

  Future<void> approveAlert(int alertId) async {
    await repository.updateAlertStatus(alertId, AlertStatus.pending);
    await refresh();
  }

  Future<void> rejectAlert(int alertId) async {
    await repository.updateAlertStatus(alertId, AlertStatus.faults);
    await refresh();
  }

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
    try {
      await refresh();
      await _seedDemoDataIfNeeded();
    } catch (e) {
      // Alerts/reports/worker data (and the one-time demo seed) are
      // admin/worker-facing and may be unavailable to some sessions (e.g. a
      // customer role without RLS access to those tables). Don't let that
      // block the rest of the app — screens that don't touch this data
      // (like the customer report form) must still be usable.
      debugPrint('AppState.init: could not load alerts/reports data: $e');
    }
    _loading = false;
    notifyListeners();
    _startPolling();
  }

  void _startPolling() {
    WidgetsBinding.instance.addObserver(this);
    _pollTimer ??= Timer.periodic(const Duration(seconds: 3), (_) => refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _pollTimer ??=
          Timer.periodic(const Duration(seconds: 3), (_) => refresh());
    } else {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
    try {
      await repository.readings();
    } catch (_) {
      debugPrint('Could not refresh the local reading backup.');
    }
    _alerts = await repository.alerts();
    _anomalyCases = await repository.anomalyCases();
    _reports = await repository.reports();
    _workerNames = await repository.workerNames();
    notifyListeners();
  }

  Future<void> submitHouseholdProblem({
    required Utility utility,
    required String state,
    required String address,
    required String category,
    required String description,
    required DateTime occurredAt,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      throw StateError('Please sign in before submitting a report.');
    }
    final householdId =
        (user.userMetadata?['household_id'] as String?)?.trim().isNotEmpty ==
                true
            ? (user.userMetadata?['household_id'] as String).trim()
            : 'H-305';
    final now = DateTime.now();
    await repository.insertAlert(Alert(
      alertType: AlertType.household,
      state: state,
      detectedAt: now,
      signature: LeakSignature.continuousLeak,
      severity: Severity.medium,
      explanation: '$category reported at $address: $description',
      status: AlertStatus.pendingReview,
      householdId: householdId,
      sourceScope: AlertSourceScope.household,
      utilityType: utility == Utility.water ? 'water' : 'electricity',
      sourceKey: 'household:${user.id}:${now.microsecondsSinceEpoch}',
    ));
    await refresh();
  }

  /// Equipment needing attention, worst first — the Mall tier's source.
  /// 'Critical' is a technician's own flag on the equipment record, so this
  /// list always agrees with what Inventory shows for the same node.
  static const _attentionStatuses = ['Critical', 'Warning', 'Maintenance'];

  static bool needsAttention(EquipmentNode node) =>
      _attentionStatuses.contains(node.status);

  static String equipmentSeverity(String status) {
    switch (status) {
      case 'Critical':
        return Severity.high;
      case 'Warning':
        return Severity.medium;
      default:
        return Severity.low;
    }
  }

  Future<SimulationOutcome> simulate(
      LeakScenario scenario, String state) async {
    final outcome = await simulation.run(scenario, state);
    await refresh();
    return outcome;
  }

  Future<void> updateAlertStatus(int alertId, String status,
      {String? handledBy, String? handledById}) async {
    await repository.updateAlertStatus(alertId, status,
        handledBy: handledBy, handledById: handledById);
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
