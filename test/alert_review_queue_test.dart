import 'package:flutter_test/flutter_test.dart';

import 'package:mysumber/modules/admin/services/abnormal_production_filter.dart';
import 'package:mysumber/modules/leakage/models/alert.dart';
import 'package:mysumber/modules/leakage/state/app_state.dart';

Alert _alert({
  required String status,
  DateTime? aiGeneratedAt,
  String sourceScope = AlertSourceScope.state,
}) =>
    Alert(
      alertType: AlertType.nrwHotspot,
      state: 'Perlis',
      detectedAt: DateTime(2026, 8, 21),
      signature: LeakSignature.nrwHotspot,
      severity: Severity.high,
      explanation: 'Test alert',
      status: status,
      sourceScope: sourceScope,
      aiGeneratedAt: aiGeneratedAt,
    );

void main() {
  test('an alert awaiting a decision must be pending_review AND have AI', () {
    expect(
      AppState.awaitingDecision(_alert(
        status: AlertStatus.pendingReview,
        aiGeneratedAt: DateTime(2026, 8, 21),
      )),
      isTrue,
    );
  });

  test('an alert whose AI has not landed is not shown for decision', () {
    expect(
      AppState.awaitingDecision(_alert(status: AlertStatus.pendingReview)),
      isFalse,
    );
  });

  test('an approved alert no longer awaits a decision', () {
    expect(
      AppState.awaitingDecision(_alert(
        status: AlertStatus.pending,
        aiGeneratedAt: DateTime(2026, 8, 21),
      )),
      isFalse,
    );
  });

  test('a faulted alert no longer awaits a decision', () {
    expect(
      AppState.awaitingDecision(_alert(
        status: AlertStatus.faults,
        aiGeneratedAt: DateTime(2026, 8, 21),
      )),
      isFalse,
    );
  });

  test('the review queue keeps faulted alerts on screen', () {
    expect(
        AppState.inReviewQueue(_alert(
          status: AlertStatus.faults,
          aiGeneratedAt: DateTime(2026, 8, 21),
        )),
        isTrue);
    expect(
        AppState.inReviewQueue(_alert(
          status: AlertStatus.pendingReview,
          aiGeneratedAt: DateTime(2026, 8, 21),
        )),
        isTrue);
    expect(
        AppState.inReviewQueue(_alert(
          status: AlertStatus.pending,
          aiGeneratedAt: DateTime(2026, 8, 21),
        )),
        isFalse);
  });

  test('an empty query matches every alert', () {
    expect(
      ReviewQueueFilter.matches(
          query: '', alert: _alert(status: AlertStatus.pendingReview)),
      isTrue,
    );
  });

  test('the query matches on state, case-insensitively', () {
    final alert = _alert(status: AlertStatus.pendingReview);
    expect(ReviewQueueFilter.matches(query: 'perl', alert: alert), isTrue);
    expect(ReviewQueueFilter.matches(query: 'johor', alert: alert), isFalse);
  });

  test('state and severity narrow independently', () {
    final alert = _alert(status: AlertStatus.pendingReview);
    expect(
      ReviewQueueFilter.matches(
          query: '', alert: alert, selectedState: 'Perlis'),
      isTrue,
    );
    expect(
      ReviewQueueFilter.matches(
          query: '', alert: alert, selectedState: 'Johor'),
      isFalse,
    );
    expect(
      ReviewQueueFilter.matches(
          query: '', alert: alert, selectedSeverity: Severity.high),
      isTrue,
    );
    expect(
      ReviewQueueFilter.matches(
          query: '', alert: alert, selectedSeverity: Severity.low),
      isFalse,
    );
  });

  test('status narrows the queue to pending-review or faulted rows', () {
    final pending = _alert(status: AlertStatus.pendingReview);
    final faulted = _alert(status: AlertStatus.faults);

    // Null means "all", which is what Clear filters restores.
    expect(ReviewQueueFilter.matches(query: '', alert: pending), isTrue);
    expect(ReviewQueueFilter.matches(query: '', alert: faulted), isTrue);

    expect(
      ReviewQueueFilter.matches(
          query: '',
          alert: pending,
          selectedStatus: AlertStatus.pendingReview),
      isTrue,
    );
    expect(
      ReviewQueueFilter.matches(
          query: '',
          alert: faulted,
          selectedStatus: AlertStatus.pendingReview),
      isFalse,
    );
    expect(
      ReviewQueueFilter.matches(
          query: '', alert: faulted, selectedStatus: AlertStatus.faults),
      isTrue,
    );
  });
}
