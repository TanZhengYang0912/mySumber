begin;

create extension if not exists pgtap with schema extensions;

select plan(12);

select hasnt_trigger(
  'public', 'equipment_nodes', 'equipment_critical_alert',
  'Equipment status changes never create alerts'
);

select has_trigger(
  'public', 'equipment_usage_logs', 'equipment_usage_auto_status',
  'Usage writes run automatic status classification'
);

insert into public.equipment_nodes (
  node_id, node_name, utility_type, status, asset_tag
) values
  ('10000000-0000-0000-0000-000000000001', 'pgTAP Active Node',
   'Water', 'Active', 'PGTAP-AUTO-1'),
  ('10000000-0000-0000-0000-000000000002', 'pgTAP Maintenance Node',
   'Electricity', 'Maintenance', 'PGTAP-AUTO-2');

insert into public.equipment_usage_logs (
  log_id, node_id, timestamp, usage_value, is_anomaly
)
select
  gen_random_uuid(),
  node.node_id,
  timestamptz '2026-01-01 00:00:00+00' + day_number * interval '1 day',
  100.0,
  false
from (values
  ('10000000-0000-0000-0000-000000000001'::uuid),
  ('10000000-0000-0000-0000-000000000002'::uuid)
) as node(node_id)
cross join generate_series(0, 6) as days(day_number);

-- 1.30x baseline -> Warning, medium-severity alert
insert into public.equipment_usage_logs (log_id, node_id, timestamp, usage_value)
values ('20000000-0000-0000-0000-000000000001',
        '10000000-0000-0000-0000-000000000001',
        '2026-01-08 00:00:00+00', 130.0);

select is(
  (select status from public.equipment_nodes
   where node_id = '10000000-0000-0000-0000-000000000001'),
  'Warning'::text,
  '1.30x baseline sets latest equipment status to Warning'
);

select is(
  (select severity from public.alerts
   where equipment_node_id = '10000000-0000-0000-0000-000000000001'),
  'medium'::text,
  'A Warning reading raises a medium-severity alert'
);

select is(
  (select status from public.alerts
   where equipment_node_id = '10000000-0000-0000-0000-000000000001'),
  'pending_review'::text,
  'A baseline alert starts in pending_review'
);

-- A second spike must NOT raise a duplicate while the first is still open
insert into public.equipment_usage_logs (log_id, node_id, timestamp, usage_value)
values ('20000000-0000-0000-0000-000000000003',
        '10000000-0000-0000-0000-000000000001',
        '2026-01-09 00:00:00+00', 200.0);

select is(
  (select count(*)::integer from public.alerts
   where equipment_node_id = '10000000-0000-0000-0000-000000000001'),
  1,
  'An open alert suppresses a duplicate for the same node'
);

select is(
  (select status from public.equipment_nodes
   where node_id = '10000000-0000-0000-0000-000000000001'),
  'Critical'::text,
  '2.00x baseline still escalates the equipment status to Critical'
);

-- Maintenance equipment: reading is flagged, status held, no alert
insert into public.equipment_usage_logs (log_id, node_id, timestamp, usage_value)
values ('20000000-0000-0000-0000-000000000002',
        '10000000-0000-0000-0000-000000000002',
        '2026-01-08 00:00:00+00', 160.0);

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
  'Maintenance equipment still records the anomaly on the reading'
);

select is(
  (select count(*)::integer from public.alerts
   where equipment_node_id = '10000000-0000-0000-0000-000000000002'),
  0,
  'Maintenance equipment never raises an alert'
);

-- Editing an older reading must not move current status
update public.equipment_usage_logs
set usage_value = 300.0
where node_id = '10000000-0000-0000-0000-000000000001'
  and timestamp = '2026-01-01 00:00:00+00';

select is(
  (select status from public.equipment_nodes
   where node_id = '10000000-0000-0000-0000-000000000001'),
  'Critical'::text,
  'Editing an older reading does not change current equipment status'
);

-- Recovery: a normal latest reading returns the node to Active
insert into public.equipment_usage_logs (log_id, node_id, timestamp, usage_value)
values ('20000000-0000-0000-0000-000000000004',
        '10000000-0000-0000-0000-000000000001',
        '2026-01-10 00:00:00+00', 105.0);

select is(
  (select status from public.equipment_nodes
   where node_id = '10000000-0000-0000-0000-000000000001'),
  'Active'::text,
  'A normal latest reading recovers equipment status to Active'
);

select * from finish();
rollback;
