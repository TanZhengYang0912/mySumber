begin;

do $$
declare
  active_node_id constant uuid := '10000000-0000-0000-0000-000000000001';
  maintenance_node_id constant uuid := '10000000-0000-0000-0000-000000000002';
  warning_log_id constant uuid := '20000000-0000-0000-0000-000000000001';
  maintenance_log_id constant uuid := '20000000-0000-0000-0000-000000000002';
  actual_status text;
  actual_anomaly boolean;
begin
  if exists (
    select 1
    from information_schema.triggers
    where trigger_schema = 'public'
      and event_object_table = 'equipment_nodes'
      and trigger_name = 'equipment_critical_alert'
  ) then
    raise exception 'equipment_critical_alert must not exist';
  end if;

  if not exists (
    select 1
    from information_schema.triggers
    where trigger_schema = 'public'
      and event_object_table = 'equipment_usage_logs'
      and trigger_name = 'equipment_usage_auto_status'
  ) then
    raise exception 'equipment_usage_auto_status must exist';
  end if;

  insert into public.equipment_nodes (
    node_id,
    node_name,
    utility_type,
    status,
    asset_tag,
    health_score
  ) values
    (
      active_node_id,
      'Smoke Active Node',
      'Water',
      'Active',
      'SMOKE-AUTO-STATUS-1',
      100
    ),
    (
      maintenance_node_id,
      'Smoke Maintenance Node',
      'Electricity',
      'Maintenance',
      'SMOKE-AUTO-STATUS-2',
      100
    );

  insert into public.equipment_usage_logs (
    log_id,
    node_id,
    timestamp,
    usage_value,
    is_anomaly
  )
  select
    gen_random_uuid(),
    node.node_id,
    timestamptz '2026-01-01 00:00:00+00' + day_number * interval '1 day',
    100.0,
    false
  from (
    values (active_node_id), (maintenance_node_id)
  ) as node(node_id)
  cross join generate_series(0, 6) as days(day_number);

  insert into public.equipment_usage_logs (
    log_id,
    node_id,
    timestamp,
    usage_value
  ) values (
    warning_log_id,
    active_node_id,
    '2026-01-08 00:00:00+00',
    130.0
  );

  select status into actual_status
  from public.equipment_nodes
  where node_id = active_node_id;
  if actual_status <> 'Warning' then
    raise exception 'expected Warning, got %', actual_status;
  end if;

  select is_anomaly into actual_anomaly
  from public.equipment_usage_logs
  where log_id = warning_log_id;
  if actual_anomaly is not true then
    raise exception 'warning reading must be anomalous';
  end if;

  update public.equipment_usage_logs
  set usage_value = 160.0
  where log_id = warning_log_id;

  select status into actual_status
  from public.equipment_nodes
  where node_id = active_node_id;
  if actual_status <> 'Critical' then
    raise exception 'expected Critical, got %', actual_status;
  end if;

  if exists (
    select 1
    from public.alerts
    where equipment_node_id in (active_node_id::text, maintenance_node_id::text)
  ) then
    raise exception 'automatic status changes must not create alerts';
  end if;

  update public.equipment_usage_logs
  set usage_value = 110.0
  where log_id = warning_log_id;

  select status, is_anomaly
  into actual_status, actual_anomaly
  from public.equipment_nodes as node
  join public.equipment_usage_logs as log
    on log.log_id = warning_log_id
  where node.node_id = active_node_id;
  if actual_status <> 'Active' or actual_anomaly is not false then
    raise exception 'normal reading must restore Active and false anomaly, got %, %',
      actual_status, actual_anomaly;
  end if;

  insert into public.equipment_usage_logs (
    log_id,
    node_id,
    timestamp,
    usage_value
  ) values (
    maintenance_log_id,
    maintenance_node_id,
    '2026-01-08 00:00:00+00',
    160.0
  );

  select status into actual_status
  from public.equipment_nodes
  where node_id = maintenance_node_id;
  if actual_status <> 'Maintenance' then
    raise exception 'maintenance status must not be overwritten, got %', actual_status;
  end if;

  select is_anomaly into actual_anomaly
  from public.equipment_usage_logs
  where log_id = maintenance_log_id;
  if actual_anomaly is not true then
    raise exception 'maintenance critical reading must be anomalous';
  end if;

  update public.equipment_usage_logs
  set usage_value = 300.0
  where node_id = active_node_id
    and timestamp = '2026-01-01 00:00:00+00';

  select status into actual_status
  from public.equipment_nodes
  where node_id = active_node_id;
  if actual_status <> 'Active' then
    raise exception 'historical update must not change latest status, got %', actual_status;
  end if;
end;
$$;

rollback;
