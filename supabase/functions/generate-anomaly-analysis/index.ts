import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

import { anomalyPrompt, parseAlertId, parseGroqAnalysis } from './anomaly_ai.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
      'authorization, x-client-info, apikey, content-type',
};

const groqModel = 'openai/gpt-oss-120b';

function json(data: unknown, status = 200) {
  return Response.json(data, {status, headers: corsHeaders});
}

async function runAnalysis(evidence: Record<string, unknown>, groqApiKey: string) {
  const groqResponse = await fetch(
    'https://api.groq.com/openai/v1/chat/completions',
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${groqApiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: groqModel,
        messages: [
          {
            role: 'system',
            content: 'You analyze Malaysian water and electricity equipment anomalies. '
                + 'Return only valid JSON with exactly these keys: summary, '
                + 'possible_cause, severity_assessment, confidence, recommendation. '
                + 'severity_assessment must be exactly Low, Medium, or High. '
                + 'confidence must be a JSON number from 0 to 1. '
                + 'Do not change system status or system severity. Do not recommend '
                + 'a Worker visit, photo upload, or repair result.',
          },
          {role: 'user', content: anomalyPrompt(evidence)},
        ],
        response_format: {type: 'json_object'},
        temperature: 0.3,
        max_tokens: 512,
      }),
      signal: AbortSignal.timeout(30_000),
    },
  );
  if (!groqResponse.ok) throw new Error('AI analysis is unavailable');
  return parseGroqAnalysis(await groqResponse.json());
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', {headers: corsHeaders});
  if (request.method !== 'POST') return json({error: 'Method not allowed'}, 405);

  const authorization = request.headers.get('Authorization');
  const url = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const groqApiKey = Deno.env.get('GROQ_API_KEY');
  const triggerSecret = Deno.env.get('INTERNAL_TRIGGER_SECRET');
  if (authorization == null) return json({error: 'Authentication required'}, 401);
  if (url == null || anonKey == null || serviceRoleKey == null || groqApiKey == null) {
    return json({error: 'Server configuration error'}, 500);
  }

  const adminClient = createClient(url, serviceRoleKey);
  const isSystemCall = triggerSecret != null && authorization === `Bearer ${triggerSecret}`;

  if (!isSystemCall) {
    const callerClient = createClient(url, anonKey, {
      global: {headers: {Authorization: authorization}},
    });
    const {data: callerData, error: callerError} = await callerClient.auth.getUser();
    if (callerError != null || callerData.user == null) {
      return json({error: 'Invalid session'}, 401);
    }

    const {data: profile, error: profileError} = await adminClient
        .from('profiles')
        .select('role, status')
        .eq('id', callerData.user.id)
        .single();
    if (
      profileError != null ||
      profile == null ||
      profile.role !== 'admin' ||
      profile.status !== 'active'
    ) {
      return json({error: 'Admin access required'}, 403);
    }
  }

  const rawBody = await request.json();

  if (rawBody != null && typeof rawBody === 'object' && 'preview' in rawBody) {
    try {
      const evidence = (rawBody as Record<string, unknown>).preview;
      if (evidence == null || typeof evidence !== 'object') {
        return json({error: 'preview must be an object'}, 400);
      }
      const analysis = await runAnalysis(evidence as Record<string, unknown>, groqApiKey);
      return json({analysis: {...analysis, generated_at: new Date().toISOString()}});
    } catch (error) {
      console.error('generate-anomaly-analysis preview failed', error);
      return json({error: 'Could not generate AI analysis'}, 500);
    }
  }

  try {
    const alertId = parseAlertId(rawBody);
    const {data: alert, error: alertError} = await adminClient
        .from('alerts')
        .select()
        .eq('id', alertId)
        .maybeSingle();
    if (alertError != null || alert == null) return json({error: 'Alert not found'}, 404);

    const analysis = await runAnalysis(alert, groqApiKey);
    const generatedAt = new Date().toISOString();
    const {error: saveError} = await adminClient
        .from('alerts')
        .update({
          ai_summary: analysis.summary,
          ai_possible_cause: analysis.possible_cause,
          ai_severity_assessment: analysis.severity_assessment,
          ai_recommendation: analysis.recommendation,
          ai_confidence: analysis.confidence,
          ai_generated_at: generatedAt,
        })
        .eq('id', alertId);
    if (saveError != null) throw saveError;

    return json({analysis: {...analysis, generated_at: generatedAt}});
  } catch (error) {
    if (error instanceof Error && error.message.startsWith('alert_id')) {
      return json({error: error.message}, 400);
    }
    console.error('generate-anomaly-analysis failed', error);
    return json({error: 'Could not generate AI analysis'}, 500);
  }
});
