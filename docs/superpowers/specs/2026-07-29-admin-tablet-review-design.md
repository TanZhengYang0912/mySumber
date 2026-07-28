# Admin Tablet AI Review Design

## Goal

Make the Admin workspace comfortable and efficient on landscape tablets without changing the compact mobile experience. The focus is the AI Review workflow: locate an anomaly, inspect its evidence, then act without repeatedly navigating between screens.

## Responsive navigation

- At widths below 840dp, retain the existing bottom navigation, single-column AI Review list, and detail-route navigation.
- At widths of 840dp and above, all Admin destinations use a labelled NavigationRail; bottom navigation is not rendered.
- The tablet Admin shell preserves each tab's state when navigating between destinations.

## Tablet AI Review layout

The tablet view is composed of a header, two-row filter toolbar, and a master-detail content area.

- Header: page title and compact, non-interactive context counts for results, pending anomalies, and high-severity anomalies. There is no separate horizontal summary-card row.
- Filter toolbar: spans the full content width above the split view.
  - Status is a single choice: All, Pending, Ongoing, Solved, or Faults.
  - Utility is a single choice: All utilities, Water, or Electricity.
  - High severity is an independent toggle that combines with status and utility choices.
  - State, Shopping Mall, and Equipment are dependent dropdowns in a second row, with Clear.
- Content: a 400dp result-list pane and a flexible detail pane, separated by a divider. The detail content itself is capped at roughly 760–840dp on very wide displays.
- Result list: each result is a dense 72–88dp row/card that keeps facility, location or equipment, utility, severity, status, and date close together. The selected result has a clear teal outline.
- Detail pane: displays selected anomaly metadata, evidence, AI analysis, and its existing next actions. It must not introduce new review outcome rules in this scope.

## Selection and live updates

- On initial load, select the highest-priority matching anomaly: highest severity first, then Pending status, then newest detection time.
- If filters remove the selected item, select the next highest-priority matching item. If no item remains, show an empty detail state.
- When real-time data changes the selected alert, update the visible detail. If it no longer matches the active filters, notify the user briefly and select the next valid item or show the empty state.

## Implementation boundaries

- lib/main.dart owns the responsive Admin shell/navigation and will be updated carefully because it is shared.
- lib/modules/admin/screens/review_management_screen.dart owns the responsive review list, filter toolbar, selection, and empty states.
- lib/modules/admin/screens/anomaly_review_detail_screen.dart should expose reusable detail content for the tablet detail pane while retaining the existing mobile route.
- lib/modules/admin/services/anomaly_review_filter.dart gains the severity criterion and deterministic priority ordering.
- No CSV assets, Supabase schema, authentication logic, or user/worker interfaces change.

## Validation

- Test at a phone width, a 768dp portrait tablet width, an 840dp landscape breakpoint, and a large landscape tablet width.
- Verify every status, utility, severity, and dependent location/equipment filter combination.
- Verify selected-item replacement after filtering and after live data changes.
- Verify tab switching preserves AI Review filters, selection, and list scroll position on tablet.
- Run formatter, static analysis, and relevant Flutter widget tests after implementation.
