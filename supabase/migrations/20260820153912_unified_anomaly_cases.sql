-- Durable Admin-review queue. Only approved cases become Worker alerts.

create extension if not exists pgcrypto;
create schema if not exists private;

create table if not exists public.anomaly_cases (
  id uuid primary key default gen_random_uuid(),
  source_scope text not null
    check (source_scope in ('state', 'mall', 'household')),
  source_key text not null unique,
  utility text not null check (utility in ('water', 'electricity')),
  state text not null,
  facility_name text,
  equipment_node_id text,
  equipment_name text,
  household_id text,
  severity text not null check (severity in ('low', 'medium', 'high')),
  explanation text not null,
  evidence jsonb not null default '{}'::jsonb,
  status text not null default 'pending_review'
    check (status in ('pending_review', 'approved', 'rejected')),
  rejection_reason text,
  submitted_by uuid references public.profiles(id) on delete set null,
  reviewed_by uuid references public.profiles(id) on delete set null,
  reviewed_at timestamptz,
  ai_summary text,
  ai_possible_cause text,
  ai_severity_assessment text,
  ai_recommendation text,
  ai_confidence numeric
    check (ai_confidence is null or (ai_confidence >= 0 and ai_confidence <= 1)),
  ai_generated_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (
    (source_scope = 'state' and facility_name is null and equipment_node_id is null
      and equipment_name is null and household_id is null)
    or (source_scope = 'mall' and facility_name is not null and equipment_node_id is not null
      and equipment_name is not null and household_id is null)
    or (source_scope = 'household' and household_id is not null
      and facility_name is null and equipment_node_id is null and equipment_name is null)
  )
);

create index if not exists anomaly_cases_status_created_at_idx
  on public.anomaly_cases (status, created_at desc);
create index if not exists anomaly_cases_source_scope_utility_idx
  on public.anomaly_cases (source_scope, utility);
create index if not exists anomaly_cases_submitted_by_idx
  on public.anomaly_cases (submitted_by);

alter table public.alerts
  add column if not exists review_case_id uuid
    references public.anomaly_cases(id) on delete set null,
  add column if not exists source_scope text,
  add column if not exists utility_type text;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.alerts'::regclass
      and conname = 'alerts_source_scope_check'
  ) then
    alter table public.alerts add constraint alerts_source_scope_check
      check (source_scope is null or source_scope in ('state', 'mall', 'household'));
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.alerts'::regclass
      and conname = 'alerts_utility_type_check'
  ) then
    alter table public.alerts add constraint alerts_utility_type_check
      check (utility_type is null or utility_type in ('water', 'electricity'));
  end if;
end
$$;

create unique index if not exists alerts_review_case_id_key
  on public.alerts (review_case_id)
  where review_case_id is not null;
create index if not exists alerts_source_scope_utility_type_idx
  on public.alerts (source_scope, utility_type);

create or replace function private.is_active_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles profile
    where profile.id = (select auth.uid())
      and profile.role = 'admin'
      and profile.status = 'active'
  );
$$;

revoke all on function private.is_active_admin() from public;
grant usage on schema private to authenticated;
grant execute on function private.is_active_admin() to authenticated;

create or replace function private.touch_anomaly_case_updated_at()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

revoke all on function private.touch_anomaly_case_updated_at() from public;

drop trigger if exists touch_anomaly_case_updated_at on public.anomaly_cases;
create trigger touch_anomaly_case_updated_at
before update on public.anomaly_cases
for each row execute function private.touch_anomaly_case_updated_at();

alter table public.anomaly_cases enable row level security;
revoke all on public.anomaly_cases from anon, authenticated;
grant select, insert, update on public.anomaly_cases to authenticated;

create policy "Customers can submit their own household cases"
  on public.anomaly_cases for insert to authenticated
  with check (
    source_scope = 'household'
    and submitted_by = (select auth.uid())
    and status = 'pending_review'
    and reviewed_by is null
    and reviewed_at is null
    and rejection_reason is null
  );

create policy "Customers can view their own household cases"
  on public.anomaly_cases for select to authenticated
  using (
    source_scope = 'household'
    and submitted_by = (select auth.uid())
  );

create policy "Active admins can manage all anomaly cases"
  on public.anomaly_cases for all to authenticated
  using ((select private.is_active_admin()))
  with check ((select private.is_active_admin()));

create or replace function public.approve_anomaly_case(p_case_id uuid)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  selected_case public.anomaly_cases%rowtype;
  created_alert_id bigint;
  selected_alert_type text;
begin
  if not private.is_active_admin() then
    raise exception 'Active admin account required';
  end if;

  select * into selected_case
  from public.anomaly_cases
  where id = p_case_id
  for update;

  if not found then
    raise exception 'Anomaly case not found';
  end if;
  if selected_case.status <> 'pending_review' then
    raise exception 'Only pending-review cases can be approved';
  end if;

  selected_alert_type := case
    when selected_case.source_scope = 'household' then 'household'
    when selected_case.utility = 'water' then 'nrw_hotspot'
    else 'electricity_hotspot'
  end;

  insert into public.alerts (
    alert_type, household_id, state, detected_at, signature, severity,
    baseline_l, actual_l, explanation, status, is_deleted,
    equipment_node_id, facility_name, facility_city, equipment_name, data_year,
    source_scope, utility_type, review_case_id,
    ai_summary, ai_possible_cause, ai_severity_assessment,
    ai_recommendation, ai_confidence, ai_generated_at
  ) values (
    selected_alert_type,
    selected_case.household_id,
    selected_case.state,
    now(),
    case selected_case.source_scope
      when 'state' then initcap(selected_case.utility) || ' state anomaly'
      when 'mall' then coalesce(selected_case.equipment_name, 'Mall equipment') || ' anomaly'
      else 'Household utility problem'
    end,
    selected_case.severity,
    coalesce(nullif(selected_case.evidence ->> 'baseline_l', '')::double precision, 0),
    coalesce(nullif(selected_case.evidence ->> 'actual_l', '')::double precision, 0),
    selected_case.explanation,
    'pending',
    false,
    selected_case.equipment_node_id,
    selected_case.facility_name,
    null,
    selected_case.equipment_name,
    extract(year from now())::integer,
    selected_case.source_scope,
    selected_case.utility,
    selected_case.id,
    selected_case.ai_summary,
    selected_case.ai_possible_cause,
    selected_case.ai_severity_assessment,
    selected_case.ai_recommendation,
    selected_case.ai_confidence,
    selected_case.ai_generated_at
  ) returning id into created_alert_id;

  update public.anomaly_cases
  set status = 'approved',
      reviewed_by = (select auth.uid()),
      reviewed_at = now(),
      rejection_reason = null
  where id = selected_case.id;

  return created_alert_id;
end;
$$;

create or replace function public.reject_anomaly_case(p_case_id uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  selected_case public.anomaly_cases%rowtype;
begin
  if not private.is_active_admin() then
    raise exception 'Active admin account required';
  end if;
  if nullif(btrim(p_reason), '') is null then
    raise exception 'A rejection reason is required';
  end if;

  select * into selected_case
  from public.anomaly_cases
  where id = p_case_id
  for update;

  if not found then
    raise exception 'Anomaly case not found';
  end if;
  if selected_case.status <> 'pending_review' then
    raise exception 'Only pending-review cases can be rejected';
  end if;

  update public.anomaly_cases
  set status = 'rejected',
      rejection_reason = btrim(p_reason),
      reviewed_by = (select auth.uid()),
      reviewed_at = now()
  where id = selected_case.id;
end;
$$;

revoke all on function public.approve_anomaly_case(uuid) from public;
revoke all on function public.reject_anomaly_case(uuid, text) from public;
grant execute on function public.approve_anomaly_case(uuid) to authenticated;
grant execute on function public.reject_anomaly_case(uuid, text) to authenticated;

create or replace function public.request_anomaly_analysis()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  trigger_secret text;
begin
  -- An approved case already carries saved AI fields; never regenerate it.
  if new.ai_generated_at is not null then
    return new;
  end if;

  select decrypted_secret into trigger_secret
  from vault.decrypted_secrets
  where name = 'internal_trigger_secret';

  if trigger_secret is null then
    return new;
  end if;

  perform net.http_post(
    url := 'https://tnmznkdvrrpigevxdfet.supabase.co/functions/v1/generate-anomaly-analysis',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || trigger_secret
    ),
    body := jsonb_build_object('alert_id', new.id)
  );

  return new;
end;
$$;

create or replace function public.request_anomaly_case_analysis()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  trigger_secret text;
begin
  select decrypted_secret into trigger_secret
  from vault.decrypted_secrets
  where name = 'internal_trigger_secret';

  if trigger_secret is null then
    return new;
  end if;

  perform net.http_post(
    url := 'https://tnmznkdvrrpigevxdfet.supabase.co/functions/v1/generate-anomaly-analysis',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || trigger_secret
    ),
    body := jsonb_build_object('case_id', new.id)
  );

  return new;
end;
$$;

drop trigger if exists anomaly_cases_ai_analysis on public.anomaly_cases;
create trigger anomaly_cases_ai_analysis
after insert on public.anomaly_cases
for each row execute function public.request_anomaly_case_analysis();
