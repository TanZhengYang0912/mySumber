-- This trigger has been live in Supabase since 2026-08-20 but its migration was
-- removed from the repo by commit 08da2de (a git revert that did not roll back
-- the database). Re-committing it so local files and remote schema agree.
create or replace function public.classify_equipment_usage()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  baseline_value double precision;
  baseline_count integer;
  calculated_status text;
  is_latest boolean;
begin
  perform 1
  from public.equipment_nodes as node
  where node.node_id = new.node_id
  for update;

  select
    count(*)::integer,
    avg(recent.usage_value)
  into baseline_count, baseline_value
  from (
    select log.usage_value
    from public.equipment_usage_logs as log
    where log.node_id = new.node_id
      and log.log_id is distinct from new.log_id
      and log.timestamp < new.timestamp
      and log.is_anomaly = false
    order by log.timestamp desc
    limit 7
  ) as recent;

  if baseline_count < 7 or baseline_value is null or baseline_value <= 0 then
    new.is_anomaly := false;
    return new;
  end if;

  calculated_status := case
    when new.usage_value >= baseline_value * 1.50 then 'Critical'
    when new.usage_value >= baseline_value * 1.25 then 'Warning'
    else 'Active'
  end;

  new.is_anomaly := calculated_status in ('Warning', 'Critical');

  select not exists (
    select 1
    from public.equipment_usage_logs as later
    where later.node_id = new.node_id
      and later.log_id is distinct from new.log_id
      and later.timestamp > new.timestamp
  )
  into is_latest;

  if is_latest then
    update public.equipment_nodes
    set status = calculated_status
    where node_id = new.node_id
      and status <> 'Maintenance';
  end if;

  return new;
end;
$$;

drop trigger if exists equipment_usage_auto_status
  on public.equipment_usage_logs;
create trigger equipment_usage_auto_status
before insert or update of usage_value
on public.equipment_usage_logs
for each row
execute function public.classify_equipment_usage();
