export type AnomalyAnalysis = {
  summary: string;
  possible_cause: string;
  severity_assessment: 'Low' | 'Medium' | 'High';
  confidence: number;
  recommendation: string;
};

export function parseAlertId(value: unknown): number {
  if (value == null || typeof value !== 'object') {
    throw new Error('Request body must be an object.');
  }
  const alertId = (value as Record<string, unknown>).alert_id;
  if (typeof alertId !== 'number' || !Number.isInteger(alertId) || alertId <= 0) {
    throw new Error('alert_id must be a positive integer.');
  }
  return alertId;
}

export function parseGroqAnalysis(value: unknown): AnomalyAnalysis {
  if (value == null || typeof value !== 'object') {
    throw new Error('Groq returned an invalid response.');
  }
  const choices = (value as Record<string, unknown>).choices;
  if (!Array.isArray(choices) || choices.length === 0) {
    throw new Error('Groq returned no analysis.');
  }
  const first = choices[0] as Record<string, unknown>;
  const message = first.message as Record<string, unknown> | undefined;
  const content = message?.content;
  if (typeof content !== 'string' || content.trim() === '') {
    throw new Error('Groq returned no analysis content.');
  }

  let parsed: Record<string, unknown>;
  try {
    parsed = JSON.parse(content) as Record<string, unknown>;
  } catch (_) {
    throw new Error('Groq returned malformed analysis JSON.');
  }

  const summary = text(parsed.summary);
  const possibleCause = text(parsed.possible_cause);
  const recommendation = text(parsed.recommendation);
  const severity = text(parsed.severity_assessment);
  const confidence = typeof parsed.confidence === 'number'
      ? parsed.confidence
      : Number.NaN;

  if (!summary || !possibleCause || !recommendation) {
    throw new Error('Groq analysis is missing required text fields.');
  }
  if (!['Low', 'Medium', 'High'].includes(severity)) {
    throw new Error('Groq analysis has an invalid severity.');
  }
  if (!Number.isFinite(confidence) || confidence < 0 || confidence > 1) {
    throw new Error('Groq analysis has an invalid confidence.');
  }

  return {
    summary,
    possible_cause: possibleCause,
    severity_assessment: severity as AnomalyAnalysis['severity_assessment'],
    confidence,
    recommendation,
  };
}

const WATER_ALERT_TYPES = new Set(['nrw_hotspot', 'household']);

function utilityLabel(alertType: unknown): string {
  return typeof alertType === 'string' && WATER_ALERT_TYPES.has(alertType)
      ? 'Water'
      : 'Electricity';
}

export function anomalyPrompt(alert: Record<string, unknown>): string {
  const location = [
    alert.state,
    alert.facility_name,
    alert.facility_city,
    alert.equipment_name,
  ]
      .filter((value): value is string => typeof value === 'string' && value.trim() !== '')
      .join(' → ');

  return [
    `Utility: ${utilityLabel(alert.alert_type)}`,
    `Location: ${location || 'Not linked'}`,
    `Alert type: ${alert.alert_type ?? 'Unknown'}`,
    `Alert signature: ${alert.signature ?? 'Unknown'}`,
    `System severity: ${alert.severity ?? 'Unknown'}`,
    `Actual: ${alert.actual_l ?? 'Unavailable'}`,
    `Baseline: ${alert.baseline_l ?? 'Unavailable'}`,
    `Produced/supplied: ${alert.produced_mld ?? 'Unavailable'}`,
    `Billed/consumed: ${alert.billed_mld ?? 'Unavailable'}`,
    `Loss: ${alert.loss_mld ?? 'Unavailable'}`,
    `Loss rate: ${alert.loss_pct ?? 'Unavailable'}%`,
    `Deterministic explanation: ${alert.explanation ?? 'Unavailable'}`,
  ].join('\n');
}

function text(value: unknown): string {
  return typeof value === 'string' ? value.trim() : '';
}
