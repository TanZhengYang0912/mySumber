-- Equipment alerts now land in the admin review queue rather than straight in
-- the worker queue. source_key replaces the old "is there an open alert?"
-- scan, so a rejected alert is not silently recreated.
create or replace function public.alert_on_equipment_critical()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status <> 'Critical' or old.status is not distinct from 'Critical' then
    return new;
  end if;

  insert into public.alerts (
    alert_type, state, detected_at, signature, severity, explanation, status,
    is_deleted, equipment_node_id, facility_name, facility_city, equipment_name,
    data_year, source_scope, utility_type, source_key
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
    'pending_review', false, new.node_id::text, new.facility_name,
    new.facility_city, new.node_name, extract(year from now())::int,
    'mall',
    case when new.utility_type = 'Water' then 'water' else 'electricity' end,
    'mall:' || new.node_id::text || ':' ||
      to_char(now(), 'YYYY-MM')
  )
  on conflict (source_key) do nothing;

  return new;
end;
$$;

-- The trigger binding itself was missing in this environment (the function
-- existed from an earlier round, but no trigger called it — confirmed via
-- pg_trigger before this migration). Recreate it explicitly rather than
-- assuming it survived.
drop trigger if exists equipment_critical_alert on public.equipment_nodes;
create trigger equipment_critical_alert
after update of status on public.equipment_nodes
for each row execute function public.alert_on_equipment_critical();
