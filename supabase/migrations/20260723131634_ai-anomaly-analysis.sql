alter table public.alerts
  add column if not exists ai_summary text,
  add column if not exists ai_possible_cause text,
  add column if not exists ai_severity_assessment text,
  add column if not exists ai_recommendation text,
  add column if not exists ai_confidence numeric,
  add column if not exists ai_generated_at timestamptz;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.alerts'::regclass
      and conname = 'alerts_ai_confidence_range'
  ) then
    alter table public.alerts
      add constraint alerts_ai_confidence_range
      check (ai_confidence is null or (ai_confidence >= 0 and ai_confidence <= 1));
  end if;
end
$$;
