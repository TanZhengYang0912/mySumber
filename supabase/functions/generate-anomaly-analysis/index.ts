import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

import {
  analysisStorageFields,
  anomalyPrompt,
  isHouseholdReport,
  parseAlertId,
  parseCaseId,
  parseGroqAnalysis,
} from "./anomaly_ai.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const groqModel = "openai/gpt-oss-120b";

function json(data: unknown, status = 200) {
  return Response.json(data, { status, headers: corsHeaders });
}

async function runAnalysis(
  evidence: Record<string, unknown>,
  groqApiKey: string,
) {
  const household = isHouseholdReport(evidence);
  const systemPrompt = household
    ? "A Malaysian utility customer has reported a problem in their own words. " +
      "Return only valid JSON with exactly these keys: summary, recommendation. " +
      "summary restates what the resident reported, in one neutral sentence. " +
      "recommendation is the next step for staff. " +
      "You have no sensor data for this report: never mention missing data, " +
      "never speculate about the cause, and never question whether the " +
      "resident is telling the truth."
    : "You analyze Malaysian water and electricity equipment anomalies. " +
      "Return only valid JSON with exactly these keys: summary, " +
      "possible_cause, severity_assessment, confidence, recommendation. " +
      "severity_assessment must be exactly Low, Medium, or High. " +
      "confidence must be a JSON number from 0 to 1. " +
      "Do not change system status or system severity. Do not recommend " +
      "a Worker visit, photo upload, or repair result.";
  const groqResponse = await fetch(
    "https://api.groq.com/openai/v1/chat/completions",
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${groqApiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: groqModel,
        messages: [
          {
            role: "system",
            content: systemPrompt,
          },
          { role: "user", content: anomalyPrompt(evidence) },
        ],
        response_format: { type: "json_object" },
        temperature: 0.3,
        max_tokens: 512,
      }),
      signal: AbortSignal.timeout(30_000),
    },
  );
  if (!groqResponse.ok) throw new Error("AI analysis is unavailable");
  return parseGroqAnalysis(await groqResponse.json(), {
    householdReport: household,
  });
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const authorization = request.headers.get("Authorization");
  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const groqApiKey = Deno.env.get("GROQ_API_KEY");
  const triggerSecret = Deno.env.get("INTERNAL_TRIGGER_SECRET");
  if (authorization == null) {
    return json({ error: "Authentication required" }, 401);
  }
  if (
    url == null || anonKey == null || serviceRoleKey == null ||
    groqApiKey == null
  ) {
    return json({ error: "Server configuration error" }, 500);
  }

  const adminClient = createClient(url, serviceRoleKey);
  const isSystemCall = triggerSecret != null &&
    authorization === `Bearer ${triggerSecret}`;

  if (!isSystemCall) {
    const callerClient = createClient(url, anonKey, {
      global: { headers: { Authorization: authorization } },
    });
    const { data: callerData, error: callerError } = await callerClient.auth
      .getUser();
    if (callerError != null || callerData.user == null) {
      return json({ error: "Invalid session" }, 401);
    }

    const { data: profile, error: profileError } = await adminClient
      .from("profiles")
      .select("role, status")
      .eq("id", callerData.user.id)
      .single();
    if (
      profileError != null ||
      profile == null ||
      profile.role !== "admin" ||
      profile.status !== "active"
    ) {
      return json({ error: "Admin access required" }, 403);
    }
  }

  const rawBody = await request.json();
  if (
    rawBody == null || typeof rawBody !== "object" || Array.isArray(rawBody)
  ) {
    return json({ error: "Request body must be an object" }, 400);
  }
  const body = rawBody as Record<string, unknown>;
  const targetCount = [
    Object.hasOwn(body, "preview"),
    Object.hasOwn(body, "alert_id"),
    Object.hasOwn(body, "case_id"),
  ].filter((isPresent) => isPresent).length;
  if (targetCount !== 1) {
    return json({
      error: "Provide exactly one of preview, alert_id, or case_id",
    }, 400);
  }

  if ("preview" in body) {
    try {
      const evidence = body.preview;
      if (evidence == null || typeof evidence !== "object") {
        return json({ error: "preview must be an object" }, 400);
      }
      const analysis = await runAnalysis(
        evidence as Record<string, unknown>,
        groqApiKey,
      );
      return json({
        analysis: { ...analysis, generated_at: new Date().toISOString() },
      });
    } catch (error) {
      console.error("generate-anomaly-analysis preview failed", error);
      return json({ error: "Could not generate AI analysis" }, 500);
    }
  }

  try {
    if ("case_id" in body) {
      const caseId = parseCaseId(body);
      const { data: anomalyCase, error: caseError } = await adminClient
        .from("anomaly_cases")
        .select()
        .eq("id", caseId)
        .maybeSingle();
      if (caseError != null || anomalyCase == null) {
        return json({ error: "Anomaly case not found" }, 404);
      }

      const evidence =
        anomalyCase.evidence != null && typeof anomalyCase.evidence === "object"
          ? anomalyCase.evidence as Record<string, unknown>
          : {};
      const analysis = await runAnalysis(
        { ...evidence, ...anomalyCase },
        groqApiKey,
      );
      const generatedAt = new Date().toISOString();
      const { error: saveError } = await adminClient
        .from("anomaly_cases")
        .update({
          ...analysisStorageFields(analysis),
          ai_generated_at: generatedAt,
        })
        .eq("id", caseId);
      if (saveError != null) throw saveError;

      return json({ analysis: { ...analysis, generated_at: generatedAt } });
    }

    const alertId = parseAlertId(body);
    const { data: alert, error: alertError } = await adminClient
      .from("alerts")
      .select()
      .eq("id", alertId)
      .maybeSingle();
    if (alertError != null || alert == null) {
      return json({ error: "Alert not found" }, 404);
    }

    const analysis = await runAnalysis(alert, groqApiKey);
    const generatedAt = new Date().toISOString();
    const { error: saveError } = await adminClient
      .from("alerts")
      .update({
        ...analysisStorageFields(analysis),
        ai_generated_at: generatedAt,
      })
      .eq("id", alertId);
    if (saveError != null) throw saveError;

    return json({ analysis: { ...analysis, generated_at: generatedAt } });
  } catch (error) {
    if (error instanceof Error && error.message.startsWith("alert_id")) {
      return json({ error: error.message }, 400);
    }
    console.error("generate-anomaly-analysis failed", error);
    return json({ error: "Could not generate AI analysis" }, 500);
  }
});
