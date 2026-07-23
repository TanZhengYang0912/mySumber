import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../electricity/models/electricity_models.dart';
import '../../electricity/services/electricity_data_service.dart';
import '../data/leakage_repository.dart';
import '../../../config.dart';
import '../models/ai_summary.dart';
import '../models/alert.dart';
import '../models/report.dart';
import '../models/service_review.dart';
import '../services/baseline_service.dart';
import '../services/electricity_loss_service.dart';
import '../services/explainer.dart';
import '../services/nrw_service.dart';
import '../services/simulation_service.dart';

enum SummaryResult {
  success,
  belowThreshold,
  upToDate,
  networkError,
  apiError,
  parseError,
  storageError,
  alreadyRunning,
}

enum ReviewSubmitResult {
  success,
  networkError,
  storageError,
}

class _ReviewMetrics {
  final int valid;
  final int newValidSinceSummary;
  const _ReviewMetrics({required this.valid, required this.newValidSinceSummary});
}

class AppState extends ChangeNotifier {
  final BaselineService baseline;
  final NrwService nrw;
  final ElectricityLossService electricityLoss;
  final ElectricityDataService electricityData;
  final LeakageRepository repository;
  final SimulationService simulation;
  final Explainer explainer;

  List<Alert> _alerts = [];
  List<Report> _reports = [];
  List<ServiceReview> _reviews = [];
  AiSummary? _latestSummary;
  List<ElectricityRecord> _electricityRecords = [];
  bool _loading = true;
  bool _generatingSummary = false;
  _ReviewMetrics? _cachedMetrics;

  AppState({
    required this.baseline,
    required this.nrw,
    required this.repository,
    required this.simulation,
    ElectricityLossService? electricityLoss,
    ElectricityDataService? electricityData,
    Explainer? explainer,
  })  : electricityLoss = electricityLoss ?? ElectricityLossService(),
        electricityData = electricityData ?? ElectricityDataService(),
        explainer = explainer ?? Explainer();

  static const int minReviewsForSummary = 5;
  static const Duration _groqTimeout = Duration(seconds: 30);

  // A review counts toward the AI-summary threshold only if it carries
  // signal beyond a star rating — either selected tags or a written comment.
  static bool _isValidReview(ServiceReview r) =>
      r.tags.isNotEmpty || r.comment.trim().isNotEmpty;

  String get workerName => 'Worker X';
  List<Alert> get alerts => _alerts;
  List<Report> get reports => _reports;
  // Unmodifiable view — callers can iterate/count without being able to mutate
  // the internal list and silently invalidate the metrics cache.
  List<ServiceReview> get reviews => UnmodifiableListView(_reviews);
  AiSummary? get latestSummary => _latestSummary;
  bool get loading => _loading;
  bool get isGeneratingSummary => _generatingSummary;

  // Single-pass computation of derived review metrics, memoised until
  // refresh() invalidates it. All threshold / stale-check getters share this,
  // so a full rebuild pays for at most one _reviews traversal.
  _ReviewMetrics get _metrics {
    final cached = _cachedMetrics;
    if (cached != null) return cached;
    var valid = 0;
    var newValid = 0;
    final cutoff = _latestSummary?.generatedAt;
    for (final r in _reviews) {
      if (!_isValidReview(r)) continue;
      valid++;
      if (cutoff != null && r.createdAt.isAfter(cutoff)) newValid++;
    }
    return _cachedMetrics =
        _ReviewMetrics(valid: valid, newValidSinceSummary: newValid);
  }

  int get validReviewCount => _metrics.valid;
  bool get canGenerateSummary => _metrics.valid >= minReviewsForSummary;
  int get reviewsUntilSummary =>
      (minReviewsForSummary - _metrics.valid).clamp(0, minReviewsForSummary);

  /// Detailed reviews added since the last summary. Timestamp-based, so this
  /// stays accurate even when total valid reviews exceed the 50-analysis cap.
  int get newReviewsSinceSummary => _metrics.newValidSinceSummary;

  bool get isSummaryUpToDate =>
      _latestSummary != null && _metrics.newValidSinceSummary == 0;

  Set<int> reviewedAlertIds(String email) => _reviews
      .where((r) => r.consumerEmail == email && r.alertId != null)
      .map((r) => r.alertId!)
      .toSet();

  // --- Per-utility queues, used by the worker Water / Electricity tabs ---
  List<Alert> unresolvedFor(Utility u) =>
      _bySeverity(_alerts.where((a) => a.utility == u && a.isUnresolved));
  List<Alert> resolvedFor(Utility u) => _bySeverity(
      _alerts.where((a) => a.utility == u && a.status == AlertStatus.resolved));

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

  List<Alert> ongoingAlerts([Utility? utility]) => _bySeverity(_alerts.where(
      (a) =>
          (a.status == AlertStatus.investigating ||
              a.status == AlertStatus.notFixed) &&
          _matchesUtility(a, utility)));

  List<Alert> solvedAlerts([Utility? utility]) => _bySeverity(_alerts.where(
      (a) => a.status == AlertStatus.resolved && _matchesUtility(a, utility)));

  List<Alert> faultAlerts([Utility? utility]) => _bySeverity(_alerts.where(
      (a) => a.status == AlertStatus.faults && _matchesUtility(a, utility)));

  /// Reports for the admin Oversight Reports tab, filtered by the alert's
  /// utility/state and the report's own outcome.
  List<Report> reportsFiltered({Utility? utility, String? state, String? outcome}) {
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
    await _seedReviewsIfNeeded();
    _loading = false;
    notifyListeners();
  }

  Future<void> _seedDemoDataIfNeeded() async {
    await _seedWaterIfNeeded();
    await _seedElectricityIfNeeded();
  }

  Future<void> _seedWaterIfNeeded() async {
    final waterAlerts = _alerts.where((a) => !a.isElectricity).toList();
    final waterAlertIds =
        waterAlerts.map((a) => a.id).whereType<int>().toSet();
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

    final w1 = await aid(0, () => Alert(
          alertType: AlertType.nrwHotspot,
          state: 'Selangor',
          detectedAt: now.subtract(const Duration(days: 1)),
          signature: LeakSignature.nrwHotspot,
          severity: Severity.high,
          explanation: 'High NRW detected in Selangor water distribution network.',
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

    final w2 = await aid(1, () => Alert(
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

    final w3 = await aid(2, () => Alert(
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
    final elecAlertIds =
        elecAlerts.map((a) => a.id).whereType<int>().toSet();
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

    final e1 = await aid(0, () => Alert(
          alertType: AlertType.electricityHotspot,
          state: 'Kelantan',
          detectedAt: now.subtract(const Duration(days: 2)),
          signature: LeakSignature.electricityHotspot,
          severity: Severity.medium,
          explanation: 'Above-average electricity loss detected in Kelantan grid.',
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

    final e2 = await aid(1, () => Alert(
          alertType: AlertType.electricityHotspot,
          state: 'Kelantan',
          detectedAt: now.subtract(const Duration(days: 2)),
          signature: LeakSignature.electricityHotspot,
          severity: Severity.high,
          explanation: 'Suspected meter tampering pattern in Kelantan substation.',
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

    final e3 = await aid(2, () => Alert(
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
    try {
      _reviews = await repository.reviews();
      // Invalidate immediately — the next await lets other code run, and any
      // metrics getter it calls must not read the stale cache against the new
      // _reviews list.
      _cachedMetrics = null;
      _latestSummary = await repository.latestAiSummary();
      _cachedMetrics = null;
    } catch (_) {
      // service_reviews / ai_summaries tables not yet created — skip gracefully
    }
    _cachedMetrics = null;
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

  Future<ReviewSubmitResult> submitReview(ServiceReview review) async {
    try {
      await repository.insertReview(review);
    } on TimeoutException {
      return ReviewSubmitResult.networkError;
    } on SocketException {
      return ReviewSubmitResult.networkError;
    } on http.ClientException {
      return ReviewSubmitResult.networkError;
    } catch (e, st) {
      if (kDebugMode) debugPrint('submitReview insert error: $e\n$st');
      return ReviewSubmitResult.storageError;
    }
    // Insert already succeeded — a refresh failure shouldn't downgrade the
    // user-facing result. Their review is safely stored.
    try {
      await refresh();
    } catch (e, st) {
      if (kDebugMode) debugPrint('submitReview post-insert refresh error: $e\n$st');
    }
    return ReviewSubmitResult.success;
  }

  Future<SummaryResult> generateAiSummary() async {
    // Mutex guard: prevent concurrent generation across screen recreations.
    // The button is disabled while running, but a re-mount after navigating
    // away would otherwise let admin fire a second parallel Groq call.
    if (_generatingSummary) return SummaryResult.alreadyRunning;
    _generatingSummary = true;
    notifyListeners();
    try {
    // Snapshot reviews up-front so a concurrent submitReview() cannot
    // desync the analysed batch from the stored reviewCount.
    final validReviews = _reviews.where(_isValidReview).toList();
    if (validReviews.length < minReviewsForSummary) {
      return SummaryResult.belowThreshold;
    }

    final analyzed = validReviews.take(50).toList();
    final analyzedCount = analyzed.length;

    // Timestamp-based staleness check: up to date iff no valid review has been
    // created after the last summary. Works correctly even when the number of
    // valid reviews exceeds the 50-review analysis window (fixes the boundary
    // bug where count comparison couldn't detect a shifted analysis set).
    if (isSummaryUpToDate) {
      return SummaryResult.upToDate;
    }

    final reviewsText = analyzed.asMap().entries.map((e) {
      final r = e.value;
      final tags = r.tags.isEmpty ? 'none' : r.tags.join(', ');
      final comment = r.comment.isEmpty ? 'No comment' : r.comment;
      return 'Review ${e.key + 1}: ${r.stars}/5 stars. Tags: $tags. Comment: "$comment"';
    }).join('\n');

    // 1. HTTP call with timeout.
    http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
            headers: {
              'Authorization': 'Bearer ${GroqConfig.apiKey}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': 'llama3-8b-8192',
              'messages': [
                {
                  'role': 'system',
                  'content':
                      'You are a professional service quality analyst for a Malaysian water and electricity utility company. Analyze repair service reviews. When a review\'s star rating contradicts its comment content (e.g. high stars but negative comments, or low stars but positive comments), prioritize the comment and selected tags over the star rating for quality assessment. Always respond with valid JSON in this exact format: {"summary": "2-3 sentence overall assessment", "pros": ["pro 1", "pro 2", "pro 3"], "cons": ["con 1", "con 2"]}. Keep each pro/con under 5 words.',
                },
                {
                  'role': 'user',
                  'content':
                      'Analyze these $analyzedCount repair service reviews from mySumber customers:\n\n$reviewsText\n\nProvide a balanced assessment focusing on repair quality and customer experience.',
                },
              ],
              'response_format': {'type': 'json_object'},
              'max_tokens': 512,
              'temperature': 0.3,
            }),
          )
          .timeout(_groqTimeout);
    } on TimeoutException {
      return SummaryResult.networkError;
    } on SocketException {
      return SummaryResult.networkError;
    } on http.ClientException {
      return SummaryResult.networkError;
    }

    if (response.statusCode != 200) return SummaryResult.apiError;

    // 2. Parse response defensively.
    String summaryText;
    List<String> pros;
    List<String> cons;
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = data['choices'] as List?;
      if (choices == null || choices.isEmpty) return SummaryResult.parseError;
      final message = choices.first as Map<String, dynamic>?;
      final content = (message?['message'] as Map?)?['content'] as String?;
      if (content == null || content.isEmpty) return SummaryResult.parseError;
      final result = jsonDecode(content) as Map<String, dynamic>;
      summaryText = (result['summary'] as String?)?.trim() ?? '';
      if (summaryText.isEmpty) return SummaryResult.parseError;
      pros = List<String>.from(result['pros'] ?? const []);
      cons = List<String>.from(result['cons'] ?? const []);
    } catch (e, st) {
      if (kDebugMode) debugPrint('AI summary parse error: $e\n$st');
      return SummaryResult.parseError;
    }

    // 3. Persist. Store the analysed count (what AI actually saw), not the
    // raw total, so the "Based on N" display and up-to-date check line up.
    try {
      await repository.insertAiSummary(
        summaryText: summaryText,
        pros: pros,
        cons: cons,
        reviewCount: analyzedCount,
      );
    } on Exception catch (e, st) {
      if (kDebugMode) debugPrint('AI summary storage error: $e\n$st');
      return SummaryResult.storageError;
    }

    // Insert already succeeded — a refresh failure shouldn't mask that.
    // Absorb any error so generateAiSummary honours its "never throws" contract.
    try {
      await refresh();
    } catch (e, st) {
      if (kDebugMode) debugPrint('AI summary post-insert refresh error: $e\n$st');
    }
    return SummaryResult.success;
    } finally {
      _generatingSummary = false;
      notifyListeners();
    }
  }

  Future<void> _seedReviewsIfNeeded() async {
    List<ServiceReview> existing;
    try {
      existing = await repository.reviews();
    } catch (_) {
      return; // table doesn't exist yet
    }
    if (existing.isNotEmpty) return;

    final now = DateTime.now();
    final seeds = [
      ServiceReview(
        consumerEmail: 'ahmad@example.com',
        stars: 5,
        tags: ['Fast Response', 'Perfectly Fixed', 'Professional'],
        comment: 'Technician arrived within 2 hours and fixed the burst pipe completely. Very impressed with the speed and quality!',
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      ServiceReview(
        consumerEmail: 'siti@example.com',
        stars: 4,
        tags: ['Perfectly Fixed', 'Great Attitude'],
        comment: 'Good service overall. The leak was fully resolved. Slight delay but the work quality was excellent.',
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      ServiceReview(
        consumerEmail: 'razif@example.com',
        stars: 2,
        tags: ['Still Leaking', 'Slow Response'],
        comment: 'Still a small drip after the repair. Called back and was told they would return next week. Disappointing.',
        createdAt: now.subtract(const Duration(days: 3)),
      ),
      ServiceReview(
        consumerEmail: 'nurul@example.com',
        stars: 5,
        tags: ['Fast Response', 'Thorough Check', 'Professional'],
        comment: 'Outstanding! The team did a thorough inspection of the whole pipe system and found an additional hidden crack.',
        createdAt: now.subtract(const Duration(days: 4)),
      ),
      ServiceReview(
        consumerEmail: 'hafiz@example.com',
        stars: 3,
        tags: ['Slow Response', 'Poor Fix'],
        comment: 'Waited 3 days for someone to come. The fix seemed rushed — hoping it holds up over the next few weeks.',
        createdAt: now.subtract(const Duration(days: 5)),
      ),
      ServiceReview(
        consumerEmail: 'mei@example.com',
        stars: 5,
        tags: ['Perfectly Fixed', 'Great Attitude', 'Fast Response'],
        comment: 'Excellent experience. The worker explained everything clearly and showed me the repaired section before leaving.',
        createdAt: now.subtract(const Duration(days: 6)),
      ),
      ServiceReview(
        consumerEmail: 'rajan@example.com',
        stars: 1,
        tags: ['Overcharged', 'Unprofessional'],
        comment: 'Was charged extra fees not mentioned in the initial quote. When I asked, the worker was rude. Will escalate.',
        createdAt: now.subtract(const Duration(days: 7)),
      ),
      ServiceReview(
        consumerEmail: 'lily@example.com',
        stars: 4,
        tags: ['Fast Response', 'Thorough Check'],
        comment: 'Quick response and the repair looks solid. Happy with the service, just wished they cleaned up after.',
        createdAt: now.subtract(const Duration(days: 8)),
      ),
    ];

    try {
      for (final r in seeds) {
        await repository.insertReview(r);
      }
    } catch (_) {
      return; // table doesn't exist yet
    }
    await refresh();
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
      explanation:
          explainer.describeElectricityLoss(result, electricityLoss.nationalLossPct),
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

  Future<SimulationOutcome> simulate(LeakScenario scenario, String state) async {
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
