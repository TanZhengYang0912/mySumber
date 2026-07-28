# Admin Tablet AI Review Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver a responsive Admin AI Review workspace that uses a navigation rail and master-detail review layout on landscape tablets while retaining the current phone UI.

**Architecture:** Keep responsive shell navigation in AppShell, with an IndexedStack preserving Admin tab state. Keep review query and ordering logic pure in AnomalyReviewFilter. ReviewManagementScreen chooses a phone or tablet composition with LayoutBuilder, while a reusable detail-content widget serves the tablet pane and the existing phone route.

**Tech Stack:** Flutter Material 3, Dart, Provider, flutter_test, intl.

## Global Constraints

- Work only on the Admin review UI, its filter service, targeted tests, and the shared AppShell navigation.
- Use 840dp as the tablet-layout breakpoint; widths below it retain bottom navigation and the existing route-to-detail flow.
- Do not change Supabase schemas, CSV assets, authentication, user/worker UI, or alert-review business outcomes.
- Preserve the existing AI-analysis generation and Oversight navigation actions.
- Keep all interactive controls at least 48dp in hit-target height or provide equivalent padded tap regions.

---

## File structure

- Modify: `lib/main.dart` — responsive Admin rail/bottom navigation and preserved tab bodies.
- Modify: `lib/modules/admin/services/anomaly_review_filter.dart` — high-severity criterion and deterministic review priority.
- Modify: `lib/modules/admin/screens/review_management_screen.dart` — responsive filters, compact summary, result selection, phone list, and tablet master-detail layout.
- Modify: `lib/modules/admin/screens/anomaly_review_detail_screen.dart` — reusable stateful detail content usable in a route or a pane.
- Modify: `test/anomaly_review_test.dart` — query, ordering, and dependent-filter tests.

### Task 1: Make the anomaly query support severity and review priority

**Files:**

- Modify: `lib/modules/admin/services/anomaly_review_filter.dart:3-61`
- Modify: `test/anomaly_review_test.dart:45-124`

**Interfaces:**

- Consumes: `Alert.status`, `Alert.severity`, `Alert.detectedAt`, and the existing location/utility fields.
- Produces: `AnomalyReviewQuery.highSeverityOnly` and an `AnomalyReviewFilter.apply` result ordered by severity, pending status, then newest detection time.

- [ ] **Step 1: Add failing severity and ordering tests**

  Add a high-severity investigating fixture and these tests to `test/anomaly_review_test.dart`:

  ```dart
  test('combines ongoing status with the high-severity filter', () {
    final result = AnomalyReviewFilter.apply(
      alerts,
      const AnomalyReviewQuery(
        statuses: {AlertStatus.investigating, AlertStatus.notFixed},
        highSeverityOnly: true,
      ),
    );

    expect(result.map((alert) => alert.id), [5]);
  });

  test('orders review results by severity, pending status, then recency', () {
    final result = AnomalyReviewFilter.apply(
      alerts,
      AnomalyReviewQuery(statuses: AlertStatus.all.toSet()),
    );

    expect(result.take(3).map((alert) => alert.id), [1, 5, 2]);
  });
  ```

  Extend `_fixtureAlerts()` with alert id 5: high severity, `AlertStatus.investigating`, and detected at `DateTime.utc(2026, 7, 24)`.

- [ ] **Step 2: Run the focused test to verify the new API is missing**

  Run: `flutter test test/anomaly_review_test.dart`

  Expected: compilation fails because `highSeverityOnly` is not a parameter of `AnomalyReviewQuery`.

- [ ] **Step 3: Implement severity filtering and ordering**

  Add the query field and apply it before sorting:

  ```dart
  final bool highSeverityOnly;

  const AnomalyReviewQuery({
    this.statuses = const {
      AlertStatus.pending,
      AlertStatus.investigating,
      AlertStatus.notFixed,
    },
    this.highSeverityOnly = false,
    this.utility,
    this.state,
    this.facilityName,
    this.equipmentName,
  });
  ```

  Use these ranking helpers in `AnomalyReviewFilter`:

  ```dart
  static const _statusRank = {
    AlertStatus.pending: 2,
    AlertStatus.investigating: 1,
    AlertStatus.notFixed: 1,
  };

  static int _compareForReview(Alert a, Alert b) {
    final bySeverity =
        (_severityRank[b.severity] ?? 0).compareTo(_severityRank[a.severity] ?? 0);
    if (bySeverity != 0) return bySeverity;
    final byStatus =
        (_statusRank[b.status] ?? 0).compareTo(_statusRank[a.status] ?? 0);
    if (byStatus != 0) return byStatus;
    final byDate = b.detectedAt.compareTo(a.detectedAt);
    if (byDate != 0) return byDate;
    return (a.id ?? -1).compareTo(b.id ?? -1);
  }
  ```

  Filter with `if (query.highSeverityOnly && alert.severity != Severity.high) return false;` and sort using `_compareForReview`.

- [ ] **Step 4: Run the filter tests**

  Run: `flutter test test/anomaly_review_test.dart`

  Expected: PASS.

- [ ] **Step 5: Commit the pure query change**

  ```bash
  git add lib/modules/admin/services/anomaly_review_filter.dart test/anomaly_review_test.dart
  git commit -m "feat: add high-severity anomaly review filter"
  ```

### Task 2: Extract reusable AI Review detail content

**Files:**

- Modify: `lib/modules/admin/screens/anomaly_review_detail_screen.dart:13-86`

**Interfaces:**

- Consumes: `int alertId` and `AppState.alerts`.
- Produces: `AnomalyReviewDetailContent(alertId: int, pane: bool)`, which renders the existing alert evidence, AI analysis, generation state, error state, and Oversight action without a Scaffold.

- [ ] **Step 1: Add a widget test seam**

  Give the extracted content a stable root key:

  ```dart
  const Key('anomaly-review-detail-content')
  ```

  Use that key on the scrolling detail body, so the tablet screen can assert the selected alert’s body is present without relying on typography.

- [ ] **Step 2: Extract the content widget**

  Retain `AnomalyReviewDetailScreen` as the route wrapper:

  ```dart
  class AnomalyReviewDetailScreen extends StatelessWidget {
    final int alertId;

    const AnomalyReviewDetailScreen({super.key, required this.alertId});

    @override
    Widget build(BuildContext context) => Scaffold(
          backgroundColor: AppColors.canvas,
          appBar: AppBar(
            title: const Text('AI Anomaly Review'),
            backgroundColor: AppColors.adminPrimary,
            foregroundColor: Colors.white,
          ),
          body: AnomalyReviewDetailContent(alertId: alertId),
        );
  }
  ```

  Move the existing state and helper methods into public `AnomalyReviewDetailContent extends StatefulWidget`. It accepts `pane = false`; pane mode uses the same ListView body with `EdgeInsets.zero`, does not create a nested Scaffold, and shows `Center(child: Text('Alert unavailable.'))` when the live alert disappears.

- [ ] **Step 3: Reset ephemeral generation state when the selected alert changes**

  Add `didUpdateWidget` to the extracted state:

  ```dart
  @override
  void didUpdateWidget(covariant AnomalyReviewDetailContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.alertId != widget.alertId) {
      _sessionAnalysis = null;
      _errorMessage = null;
      _generating = false;
      _sessionAnalysisPersisted = null;
    }
  }
  ```

  This prevents one alert’s temporary generation/error state appearing in the next alert’s pane.

- [ ] **Step 4: Run formatting and existing AI tests**

  Run: `dart format lib/modules/admin/screens/anomaly_review_detail_screen.dart && flutter test test/anomaly_ai_test.dart`

  Expected: formatter makes no remaining changes after a second run and AI tests pass.

- [ ] **Step 5: Commit the reusable detail component**

  ```bash
  git add lib/modules/admin/screens/anomaly_review_detail_screen.dart
  git commit -m "refactor: reuse anomaly review detail content"
  ```

### Task 3: Build the tablet master-detail AI Review workspace

**Files:**

- Modify: `lib/modules/admin/screens/review_management_screen.dart:18-523`

**Interfaces:**

- Consumes: `AnomalyReviewFilter.apply`, `AnomalyReviewDetailContent`, `AppState.alerts`, and the existing status/location filter lists.
- Produces: a phone single-column review screen below 840dp and a tablet toolbar/list/detail workspace at or above 840dp.

- [ ] **Step 1: Add tablet selection state and query wiring**

  Add the state fields:

  ```dart
  static const _tabletBreakpoint = 840.0;
  bool _highSeverityOnly = false;
  int? _selectedAlertId;
  bool _selectionSyncScheduled = false;
  ```

  Pass `highSeverityOnly: _highSeverityOnly` into `AnomalyReviewQuery`. Build a selection helper that returns the retained selected result when it is in the filtered results; otherwise it returns `null` for an empty list or `results.first`.

- [ ] **Step 2: Synchronise invalid selection after filters or live updates**

  Add this post-frame synchronisation helper and call it with the current filtered results during the tablet build:

  ```dart
  void _syncSelection(List<Alert> results) {
    final previousId = _selectedAlertId;
    final nextId = results.isEmpty ? null : results.first.id;
    final selectedStillMatches =
        _selectedAlertId != null && results.any((alert) => alert.id == _selectedAlertId);
    if (selectedStillMatches || _selectedAlertId == nextId || _selectionSyncScheduled) {
      return;
    }
    _selectionSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _selectedAlertId = nextId;
        _selectionSyncScheduled = false;
      });
      if (previousId != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('The selected anomaly changed with the latest results.'),
            ),
          );
      }
    });
  }
  ```

  When a user taps a result, set `_selectedAlertId` to its id. When filters remove it, the helper selects the priority-first result; when there are none, it clears the selection. The detail pane must use `AnomalyReviewDetailContent(alertId: selected.id!, pane: true)` only for a non-null selected id.

- [ ] **Step 3: Implement the two-row tablet filter toolbar**

  Refactor the current filters into reusable status, utility, severity, and location-control builders. On tablet, render:

  ```dart
  Column(
    children: [
      Row(children: [
        Expanded(child: _statusChips(compact: true)),
        const SizedBox(width: 12),
        _utilityChips(compact: true),
        const SizedBox(width: 8),
        FilterChip(
          label: const Text('High severity'),
          selected: _highSeverityOnly,
          onSelected: (selected) =>
              setState(() => _highSeverityOnly = selected),
        ),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
          child: _dropdown(
            label: 'State / Federal Territory',
            value: _state,
            values: states,
            onChanged: (value) => setState(() {
              _state = value;
              _facilityName = null;
              _equipmentName = null;
            }),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _dropdown(
            label: 'Shopping Mall',
            value: _facilityName,
            values: facilities,
            onChanged: (value) => setState(() {
              _facilityName = value;
              _equipmentName = null;
            }),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _dropdown(
            label: 'Equipment',
            value: _equipmentName,
            values: equipment,
            onChanged: (value) =>
                setState(() => _equipmentName = value),
          ),
        ),
        TextButton(onPressed: _clearFilters, child: const Text('Clear')),
      ]),
    ],
  )
  ```

  Keep the existing vertical filter composition for phone widths. Extend `_clearFilters` to set `_highSeverityOnly = false`.

- [ ] **Step 4: Implement the 400dp list and flexible detail composition**

  In `LayoutBuilder`, branch on `constraints.maxWidth >= _tabletBreakpoint`. The tablet branch uses:

  ```dart
  Row(
    children: [
      SizedBox(width: 400, child: _tabletResultList(results, selectedAlertId)),
      const VerticalDivider(width: 1),
      Expanded(
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 840),
            child: selectedAlert == null
                ? _tabletEmptyDetail()
                : AnomalyReviewDetailContent(
                    key: ValueKey(selectedAlert.id),
                    alertId: selectedAlert.id!,
                    pane: true,
                  ),
          ),
        ),
      ),
    ],
  )
  ```

  Make result items 72–88dp high and keep facility, location/equipment, utility, severity, status, and date together. Give the selected item a visible `AppColors.adminPrimary` outline. Retain the existing card and route-push behavior for the phone branch.

- [ ] **Step 5: Replace the tablet summary cards with compact contextual counts**

  Derive `results.length`, the pending count, and the high-severity count from the filtered results. Render them as small, non-interactive text/count pairs in the tablet header. Do not render `_summary` in the tablet branch; retain it for phones.

- [ ] **Step 6: Verify formatting, analysis, and focused tests**

  Run:

  ```bash
  dart format lib/modules/admin/screens/review_management_screen.dart
  flutter analyze
  flutter test test/anomaly_review_test.dart test/anomaly_ai_test.dart
  ```

  Expected: formatting is clean, `flutter analyze` has no diagnostics, and both test files pass.

- [ ] **Step 7: Commit the responsive AI Review screen**

  ```bash
  git add lib/modules/admin/screens/review_management_screen.dart
  git commit -m "feat: add tablet AI review workspace"
  ```

### Task 4: Add responsive Admin shell navigation with preserved tab state

**Files:**

- Modify: `lib/main.dart:250-301`

**Interfaces:**

- Consumes: the existing `_screens`, `_navItems`, `_currentIndex`, and `rolePrimary`.
- Produces: labelled Admin `NavigationRail` at 840dp and above, existing bottom navigation for all other cases, and retained screen state.

- [ ] **Step 1: Replace the one-child body with an IndexedStack**

  Create the shared body once:

  ```dart
  final screenStack = IndexedStack(
    index: _currentIndex,
    children: _screens,
  );
  ```

  This retains AI Review filter values, selection, and scroll position while the Admin visits another destination.

- [ ] **Step 2: Render the Admin-only rail at the agreed breakpoint**

  Wrap the scaffold in a `LayoutBuilder` and calculate:

  ```dart
  final useAdminRail =
      widget.userRole == 'admin' && constraints.maxWidth >= 840;
  ```

  In rail mode, put the navigation rail and the expanded IndexedStack in a Row, using:

  ```dart
  NavigationRail(
    selectedIndex: _currentIndex,
    onDestinationSelected: (index) => setState(() => _currentIndex = index),
    labelType: NavigationRailLabelType.all,
    destinations: [
      for (final item in _navItems)
        NavigationRailDestination(
          icon: Icon(item.icon),
          selectedIcon: Icon(item.icon),
          label: Text(item.label),
        ),
    ],
  )
  ```

  Set `bottomNavigationBar: useAdminRail ? null : _buildBottomNavigation(primary)`; extract the existing bottom navigation markup into that helper unchanged.

- [ ] **Step 3: Run static analysis**

  Run: `dart format lib/main.dart && flutter analyze`

  Expected: formatter is clean and analysis has no diagnostics.

- [ ] **Step 4: Perform responsive manual verification**

  Run: `flutter run`

  Verify all of the following in an Admin session:

  1. At a phone width and 768dp portrait width, bottom navigation and the existing drill-in detail page remain available.
  2. At 840dp and a large landscape tablet width, the labelled rail replaces bottom navigation on all five Admin destinations.
  3. In AI Review, choose Ongoing and High severity, then State, Mall, and Equipment; confirm the result list is their intersection and Clear resets every criterion.
  4. Select a result, change filters so it no longer matches, and confirm the priority-first replacement or the empty detail state appears.
  5. Move to Dashboard and back to AI Review; confirm the selection, filter values, and list scroll position remain.
  6. Confirm a real-time alert update refreshes the pane, and that a removed/non-matching selected alert causes the agreed replacement behavior.

- [ ] **Step 5: Commit responsive navigation**

  ```bash
  git add lib/main.dart
  git commit -m "feat: add admin tablet navigation rail"
  ```

### Task 5: Final verification and handoff

**Files:**

- Modify: only files changed by Tasks 1–4 if verification exposes a defect.

**Interfaces:**

- Consumes: the completed responsive navigation and AI Review workspace.
- Produces: a formatted, analyzed, tested branch ready for review.

- [ ] **Step 1: Run the complete automated verification set**

  Run:

  ```bash
  dart format --set-exit-if-changed lib/main.dart lib/modules/admin/screens/review_management_screen.dart lib/modules/admin/screens/anomaly_review_detail_screen.dart lib/modules/admin/services/anomaly_review_filter.dart test/anomaly_review_test.dart
  flutter analyze
  flutter test
  ```

  Expected: all commands exit with status 0.

- [ ] **Step 2: Inspect the final diff**

  Run: `git diff main...HEAD --check && git status --short`

  Expected: no whitespace errors and no untracked/generated files. The local `.superpowers/` visual-companion folder remains ignored.

- [ ] **Step 3: Commit any verification-only corrections**

  If the previous checks require a correction, commit only the corrected implementation and test files:

  ```bash
  git add lib/main.dart lib/modules/admin/screens/anomaly_review_detail_screen.dart lib/modules/admin/screens/review_management_screen.dart lib/modules/admin/services/anomaly_review_filter.dart test/anomaly_review_test.dart
  git commit -m "fix: polish admin tablet review layout"
  ```

  If no correction is needed, do not create an empty commit.
