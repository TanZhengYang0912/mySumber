# Oversight phone-landscape design

## Goal

Make the Admin **Oversight** screen useful on a phone held horizontally. The first task is to find and act on pending anomalies. The layout must not replicate the portrait screen's large header, two tab rows, visible filters, and floating action button in the limited landscape height.

## Scope

- Applies only to the Admin role in `phoneLandscape` mode (`shortestSide < 600` and width exceeds height).
- Leaves portrait and tablet layouts unchanged.
- Reuses the existing compact Admin rail and its More popover.
- Preserves the existing alert, report, filtering, and detail flows; this is a presentation and navigation change, not a data-model change.

## Layout

### Compact workspace shell

- Use the existing 56dp icon-only `AdminCompactRail` on the left.
- Replace the teal hero header with a 56–64dp white compact top bar.
- The bar contains `Oversight`, a pending-count badge, a Filter button, and a More menu.
- Do not show an in-page Logout control; logout remains in the rail's More menu.

### Primary surface

- Present a compact segmented control for `Alerts` and `Reports`; it must not become a full-width tab row.
- On entry, select `Alerts`.
- Below it, show a small queue label such as `Pending alerts` and the active sort (`Severity, then newest`).
- Show the alert list immediately below this label. No persistent utility chips or status tabs appear above it.

### Alert rows

- Rows are 64–72dp high and have one severity colour accent at the left edge.
- Each row displays: location/asset title, utility and anomaly summary, date, and a severity badge.
- The default order is high severity first, then newest alert.
- Tapping a row opens the existing alert-detail route. Assignment, resolution, reporting, and evidence actions live in that detail flow, not over the list.
- Remove the landscape floating `Report State` button from this screen. The existing report-creation route remains accessible from alert detail and the More menu if already available.

## Filters and queue defaults

- Default query: `Pending`, all utilities, all severities.
- The default must not hide medium-severity work; severity ordering surfaces high-severity alerts first.
- `Filter` opens an anchored popover beside the rail/content edge, never a bottom sheet.
- The popover contains independent controls for status (`Pending`, `Ongoing`, `Solved`, `Faults`), utility (`Water`, `Electricity`), and severity (`High`, `Medium`, or all).
- Show an active-filter count on the Filter button when the query differs from the default and provide `Clear filters` inside the popover.
- Selected filters persist while moving between `Alerts` and `Reports` only when their meaning applies. Report-only filters are created only within the Reports view.

## Reports

- Selecting `Reports` replaces the queue content with the existing reports content.
- Show only report-relevant search and filters in this state, inside the same Filter popover or a compact in-content control.
- Do not retain alert status tabs, utility chips, or alert action buttons in the Reports view.

## Interaction and orientation behaviour

- Keep the selected outer section, selected filter values, and scroll position when rotating between portrait and phone landscape.
- A valid empty filtered result displays a compact empty state with an action to clear filters.
- Filter controls remain keyboard and touch accessible, with tappable targets at least 44dp.
- Long location and equipment names truncate in rows; full content appears on the detail screen.

## Implementation boundaries

- Introduce a dedicated landscape Oversight workspace widget instead of adding more layout conditions to the existing portrait `Column`.
- Keep query/filter state in the screen state object or a small private value object shared by portrait and landscape widgets.
- Reuse `admin_tablet_layout.dart`, `AdminCompactRail`, the existing `AppState` selectors, and the existing alert-detail/report routes.
- Do not change Supabase queries, alert data schemas, or global navigation definitions.

## Verification

1. At a phone-landscape size, the top bar, segmented control, queue label, and three 64–72dp alert rows fit without vertical overlap.
2. The initial view shows pending alerts of every severity, with high severity first.
3. Selecting Ongoing, High severity, and either utility changes the visible queue; Clear filters restores the default.
4. Filter popover stays anchored and does not cover the full workspace as a bottom sheet.
5. Tapping an alert opens the existing detail view; returning preserves list context.
6. Switching to Reports does not expose alert-only controls.
7. Rotating portrait → landscape → portrait preserves section, filters, and a reasonable equivalent scroll position.
8. Run `flutter analyze` for touched files and `flutter test` before handoff.
