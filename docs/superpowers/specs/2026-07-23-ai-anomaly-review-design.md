# AI Anomaly Review Design

**Date:** 2026-07-23  
**Status:** Draft for user review  
**Scope:** Replace the current customer service-review direction with an Admin-facing water/electricity anomaly review.

## Problem

The current Review feature follows this flow:

```text
Customer rates repair service → Admin views ratings → AI summarizes feedback
```

This does not match the project's main purpose or the lecturer's required direction. MySumber monitors water and electricity data, detects abnormal patterns, and provides Admin oversight of equipment and facilities across Malaysia.

The new Review feature must therefore review system-detected utility anomalies rather than customer satisfaction.

## Goals

- Make Review specific to water/electricity anomaly analysis.
- Show the full hierarchy: State → Shopping Mall → Equipment.
- Reuse the same anomaly records and statuses as Oversight.
- Keep Oversight as the operational status overview.
- Let Review present AI evidence, explanation, severity, and recommendation.
- Remove customer stars, comments, service-quality summaries, Worker inspections, photos, and repair-result workflows from this feature.

## Non-goals

- Building a Worker field-inspection workflow.
- Uploading inspection photos or field results.
- Summarizing customer reviews with AI.
- Creating a second status system for Review.
- Replacing the existing Oversight status flow.

## Product concept

The Review feature becomes **AI Anomaly Review**.

```text
Water/electricity data
        ↓
System detects an abnormal pattern
        ↓
Anomaly record is created automatically
        ↓
AI explains the anomaly
        ↓
Admin reviews the anomaly details
        ↓
Admin uses the existing Oversight flow for status operations
```

The feature is not a customer-feedback workflow. It is an Admin review of the system's own anomaly detection results.

## Responsibilities by screen

### Inventory

Inventory remains the source of the facility hierarchy and equipment list:

```text
State → Shopping Mall → Equipment
```

### Oversight

Oversight remains the national anomaly monitoring view. It groups alerts using the existing status categories:

- `Pending`
- `Ongoing` (the existing `Investigating` and `Not Fixed` statuses)
- `Solved` (the existing `Resolved` status)
- `Faults`

Oversight remains responsible for the existing status operations.

### AI Anomaly Review

Review is the detailed analysis view. It reads the same alert records as Oversight and does not create a separate review record or status system.

## Data relationship

The anomaly record must be linked to the specific equipment hierarchy:

```text
Alert
├── State
├── Shopping Mall
├── Equipment
├── Water / Electricity
├── Reading
├── Baseline
├── Severity
├── AI Explanation
└── Existing Alert Status
```

The current alert model contains state and reading information but does not yet directly reference a shopping mall or equipment node. The implementation must add a stable equipment/facility reference, or an equivalent reliable mapping, before Review can truthfully display mall-level and equipment-level anomalies.

Review and Oversight must resolve the same Alert record. No separate `service_reviews`, customer-rating summary, or duplicate anomaly table should be used as the primary Review source.

## Review list

The page title is **AI Anomaly Review**.

By default, the list shows only:

- `Pending`
- `Ongoing`

Available filters:

- Status: All, Pending, Ongoing, Solved, Faults
- Utility: Water, Electricity
- State/Federal Territory
- Shopping Mall
- Equipment

Each list card should show:

- Shopping mall name and city
- State/Federal Territory
- Equipment name
- Water or Electricity
- Severity
- Main abnormal value and baseline
- Short AI explanation
- Existing alert status

Example:

```text
1 Utama Shopping Centre
Petaling Jaya, Selangor

Main Water Pump A1
Water · High Severity

Actual: 8,400 L   Baseline: 5,200 L
Unusual water consumption detected
Status: Pending
```

## Review detail

The detail view should show:

1. State → Shopping Mall → Equipment breadcrumb.
2. Water/electricity type.
3. Detection time.
4. Actual reading versus baseline.
5. Difference or loss percentage when available.
6. Severity.
7. AI explanation.
8. Current alert status.
9. A link or action to open the existing Oversight detail flow when a status operation is needed.

Review does not add Worker evidence, inspection photos, repair notes, or customer comments.

## AI output

AI analysis is generated for each anomaly, not for a batch of customer reviews. The displayed structure is:

- **Anomaly Summary** — what abnormal pattern was detected.
- **Detected Evidence** — actual value, baseline, deviation, and relevant loss metric.
- **Possible Cause** — a cautious explanation based on the available data.
- **Severity** — Low, Medium, or High.
- **Confidence** — confidence of the anomaly interpretation when available.
- **System Recommendation** — a system-level suggestion such as continue monitoring, compare historical readings, or flag the record for Admin attention.

The recommendation must not imply a Worker visit, photo upload, or repair-result submission.

## Navigation and workflow

```text
Admin opens Oversight
        ↓
Admin sees an anomaly or opens AI Anomaly Review
        ↓
Review shows the same Alert with facility/equipment context
        ↓
Admin reads the evidence and AI explanation
        ↓
Admin opens Oversight detail for existing status operations
```

This keeps the roles clear:

```text
Inventory = manage facilities and equipment
Oversight = manage anomaly status and national monitoring
AI Anomaly Review = understand why the system detected an anomaly
```

## Acceptance criteria

- The Review navigation label and page copy no longer describe customer service reviews.
- No star ratings, customer comments, or customer-review AI summaries appear in the Admin Review feature.
- Review records are automatically derived from the same anomaly/alert data used by Oversight.
- Review defaults to Pending and Ongoing anomalies.
- Review can filter by utility, state, shopping mall, equipment, and status.
- Each review item identifies a specific shopping mall and equipment where the alert data supports that relationship.
- Review displays actual readings, baseline values, severity, and AI explanation.
- Oversight and Review show consistent alert statuses.
- No Worker inspection, photo, or repair-result flow is introduced.
- Inventory, Oversight, and other completed modules remain functionally intact except for the minimum navigation/data changes required to rename and repurpose Review.

## Open implementation note

Before implementation, confirm how the existing local equipment hierarchy will be represented in the alert data shared with Oversight. A stable node/equipment reference is preferred over matching only on a state name or display text.
