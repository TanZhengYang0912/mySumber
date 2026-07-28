# Admin Orientation-Responsive Design

## Purpose

Give the Admin role a deliberate landscape-phone experience without mistaking a rotated phone for a tablet. This specification supersedes the earlier tablet-only layout assumptions for Admin navigation, Dashboard, and AI Review.

## Shared responsive classification

The layout must use both the viewport width and its shortest side.

| Mode | Condition | Navigation |
|---|---|---|
| Phone portrait | shortestSide < 600dp and height >= width | Existing Bottom Navigation |
| Phone landscape | shortestSide < 600dp and width > height | Compact 56dp icon Rail with More |
| Tablet portrait | shortestSide >= 600dp and width < 840dp | Existing Bottom Navigation |
| Tablet landscape | shortestSide >= 600dp and width >= 840dp | Labelled NavigationRail |

The same classification function must be used by AppShell and each responsive Admin screen. A landscape phone must never use the tablet master-detail layout.

## Phone landscape navigation

- The compact Rail is 56dp wide and uses the existing Admin icon semantics: Dashboard, Alerts, and AI Review.
- The selected destination is communicated by the existing Admin teal indicator and surface treatment; labels are not permanently displayed.
- A More button at the bottom of the Rail opens a small side popover immediately to the Rail’s right.
- The More popover contains Inventory, Oversight, Settings, and Logout with icon and text labels. Tapping outside closes it.
- Selecting an item from More replaces only the content area. The compact Rail remains visible and More is the selected top-level entry.

## Phone landscape Dashboard

The Dashboard is a glance-and-decide surface, not a compressed copy of the tablet dashboard.

- Replace the tall green hero with a 56dp app bar containing Dashboard, a concise subtitle, and a link to the full Dashboard.
- The first viewport shows exactly two primary status cards: Active equipment and Critical items.
- Show one priority-equipment item with location, severity, and health score.
- Total equipment and warning count become supporting text rather than equal-weight cards.
- Usage comparison charts and the full health list remain below the fold.
- Use compact icon-only Rail navigation; do not preserve the phone-portrait’s large labelled controls in this mode.

## Phone landscape AI Review

- Use a compact header with the current Status and a Filter button. Full filtering is opened only on demand in a side popover.
- The filter popover contains Status, Utility, High severity, State, Shopping Mall, Equipment, and Clear. It adapts internally rather than overflowing.
- The result area uses a two-column grid of compact anomaly cards. Each card groups facility/location, utility, severity, status, and date.
- Tapping a card opens a full-screen anomaly detail route. It does not use the tablet’s persistent detail pane.
- The full-screen detail retains evidence, AI analysis, generation state, error state, and existing Oversight action.

## Tablet layout

- Tablet portrait retains the phone-style Bottom Navigation and single-column content.
- Tablet landscape retains the previously approved labelled NavigationRail, full filter toolbar, 400dp review-result pane, and capped master-detail pane.

## Rotation and real-time state

- Rotation preserves the current Admin destination, AI Review filters, selected anomaly, and each screen’s scroll position.
- When live alerts invalidate a selected anomaly or location/equipment filter, the UI clears invalid filter values, selects the next priority result when possible, and never shows a stale hidden query.
- Flutter Debug builds must not emit RenderFlex overflow indicators at supported device sizes.

## Scope and boundaries

- This specification applies to the Admin role only.
- Worker and Customer will receive separate, role-specific phone-landscape designs after Admin implementation is accepted.
- Dashboard implementation changes touch lib/modules/dataset/; coordinate with that module owner before modifying it.
- No Supabase schema, CSV asset, authentication, or review-outcome changes are included.

## Acceptance checks

1. Rotating a Pixel/iPhone-class phone to landscape shows the compact Rail, not tablet NavigationRail or master-detail review.
2. The compact Rail exposes Dashboard, Alerts, AI Review, and More; More exposes Inventory and Oversight without hiding the content area.
3. Phone-landscape Dashboard shows two key metrics and one priority item without a dense multi-card stack.
4. Phone-landscape AI Review shows cards and a Filter popover without overflow; selecting a card opens full-screen detail.
5. A true tablet landscape uses the labelled Rail and master-detail review workspace.
6. Rotation and real-time alert/filter changes preserve valid state and clear invalid state.
