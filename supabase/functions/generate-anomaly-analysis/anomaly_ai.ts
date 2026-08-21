export type AnomalyAnalysis = {
  summary: string;
  possible_cause?: string;
  severity_assessment?: "Low" | "Medium" | "High";
  confidence?: number;
  recommendation: string;
};

export function analysisStorageFields(analysis: AnomalyAnalysis) {
  return {
    ai_summary: analysis.summary,
    ai_possible_cause: analysis.possible_cause ?? null,
    ai_severity_assessment: analysis.severity_assessment ?? null,
    ai_recommendation: analysis.recommendation,
    ai_confidence: analysis.confidence ?? null,
  };
}

export function parseAlertId(value: unknown): number {
  if (value == null || typeof value !== "object") {
    throw new Error("Request body must be an object.");
  }
  const alertId = (value as Record<string, unknown>).alert_id;
  if (
    typeof alertId !== "number" || !Number.isInteger(alertId) || alertId <= 0
  ) {
    throw new Error("alert_id must be a positive integer.");
  }
  return alertId;
}

export function parseCaseId(value: unknown): string {
  if (value == null || typeof value !== "object") {
    throw new Error("Request body must be an object.");
  }
  const caseId = (value as Record<string, unknown>).case_id;
  if (
    typeof caseId !== "string" ||
    !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
      .test(caseId)
  ) {
    throw new Error("case_id must be a UUID.");
  }
  return caseId;
}

export function parseGroqAnalysis(
  value: unknown,
  opts: { householdReport?: boolean } = {},
): AnomalyAnalysis {
  if (value == null || typeof value !== "object") {
    throw new Error("Groq returned an invalid response.");
  }
  const choices = (value as Record<string, unknown>).choices;
  if (!Array.isArray(choices) || choices.length === 0) {
    throw new Error("Groq returned no analysis.");
  }
  const first = choices[0] as Record<string, unknown>;
  const message = first.message as Record<string, unknown> | undefined;
  const content = message?.content;
  if (typeof content !== "string" || content.trim() === "") {
    throw new Error("Groq returned no analysis content.");
  }

  let parsed: Record<string, unknown>;
  try {
    parsed = JSON.parse(content) as Record<string, unknown>;
  } catch (_) {
    throw new Error("Groq returned malformed analysis JSON.");
  }

  const summary = text(parsed.summary);
  const recommendation = text(parsed.recommendation);

  if (!summary || !recommendation) {
    throw new Error("Groq analysis is missing required text fields.");
  }

  if (opts.householdReport) {
    return { summary, recommendation };
  }

  const possibleCause = text(parsed.possible_cause);
  const severity = text(parsed.severity_assessment);
  const confidence = typeof parsed.confidence === "number"
    ? parsed.confidence
    : Number.NaN;

  if (!possibleCause) {
    throw new Error("Groq analysis is missing required text fields.");
  }
  if (!["Low", "Medium", "High"].includes(severity)) {
    throw new Error("Groq analysis has an invalid severity.");
  }
  if (!Number.isFinite(confidence) || confidence < 0 || confidence > 1) {
    throw new Error("Groq analysis has an invalid confidence.");
  }

  return {
    summary,
    possible_cause: possibleCause,
    severity_assessment: severity as AnomalyAnalysis["severity_assessment"],
    confidence,
    recommendation,
  };
}

const WATER_ALERT_TYPES = new Set(["nrw_hotspot", "household"]);

export function isHouseholdReport(alert: Record<string, unknown>): boolean {
  return alert.source_scope === "household";
}

function utilityLabel(alert: Record<string, unknown>): string {
  if (alert.utility_type === "water" || alert.utility === "water") {
    return "Water";
  }
  if (alert.utility_type === "electricity" || alert.utility === "electricity") {
    return "Electricity";
  }
  const alertType = alert.alert_type;
  return typeof alertType === "string" && WATER_ALERT_TYPES.has(alertType)
    ? "Water"
    : "Electricity";
}

export function anomalyPrompt(alert: Record<string, unknown>): string {
  const location = [
    alert.state,
    alert.facility_name,
    alert.facility_city,
    alert.equipment_name,
    alert.household_id,
  ]
    .filter((value): value is string =>
      typeof value === "string" && value.trim() !== ""
    )
    .join(" → ");

  if (isHouseholdReport(alert)) {
    return [
      "Source: Household report",
      `Utility: ${utilityLabel(alert)}`,
      `Location: ${location || "Not linked"}`,
      `Resident's own words: ${alert.explanation ?? "Unavailable"}`,
    ].join("\n");
  }

  return [
    `Source: ${alert.source_scope ?? "Unknown"}`,
    `Utility: ${utilityLabel(alert)}`,
    `Location: ${location || "Not linked"}`,
    `Alert type: ${alert.alert_type ?? "Unknown"}`,
    `Alert signature: ${alert.signature ?? "Unknown"}`,
    `System severity: ${alert.severity ?? "Unknown"}`,
    `Actual: ${alert.actual_l ?? "Unavailable"}`,
    `Baseline: ${alert.baseline_l ?? "Unavailable"}`,
    `Produced/supplied: ${alert.produced_mld ?? "Unavailable"}`,
    `Billed/consumed: ${alert.billed_mld ?? "Unavailable"}`,
    `Loss: ${alert.loss_mld ?? "Unavailable"}`,
    `Loss rate: ${alert.loss_pct ?? "Unavailable"}%`,
    `Deterministic explanation: ${alert.explanation ?? "Unavailable"}`,
  ].join("\n");
}

function text(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}
