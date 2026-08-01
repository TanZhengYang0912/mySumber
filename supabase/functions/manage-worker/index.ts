import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

import { isActiveAdmin, parseWorkerAction } from './worker_actions.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
      'authorization, x-client-info, apikey, content-type',
};

Response.json = Response.json ?? ((data: unknown, init?: ResponseInit) =>
    new Response(JSON.stringify(data), {
      ...init,
      headers: {'Content-Type': 'application/json', ...init?.headers},
    }));

function json(data: unknown, status = 200) {
  return Response.json(data, {
    status,
    headers: corsHeaders,
  });
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', {headers: corsHeaders});
  }

  if (request.method !== 'POST') {
    return json({error: 'Method not allowed'}, 405);
  }

  const authorization = request.headers.get('Authorization');
  if (authorization == null) return json({error: 'Missing authorization'}, 401);

  const url = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (url == null || anonKey == null || serviceRoleKey == null) {
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
    if (profileError != null || profile == null || !isActiveAdmin(profile)) {
      return json({error: 'Admin access required'}, 403);
    }

    const action = parseWorkerAction(await request.json());
    if (action.action === 'create') {
      const {data: invited, error: inviteError} =
          await adminClient.auth.admin.inviteUserByEmail(action.email, {
            redirectTo: 'io.supabase.mysumber://login-callback',
            data: {
              display_name: action.fullName,
              must_set_password: true,
            },
          });
      if (inviteError != null || invited.user == null) {
        return json({error: inviteError?.message ?? 'Could not invite worker'}, 400);
      }
      const workerId = invited.user.id;
      const {error: authError} = await adminClient.auth.admin.updateUserById(workerId, {
        app_metadata: {role: 'worker'},
      });
      if (authError != null) throw authError;
      const {error: upsertError} = await adminClient.from('profiles').upsert({
        id: workerId,
        full_name: action.fullName,
        email: action.email,
        role: 'worker',
        status: 'active',
      });
      if (upsertError != null) throw upsertError;
      return json({worker: {id: workerId, fullName: action.fullName, email: action.email, status: 'active'}});
    }

    if (action.action === 'update') {
      const {error} = await adminClient.from('profiles')
          .update({full_name: action.fullName})
          .eq('id', action.workerId)
          .eq('role', 'worker');
      if (error != null) throw error;
      return json({success: true});
    }

    const inactive = action.action === 'deactivate';
    const {error: statusError} = await adminClient.from('profiles')
        .update({status: inactive ? 'inactive' : 'active'})
        .eq('id', action.workerId)
        .eq('role', 'worker');
    if (statusError != null) throw statusError;
    const {error: authError} = await adminClient.auth.admin.updateUserById(action.workerId, {
      ban_duration: inactive ? '876000h' : 'none',
    });
    if (authError != null) throw authError;
    return json({success: true});
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Could not manage worker';
    return json({error: message}, 400);
  }
});
