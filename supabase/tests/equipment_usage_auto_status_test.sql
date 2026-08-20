begin;

create extension if not exists pgtap with schema extensions;

select plan(11);

select hasnt_trigger(
  'public',
  'equipment_nodes',
  'equipment_critical_alert',
  'Critical status no longer creates alerts'
);

select has_trigger(
  'public',
  'equipment_usage_logs',
  'equipment_usage_auto_status',
  'Usage writes run automatic status classification'
);

insert into public.equipment_nodes (
  node_id,
  node_name,
  utility_type,
  status,
  asset_tag,
  health_score
) values
  (
    '10000000-0000-0000-0000-000000000001',
    'pgTAP Active Node',
    'Water',
    'Active',
    'PGTAP-AUTO-STATUS-1',
    100
  ),
  (
    '10000000-0000-0000-0000-000000000002',
    'pgTAP Maintenance Node',
    'Electricity',
    'Maintenance',
    'PGTAP-AUTO-STATUS-2',
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
  values
    ('10000000-0000-0000-0000-000000000001'::uuid),
    ('10000000-0000-0000-0000-000000000002'::uuid)
) as node(node_id)
cross join generate_series(0, 6) as days(day_number);

insert into public.equipment_usage_logs (
  log_id,
  node_id,
  timestamp,
  usage_value
) values (
  '20000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000001',
  '2026-01-08 00:00:00+00',
  130.0
);

select is(
  (select status from public.equipment_nodes
   where node_id = '10000000-0000-0000-0000-000000000001'),
  'Warning'::text,
  '1.30x baseline changes latest equipment status to Warning'
);

select is(
  (select is_anomaly from public.equipment_usage_logs
   where log_id = '20000000-0000-0000-0000-000000000001'),
  true,
  'Warning reading is marked anomalous'
);

update public.equipment_usage_logs
set usage_value = 160.0
where log_id = '20000000-0000-0000-0000-000000000001';

select is(
  (select status from public.equipment_nodes
   where node_id = '10000000-0000-0000-0000-000000000001'),
  'Critical'::text,
  '1.60x baseline changes latest equipment status to Critical'
);

select is(
  (select count(*)::integer from public.alerts
   where equipment_node_id in (
     '10000000-0000-0000-0000-000000000001',
     '10000000-0000-0000-0000-000000000002'
   )),
  0,
  'Automatic status changes never create alerts'
);

update public.equipment_usage_logs
set usage_value = 110.0
where log_id = '20000000-0000-0000-0000-000000000001';

select is(
  (select status from public.equipment_nodes
   where node_id = '10000000-0000-0000-0000-000000000001'),
  'Active'::text,
  'A normal latest reading recovers equipment status to Active'
);

select is(
  (select is_anomaly from public.equipment_usage_logs
   where log_id = '20000000-0000-0000-0000-000000000001'),
  false,
  'Recovered reading is no longer anomalous'
);

insert into public.equipment_usage_logs (
  log_id,
  node_id,
  timestamp,
  usage_value
) values (
  '20000000-0000-0000-0000-000000000002',
  '10000000-0000-0000-0000-000000000002',
  '2026-01-08 00:00:00+00',
  160.0
);

select is(
  (select status from public.equipment_nodes
   where node_id = '10000000-0000-0000-0000-000000000002'),
  'Maintenance'::text,
  'Automatic classification does not overwrite Maintenance'
);

select is(
  (select is_anomaly from public.equipment_usage_logs
   where log_id = '20000000-0000-0000-0000-000000000002'),
  true,
  'Maintenance equipment reading still records the anomaly'
);

update public.equipment_usage_logs
set usage_value = 300.0
where node_id = '10000000-0000-0000-0000-000000000001'
  and timestamp = '2026-01-01 00:00:00+00';

select is(
  (select status from public.equipment_nodes
   where node_id = '10000000-0000-0000-0000-000000000001'),
  'Active'::text,
  'Editing an older reading does not change current equipment status'
);

select * from finish();
rollback;
