import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

import { anomalyPrompt, parseAlertId, parseGroqAnalysis } from './anomaly_ai.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
      'authorization, x-client-info, apikey, content-type',
};

const groqModel = 'llama-3.1-8b-instant';

function json(data: unknown, status = 200) {
  return Response.json(data, {status, headers: corsHeaders});
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', {headers: corsHeaders});
  if (request.method !== 'POST') return json({error: 'Method not allowed'}, 405);

  const authorization = request.headers.get('Authorization');
  const url = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const groqApiKey = Deno.env.get('GROQ_API_KEY');
  if (authorization == null) return json({error: 'Authentication required'}, 401);
  if (url == null || anonKey == null || serviceRoleKey == null || groqApiKey == null) {
    return json({error: 'Server configuration error'}, 500);
  }

  const callerClient = createClient(url, anonKey, {
    global: {headers: {Authorization: authorization}},
  });
  const adminClient = createClient(url, serviceRoleKey);

  try {
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

    const alertId = parseAlertId(await request.json());
    const {data: alert, error: alertError} = await adminClient
        .from('alerts')
        .select()
        .eq('id', alertId)
        .maybeSingle();
    if (alertError != null || alert == null) return json({error: 'Alert not found'}, 404);

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
            {role: 'user', content: anomalyPrompt(alert)},
          ],
          response_format: {type: 'json_object'},
          temperature: 0.3,
          max_tokens: 512,
        }),
        signal: AbortSignal.timeout(30_000),
      },
    );
    if (!groqResponse.ok) return json({error: 'AI analysis is unavailable'}, 502);

    const analysis = parseGroqAnalysis(await groqResponse.json());
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
