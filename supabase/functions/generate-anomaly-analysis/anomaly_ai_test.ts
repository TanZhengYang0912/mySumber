import { assertEquals, assertThrows } from "jsr:@std/assert@1";

import {
  analysisStorageFields,
  anomalyPrompt,
  parseAlertId,
  parseCaseId,
  parseGroqAnalysis,
} from "./anomaly_ai.ts";

Deno.test("accepts a positive integer alert id", () => {
  assertEquals(parseAlertId({ alert_id: 42 }), 42);
  assertThrows(() => parseAlertId({ alert_id: "42" }));
});

Deno.test("accepts a UUID case id", () => {
  assertEquals(
    parseCaseId({ case_id: "7d1b9e5b-4d91-4acf-a9cb-7a4af83d4b1e" }),
    "7d1b9e5b-4d91-4acf-a9cb-7a4af83d4b1e",
  );
  assertThrows(() => parseCaseId({ case_id: "not-a-uuid" }));
});

Deno.test("validates structured Groq JSON", () => {
  const response = {
    choices: [
      {
        message: {
          content: JSON.stringify({
            summary: "Pump usage is above baseline.",
            possible_cause: "Continuous demand spike.",
            severity_assessment: "High",
            confidence: 0.9,
            recommendation: "Inspect the equipment record.",
          }),
        },
      },
    ],
  };

  assertEquals(parseGroqAnalysis(response).severity_assessment, "High");
});

Deno.test("builds prompts from server-fetched alert data", () => {
  const prompt = anomalyPrompt({
    utility_type: "water",
    state: "Selangor",
    facility_name: "1 Utama Shopping Centre",
    equipment_name: "Main Water Pump A1",
  });
  assertEquals(prompt.includes("Main Water Pump A1"), true);
  assertEquals(prompt.includes("Water"), true);
});

Deno.test("derives utility from alert_type, not a nonexistent column", () => {
  const waterPrompt = anomalyPrompt({
    alert_type: "nrw_hotspot",
    state: "Perlis",
  });
  assertEquals(waterPrompt.includes("Utility: Water"), true);

  const electricityPrompt = anomalyPrompt({
    alert_type: "electricity_hotspot",
    state: "Selangor",
  });
  assertEquals(electricityPrompt.includes("Utility: Electricity"), true);
});

Deno.test("preview evidence produces the same prompt shape as an alert row", () => {
  const promptFromRow = anomalyPrompt({
    alert_type: "nrw_hotspot",
    state: "Perlis",
    explanation: "Test.",
  });
  const promptFromPreview = anomalyPrompt({
    alert_type: "nrw_hotspot",
    state: "Perlis",
    explanation: "Test.",
  });
  assertEquals(promptFromRow, promptFromPreview);
});

Deno.test("household analysis parses without cause, severity or confidence", () => {
  const parsed = parseGroqAnalysis({
    choices: [
      {
        message: {
          content: JSON.stringify({
            summary: "Resident reports a leak running for four hours.",
            recommendation: "Contact the resident and schedule a visit today.",
          }),
        },
      },
    ],
  }, { householdReport: true });

  assertEquals(parsed.possible_cause, undefined);
  assertEquals(parsed.severity_assessment, undefined);
  assertEquals(parsed.confidence, undefined);
});

Deno.test("household analysis storage explicitly clears unavailable fields", () => {
  assertEquals(
    analysisStorageFields({
      summary: "Resident reports a leak running for four hours.",
      recommendation: "Contact the resident and schedule a visit today.",
    }),
    {
      ai_summary: "Resident reports a leak running for four hours.",
      ai_possible_cause: null,
      ai_severity_assessment: null,
      ai_recommendation: "Contact the resident and schedule a visit today.",
      ai_confidence: null,
    },
  );
});

Deno.test("non-household analysis still demands every field", () => {
  assertThrows(() =>
    parseGroqAnalysis({
      choices: [
        {
          message: {
            content: JSON.stringify({
              summary: "Loss is high.",
              recommendation: "Inspect the district network.",
            }),
          },
        },
      ],
    })
  );
});

Deno.test("household prompt omits the telemetry lines", () => {
  const prompt = anomalyPrompt({
    source_scope: "household",
    household_id: "H-305",
    state: "Perlis",
    explanation: "Resident says water is leaking.",
  });

  assertEquals(prompt.includes("Baseline:"), false);
  assertEquals(prompt.includes("Loss rate:"), false);
  assertEquals(prompt.includes("Resident's own words:"), true);
});
