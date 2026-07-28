# Admin Phone-Landscape Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (- [ ]) syntax for tracking.

**Goal:** Give the Admin role a compact, overflow-free landscape-phone experience while preserving the approved tablet and portrait workflows.

**Architecture:** A pure Admin layout classifier is the single source of truth for orientation and tablet decisions. AppShell switches among bottom navigation, compact Rail with More, and labelled tablet Rail; Dashboard and AI Review render their own phone-landscape bodies from that same mode.

**Tech Stack:** Flutter Material 3, Dart, Provider, flutter_test, intl.

## Global Constraints

- Phone landscape means shortestSide < 600dp and width > height; it must never use tablet master-detail.
- Tablet landscape means shortestSide >= 600dp and width >= 840dp.
- Admin phone landscape uses a 56dp icon Rail, Dashboard/Alerts/AI Review, and More for Inventory/Oversight/Logout. Do not expose a non-functional Settings destination: the Admin role has no settings route today.
- Keep Supabase schemas, CSV assets, authentication semantics, and alert-review outcomes unchanged.
- Preserve Admin destination, valid filters, selected alert, and scroll positions across orientation changes.
- Do not introduce Flutter RenderFlex overflow at supported screen sizes.

---

## File structure

- Modify: lib/modules/admin/services/admin_tablet_layout.dart — replace width-only helper with a layout-mode classifier.
- Create: lib/modules/admin/widgets/admin_compact_rail.dart — icon-only Rail and anchored More menu.
- Modify: lib/main.dart — choose Admin navigation from the shared layout mode and preserve IndexedStack state.
- Modify: lib/modules/dataset/screens/dashboard_screen.dart — compact landscape Dashboard and explicit Scrollbar controller.
- Modify: lib/modules/admin/screens/review_management_screen.dart — compact landscape AI Review, side filter menu, and two-column card grid.
- Modify: test/admin_tablet_layout_test.dart — orientation classification tests.
- Modify: test/anomaly_review_test.dart — retain live filter/priority coverage.

### Task 1: Introduce one tested Admin layout classifier

**Files:**

- Modify: lib/modules/admin/services/admin_tablet_layout.dart
- Modify: test/admin_tablet_layout_test.dart

**Interfaces:**

- Produces: AdminLayoutMode adminLayoutModeFor(Size viewport).
- Consumed by: AppShell, DashboardScreen, and ReviewManagementScreen.

- [ ] **Step 1: Replace the obsolete width-only classifier test**

  Replace `test/admin_tablet_layout_test.dart` with:

  ```dart
  import 'package:flutter/material.dart';
  import 'package:flutter_test/flutter_test.dart';
  import 'package:mysumber/modules/admin/services/admin_tablet_layout.dart';

  void main() {
    test('classifies every approved Admin viewport mode', () {
      expect(
        adminLayoutModeFor(const Size(914, 411)),
        AdminLayoutMode.phoneLandscape,
      );
      expect(
        adminLayoutModeFor(const Size(411, 914)),
        AdminLayoutMode.phonePortrait,
      );
      expect(
        adminLayoutModeFor(const Size(768, 1024)),
        AdminLayoutMode.tabletPortrait,
      );
      expect(
        adminLayoutModeFor(const Size(1024, 768)),
        AdminLayoutMode.tabletLandscape,
      );
    });
  }
  ```

- [ ] **Step 2: Verify the test fails**

  Run: flutter test test/admin_tablet_layout_test.dart

  Expected: compilation fails because AdminLayoutMode and adminLayoutModeFor do not exist.

- [ ] **Step 3: Implement the classifier**

  Replace the width-only helper with:

  ```dart
  enum AdminLayoutMode {
    phonePortrait,
    phoneLandscape,
    tabletPortrait,
    tabletLandscape,
  }

  AdminLayoutMode adminLayoutModeFor(Size viewport) {
    final shortestSide = viewport.shortestSide;
    if (shortestSide < 600) {
      return viewport.width > viewport.height
          ? AdminLayoutMode.phoneLandscape
          : AdminLayoutMode.phonePortrait;
    }
    return viewport.width >= 840
        ? AdminLayoutMode.tabletLandscape
        : AdminLayoutMode.tabletPortrait;
  }
  ```

- [ ] **Step 4: Run tests and commit**

  Run: dart format lib/modules/admin/services/admin_tablet_layout.dart test/admin_tablet_layout_test.dart && flutter test test/admin_tablet_layout_test.dart

  Expected: PASS.

  ```bash
  git add lib/modules/admin/services/admin_tablet_layout.dart
  git add -f test/admin_tablet_layout_test.dart
  git commit -m "feat: classify admin orientation layouts"
  ```

### Task 2: Build the compact Admin Rail and More menu

**Files:**

- Create: lib/modules/admin/widgets/admin_compact_rail.dart
- Modify: lib/main.dart
- Create: test/admin_compact_rail_test.dart

**Interfaces:**

- Produces: AdminCompactRail(currentIndex, onDestinationSelected, onLogout).
- Consumes: destination indices 0 Dashboard, 1 Inventory, 2 Alerts, 3 Oversight, 4 AI Review.

- [ ] **Step 1: Add a failing widget test**

  Create `test/admin_compact_rail_test.dart`:

  ```dart
  import 'package:flutter/material.dart';
  import 'package:flutter_test/flutter_test.dart';
  import 'package:mysumber/modules/admin/widgets/admin_compact_rail.dart';

  void main() {
    testWidgets('keeps secondary destinations in the anchored More menu',
        (tester) async {
      int? selectedIndex;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AdminCompactRail(
            currentIndex: 0,
            onDestinationSelected: (index) => selectedIndex = index,
            onLogout: () {},
          ),
        ),
      ));

      expect(find.byTooltip('Dashboard'), findsOneWidget);
      expect(find.byTooltip('Alerts'), findsOneWidget);
      expect(find.byTooltip('AI Review'), findsOneWidget);
      expect(find.text('Inventory'), findsNothing);

      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      expect(find.text('Inventory'), findsOneWidget);
      expect(find.text('Oversight'), findsOneWidget);

      await tester.tap(find.text('Inventory'));
      expect(selectedIndex, 1);
    });
  }
  ```

- [ ] **Step 2: Implement the compact Rail**

  Create AdminCompactRail with a 56dp Container, three icon buttons, and a MenuAnchor. The menu must map Inventory to index 1 and Oversight to index 3:

  ```dart
  MenuAnchor(
    menuChildren: [
      MenuItemButton(
        leadingIcon: const Icon(Icons.inventory_2_outlined),
        onPressed: () => onDestinationSelected(1),
        child: const Text('Inventory'),
      ),
      MenuItemButton(
        leadingIcon: const Icon(Icons.shield_outlined),
        onPressed: () => onDestinationSelected(3),
        child: const Text('Oversight'),
      ),
      MenuItemButton(
        leadingIcon: const Icon(Icons.logout_outlined),
        onPressed: onLogout,
        child: const Text('Logout'),
      ),
    ],
    builder: (context, controller, child) => IconButton(
      tooltip: 'More',
      onPressed: controller.isOpen ? controller.close : controller.open,
      icon: const Icon(Icons.more_horiz),
    ),
  )
  ```

  Use the existing grid_view_outlined, notifications_outlined, and analytics_outlined icons for the three direct destinations. Expose Dashboard, Alerts, AI Review, and More through matching `Tooltip` messages. Give the active control the existing AppColors.adminPrimary indicator and surface.

- [ ] **Step 3: Integrate the three navigation modes in AppShell**

  In AppShell, calculate:

  ```dart
  final mode = adminLayoutModeFor(
    Size(constraints.maxWidth, constraints.maxHeight),
  );
  final isAdmin = widget.userRole == 'admin';
  final useCompactRail = isAdmin && mode == AdminLayoutMode.phoneLandscape;
  final useTabletRail = isAdmin && mode == AdminLayoutMode.tabletLandscape;
  ```

  Keep the existing bottom navigation for all other modes. Render AdminCompactRail only for useCompactRail, and the labelled NavigationRail only for useTabletRail. Keep the screen bodies in the existing IndexedStack.

- [ ] **Step 4: Verify and commit**

  Run: dart format lib/main.dart lib/modules/admin/widgets/admin_compact_rail.dart test/admin_compact_rail_test.dart && flutter analyze lib/main.dart lib/modules/admin/widgets/admin_compact_rail.dart && flutter test test/admin_tablet_layout_test.dart test/admin_compact_rail_test.dart

  Expected: no diagnostics; tests pass.

  ```bash
  git add lib/main.dart lib/modules/admin/widgets/admin_compact_rail.dart
  git add -f test/admin_compact_rail_test.dart
  git commit -m "feat: add compact admin landscape rail"
  ```

### Task 3: Implement the glance-first landscape Dashboard

**Files:**

- Modify: lib/modules/dataset/screens/dashboard_screen.dart

**Interfaces:**

- Consumes: DatasetState nodes and adminLayoutModeFor(MediaQuery.sizeOf(context)).
- Produces: a phone-landscape Dashboard with two status cards and one priority-equipment item.

- [ ] **Step 1: Add a Dashboard layout test seam**

  Give the landscape body a ValueKey named phone-landscape-dashboard and the priority item a ValueKey named priority-equipment. This allows a widget test to assert the compact branch without depending on typography.

- [ ] **Step 2: Add explicit controller ownership for the existing visible Scrollbar**

  Add a ScrollController field, dispose it, and attach it to both the Scrollbar and ListView that display state bars:

  ```dart
  final _stateBarController = ScrollController();

  @override
  void dispose() {
    _stateBarController.dispose();
    super.dispose();
  }

  Scrollbar(
    controller: _stateBarController,
    thumbVisibility: true,
    child: ListView.builder(
      controller: _stateBarController,
      // existing list properties
    ),
  )
  ```

- [ ] **Step 3: Add the landscape branch**

  In build, calculate mode from MediaQuery.sizeOf(context). For phoneLandscape, use a compact 56dp top bar and a Row with two equally flexible panels:

  ```dart
  Row(
  children: [
      Expanded(child: _landscapeStatusPanel(active, critical, warning, total)),
      const SizedBox(width: 14),
      Expanded(child: _landscapePriorityPanel(priority)),
    ],
  )
  ```

  Define `priority` before that Row without using `firstOrNull`:

  ```dart
  final priority = healthPreview.isEmpty ? null : healthPreview.first;
  ```

  The status panel has only Active and Critical cards. The priority panel has one health row; total and warning are supporting text. Keep the existing ListView dashboard for the other three modes.

- [ ] **Step 4: Verify and commit**

  Run: dart format lib/modules/dataset/screens/dashboard_screen.dart && flutter analyze lib/modules/dataset/screens/dashboard_screen.dart && flutter test test/dataset_facility_test.dart

  Expected: no diagnostics; dataset tests pass.

  ```bash
  git add lib/modules/dataset/screens/dashboard_screen.dart
  git commit -m "feat: compact admin dashboard in phone landscape"
  ```

### Task 4: Implement phone-landscape AI Review

**Files:**

- Create: lib/modules/admin/widgets/landscape_filter_menu.dart
- Modify: lib/modules/admin/screens/review_management_screen.dart

**Interfaces:**

- Consumes: existing AnomalyReviewQuery state, AnomalyReviewFilter results, and AnomalyReviewDetailScreen.
- Produces: LandscapeFilterMenu and a two-column phone-landscape anomaly grid.

- [ ] **Step 1: Add a failing landscape review widget test**

  Pump ReviewManagementScreen at 914 by 411 with fixture alerts and assert a GridView with two columns, a Filter control, and no AnomalyReviewDetailContent in the initial screen. Tap a result and assert AnomalyReviewDetailScreen is pushed.

- [ ] **Step 2: Implement the anchored filter menu**

  Build LandscapeFilterMenu around MenuAnchor. Its menu child is a 360dp SizedBox containing the existing Status, Utility, High severity, State, Shopping Mall, Equipment, and Clear controls. Pass values and callbacks from ReviewManagementScreen; do not duplicate filter state in the menu.

- [ ] **Step 3: Add the landscape review branch**

  Before the existing phone/tablet branch, select phone landscape:

  ```dart
  if (mode == AdminLayoutMode.phoneLandscape) {
    return _phoneLandscapeLayout(
      results: results,
      states: states,
      facilities: facilities,
      equipment: equipment,
    );
  }
  ```

  _phoneLandscapeLayout uses a compact title row with the selected status and LandscapeFilterMenu, followed by:

  ```dart
  GridView.builder(
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.65,
    ),
    itemCount: results.length,
    itemBuilder: (context, index) => _landscapeAlertCard(results[index]),
  )
  ```

  _landscapeAlertCard groups facility/location on top and utility, severity, status, and date at the bottom. Its tap action pushes AnomalyReviewDetailScreen; do not embed AnomalyReviewDetailContent.

- [ ] **Step 4: Verify and commit**

  Run: dart format lib/modules/admin/screens/review_management_screen.dart lib/modules/admin/widgets/landscape_filter_menu.dart && flutter analyze lib/modules/admin/screens/review_management_screen.dart lib/modules/admin/widgets/landscape_filter_menu.dart && flutter test test/anomaly_review_test.dart

  Expected: no diagnostics; tests pass.

  ```bash
  git add lib/modules/admin/screens/review_management_screen.dart lib/modules/admin/widgets/landscape_filter_menu.dart
  git add -f test/anomaly_review_test.dart
  git commit -m "feat: optimize AI review for phone landscape"
  ```

### Task 5: Verify rotation, overflow, and retained state

**Interfaces:**

- Consumes: all responsive branches.
- Produces: a verified Admin experience across phone and tablet modes.

- [ ] **Step 1: Run complete automated verification**

  Run:

  ```bash
  dart format --set-exit-if-changed lib/main.dart lib/modules/admin/services/admin_tablet_layout.dart lib/modules/admin/widgets/admin_compact_rail.dart lib/modules/admin/widgets/landscape_filter_menu.dart lib/modules/admin/screens/review_management_screen.dart lib/modules/dataset/screens/dashboard_screen.dart test/admin_tablet_layout_test.dart test/admin_compact_rail_test.dart test/anomaly_review_test.dart
  flutter analyze
  flutter test
  ```

  Expected: formatting is clean and all tests pass. If the full analyzer reports existing diagnostics outside these files, report them separately and do not modify unrelated modules.

- [ ] **Step 2: Run manual emulator checks**

  Run: flutter run -d emulator-5554

  Verify phone portrait, phone landscape, tablet portrait, and tablet landscape. Rotate while on Dashboard and AI Review; confirm destination, filters, selection, and scroll position persist. Confirm More is anchored beside the compact Rail, its items work, and there are no yellow/black overflow markers.

- [ ] **Step 3: Commit verification-only corrections if required**

  If manual testing exposes a layout defect, commit the corrected implementation files with:

  ```bash
  git add lib/main.dart lib/modules/dataset/screens/dashboard_screen.dart lib/modules/admin/screens/review_management_screen.dart lib/modules/admin/widgets/admin_compact_rail.dart lib/modules/admin/widgets/landscape_filter_menu.dart
  git commit -m "fix: polish admin phone landscape layout"
  ```

  If no correction is required, do not create an empty commit.
