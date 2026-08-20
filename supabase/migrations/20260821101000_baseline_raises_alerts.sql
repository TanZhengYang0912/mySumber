-- Alert creation moves onto the baseline path. Recreating
-- equipment_critical_alert earlier today contradicted the 2026-08-20
-- auto-status specification; this drops it for good and folds alert creation
-- into the function that already knows the classification.
drop trigger if exists equipment_critical_alert on public.equipment_nodes;
drop function if exists public.alert_on_equipment_critical();

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
  node_row public.equipment_nodes%rowtype;
  has_open_alert boolean;
begin
  select * into node_row
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

  if not is_latest then
    return new;
  end if;

  -- Maintenance is a person's own flag. Never overwrite it, and never raise a
  -- review item for equipment someone is already servicing.
  if node_row.status = 'Maintenance' then
    return new;
  end if;

  update public.equipment_nodes
  set status = calculated_status
  where node_id = new.node_id;

  if not new.is_anomaly then
    return new;
  end if;

  -- One open item per node. Once an alert is faulted, resolved or dismissed a
  -- fresh spike raises a new one, so the same node can be demonstrated twice
  -- without a manual reset.
  select exists (
    select 1
    from public.alerts
    where equipment_node_id = new.node_id::text
      and is_deleted = false
      and status in ('pending_review', 'pending', 'investigating', 'not_fixed')
  ) into has_open_alert;

  if has_open_alert then
    return new;
  end if;

  insert into public.alerts (
    alert_type, state, detected_at, signature, severity, explanation, status,
    is_deleted, equipment_node_id, facility_name, facility_city, equipment_name,
    data_year, source_scope, utility_type, source_key
  ) values (
    case when node_row.utility_type = 'Water'
         then 'nrw_hotspot' else 'electricity_hotspot' end,
    coalesce(node_row.zone_id, 'Malaysia'),
    now(),
    case when node_row.utility_type = 'Water'
         then 'NRW hotspot' else 'Electricity loss hotspot' end,
    case when calculated_status = 'Critical' then 'high' else 'medium' end,
    node_row.node_name || ' at ' ||
      coalesce(node_row.facility_name, 'an unlinked facility') ||
      ' recorded ' || round((new.usage_value / baseline_value)::numeric, 2) ||
      'x its normal usage (' || round(new.usage_value::numeric, 1) ||
      ' against a ' || round(baseline_value::numeric, 1) ||
      ' baseline from its last seven readings). Equipment drawing this far ' ||
      'above baseline risks unmetered loss until serviced. Recommend an ' ||
      'on-site inspection of the unit.',
    'pending_review', false, new.node_id::text, node_row.facility_name,
    node_row.facility_city, node_row.node_name,
    extract(year from new.timestamp)::int,
    'mall',
    case when node_row.utility_type = 'Water' then 'water' else 'electricity' end,
    'mall:' || new.node_id::text || ':' ||
      to_char(new.timestamp, 'YYYY-MM-DD"T"HH24:MI:SS')
  );

  return new;
end;
$$;

comment on function public.classify_equipment_usage() is
  'Classifies a reading against the previous seven normal readings, updates the '
  'latest equipment status, and raises one pending_review alert per open '
  'incident. Maintenance equipment is never reclassified and never alerted.';
