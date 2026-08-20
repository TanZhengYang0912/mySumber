begin;

do $$
declare
  admin_id uuid;
  approved_case_id uuid;
  rejected_case_id uuid;
  created_alert_id bigint;
begin
  select id into admin_id
  from public.profiles
  where role = 'admin' and status = 'active'
  order by email
  limit 1;

  if admin_id is null then
    raise exception 'An active Admin profile is required for this smoke test';
  end if;

  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', admin_id, 'role', 'authenticated')::text,
    true
  );

  insert into public.anomaly_cases (
    source_scope, source_key, utility, state, household_id,
    severity, explanation, evidence, submitted_by,
    ai_summary, ai_possible_cause, ai_severity_assessment,
    ai_recommendation, ai_confidence, ai_generated_at
  ) values (
    'household', 'smoke:household:approved', 'water', 'Selangor', 'H-305',
    'medium', 'Pipe leaking under the kitchen sink.',
    '{"baseline_l": 150, "actual_l": 280}'::jsonb, admin_id,
    'Saved AI summary', 'Loose kitchen pipe', 'Medium',
    'Inspect the inlet pipe', 0.88, now()
  ) returning id into approved_case_id;

  select public.approve_anomaly_case(approved_case_id)
  into created_alert_id;

  if (select status from public.anomaly_cases where id = approved_case_id) <> 'approved' then
    raise exception 'Approved case did not become approved';
  end if;

  if not exists (
    select 1
    from public.alerts
    where id = created_alert_id
      and review_case_id = approved_case_id
      and source_scope = 'household'
      and utility_type = 'water'
      and ai_summary = 'Saved AI summary'
  ) then
    raise exception 'Approval did not create one source-aware Worker alert with saved AI';
  end if;

  insert into public.anomaly_cases (
    source_scope, source_key, utility, state, household_id,
    severity, explanation, evidence, submitted_by
  ) values (
    'household', 'smoke:household:rejected', 'electricity', 'Johor', 'H-902',
    'low', 'Intermittent lighting report.', '{}'::jsonb, admin_id
  ) returning id into rejected_case_id;

  perform public.reject_anomaly_case(rejected_case_id, 'Duplicate report');

  if (select status from public.anomaly_cases where id = rejected_case_id) <> 'rejected' then
    raise exception 'Rejected case did not become rejected';
  end if;

  if exists (select 1 from public.alerts where review_case_id = rejected_case_id) then
    raise exception 'Rejected case created a Worker alert';
  end if;
end
$$;

rollback;
