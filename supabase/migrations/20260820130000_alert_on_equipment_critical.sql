-- Auto-raise a worker alert when equipment is flagged Critical.
--
-- Demo path: `update public.equipment_nodes set status = 'Critical' where ...`
-- inserts an alert here, which in turn fires the alerts_ai_analysis trigger
-- (20260820060000) so the AI write-up lands a few seconds later — no app
-- interaction anywhere in the chain.

create or replace function public.alert_on_equipment_critical()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Only on the transition INTO Critical, so re-saving an already-Critical
  -- row from the equipment form never raises a duplicate.
  if new.status <> 'Critical' or old.status is not distinct from 'Critical' then
    return new;
  end if;

  -- One open alert per node. A resolved/dismissed one does not block a new
  -- alert, matching AppState._isActiveReport on the client.
  if exists (
    select 1 from public.alerts
    where equipment_node_id = new.node_id::text
      and is_deleted = false
      and status not in ('resolved', 'dismissed')
  ) then
    return new;
  end if;

  insert into public.alerts (
    alert_type, state, detected_at, signature, severity, explanation, status,
    is_deleted, equipment_node_id, facility_name, facility_city, equipment_name,
    data_year
  ) values (
    case when new.utility_type = 'Water'
         then 'nrw_hotspot' else 'electricity_hotspot' end,
    coalesce(new.zone_id, 'Malaysia'),
    now(),
    case when new.utility_type = 'Water'
         then 'NRW hotspot' else 'Electricity loss hotspot' end,
    'high',
    new.node_name || ' at ' ||
      coalesce(new.facility_name, 'an unlinked facility') ||
      ' was flagged Critical during maintenance inspection. Equipment in this '
      'state risks unmetered loss until serviced. Recommend an on-site '
      'inspection of the unit.',
    'pending',
    false,
    new.node_id::text,
    new.facility_name,
    new.facility_city,
    new.node_name,
    extract(year from now())::int
  );

  return new;
end;
$$;

drop trigger if exists equipment_critical_alert on public.equipment_nodes;
create trigger equipment_critical_alert
after update of status on public.equipment_nodes
for each row execute function public.alert_on_equipment_critical();
