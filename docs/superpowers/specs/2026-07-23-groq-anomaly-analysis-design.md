# Groq AI Anomaly Analysis Design

**Date:** 2026-07-23  
**Status:** Draft for user review  
**Scope:** Add a real external Groq AI call to the Admin AI Anomaly Review feature.

## Problem

The new Admin Review page has the correct water/electricity anomaly direction, but its current explanation is based on the stored Alert explanation and does not call an external AI API. The lecturer requires the project to use an external AI API.

The old Groq integration summarizes customer service reviews. That is the wrong domain direction and must no longer be the Admin Review workflow.

## Goals

- Use the existing Groq API integration to analyze water/electricity anomalies.
- Call Groq for one selected anomaly from the Review detail page.
- Include State, Shopping Mall, Equipment, utility, readings, baseline, severity, and existing explanation as context.
- Save the structured AI result to the same `alerts` record in Supabase.
- Display the saved result after reopening the detail page.
- Keep Alert status and system severity controlled by the existing system/Oversight flow.
- Provide clear loading, validation, timeout, API, and storage error states.

## Non-goals

- Calling Groq for every alert while the Review list loads.
- Calling Groq for customer stars, comments, or service satisfaction.
- Allowing AI to modify `Alert.status`.
- Allowing AI to overwrite the system's original `Alert.severity`.
- Adding Worker inspections, photos, repair results, or field evidence.
- Exposing the Groq key in Supabase or storing it in the database.

## User flow

```text
Admin opens AI Anomaly Review
        ↓
Admin opens one alert linked to State → Shopping Mall → Equipment
        ↓
Admin taps Generate AI Analysis
        ↓
Flutter sends structured anomaly context to Groq
        ↓
Groq returns validated JSON
        ↓
Flutter saves the result to the same alerts row
        ↓
Review displays the analysis and generated timestamp
```

If an analysis already exists, the page displays it and offers `Regenerate AI Analysis`. The list page never automatically calls Groq.

## Architecture

### New responsibilities

- `anomaly_ai_analysis.dart` — immutable model for the validated Groq response.
- `anomaly_ai_service.dart` — HTTP request, prompt construction, JSON parsing, field validation, timeout, and API error mapping.
- `AppState` — loading guard, call orchestration, saved-result refresh, and user-facing result status.
- `LeakageRepository` — update the AI columns on the existing `alerts` row.
- `AnomalyReviewDetailScreen` — render the button, loading state, saved analysis, retry, and error state.

The existing customer-review `generateAiSummary()` method is not used by Admin AI Anomaly Review. It may remain for the customer-side legacy flow, but no Admin navigation or button may call it.

## Groq request context

The request includes only utility anomaly information:

- State/Federal Territory
- Shopping Mall and city
- Equipment name
- Water or Electricity
- Alert type and signature
- Actual reading and baseline
- Produced/supplied, billed/consumed, loss, and loss percentage when available
- System severity
- Existing deterministic explanation

The request must not include customer email addresses, star ratings, review comments, or API keys in the prompt.

## Structured response contract

Groq must return JSON in this shape:

```json
{
  "summary": "Short anomaly summary",
  "possible_cause": "Likely cause based on the supplied evidence",
  "severity_assessment": "High",
  "confidence": 0.92,
  "recommendation": "Continue monitoring the equipment record"
}
```

Validation rules:

- `summary`, `possible_cause`, and `recommendation` must be non-empty strings.
- `severity_assessment` must be exactly `Low`, `Medium`, or `High`.
- `confidence` must be numeric and between `0` and `1`.
- Missing fields, invalid JSON, invalid severity, or invalid confidence must reject the response and prevent persistence.

The AI severity assessment is display-only. It is not copied into the system `Alert.severity` field.

## Supabase persistence

Add these nullable columns to `public.alerts`:

```sql
alter table public.alerts
  add column if not exists ai_summary text,
  add column if not exists ai_possible_cause text,
  add column if not exists ai_recommendation text,
  add column if not exists ai_confidence numeric,
  add column if not exists ai_generated_at timestamptz;
```

No separate AI table is required. The existing alert RLS and Data API access model applies to these columns.

Saving is performed only after response validation. If saving fails, the UI may show the validated result for the current screen but must report the storage error and must not claim that the result was persisted.

## Detail-page states

```text
No saved analysis → Generate AI Analysis
Request running   → Generating...
Saved analysis   → Display result + Regenerate AI Analysis
Request failed   → Error message + Retry AI Analysis
```

The detail page displays:

- Summary
- Possible Cause
- AI Severity Assessment
- Confidence percentage
- System Recommendation
- Generated timestamp

The page continues to show the original anomaly evidence and current system status. It never displays customer reviews or Worker field data.

## Error handling

- Missing API key: `Groq API key is not configured`.
- Timeout: `AI request timed out`.
- Non-200 Groq response: `Groq API error`.
- Invalid JSON or failed validation: `Invalid AI response`.
- Supabase update failure: `AI analysis could not be saved`.
- All errors preserve the original Alert and leave status/severity unchanged.

The request is guarded against concurrent calls for the same detail screen so repeated taps do not create parallel requests.

## Acceptance criteria

- Tapping `Generate AI Analysis` sends a request to the external Groq API.
- The request contains concrete mall and equipment context when present.
- The result is parsed using the fixed JSON contract.
- Valid results are saved to the same `alerts` record.
- Reopening the detail page displays the saved result without another request.
- Regenerate explicitly performs a new Groq request.
- Invalid responses and API failures are visible and retryable.
- AI never changes Alert status or system severity.
- Admin Review never calls the old customer-review summary flow.
- No customer email, star rating, comment, Worker photo, or repair result is sent to Groq.
