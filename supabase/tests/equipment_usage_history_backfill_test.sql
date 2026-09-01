begin;

create extension if not exists pgtap with schema extensions;

select plan(5);

create temporary table target_equipment_usage_days on commit drop as
select
  (generated.day::date + time '00:00') at time zone 'UTC' as timestamp
from generate_series(
  date '2026-06-22',
  date '2026-09-01',
  interval '1 day'
) as generated(day);

select is(
  (
    select count(*)::bigint
    from public.equipment_nodes as node
    cross join target_equipment_usage_days as target
    where not exists (
      select 1
      from public.equipment_usage_logs as log
      where log.node_id = node.node_id
        and log.timestamp = target.timestamp
    )
  ),
  0::bigint,
  'Every equipment node has all 72 canonical daily readings'
);

select is(
  (
    select count(*)::bigint
    from (
      select node.node_id
      from public.equipment_nodes as node
      join target_equipment_usage_days as target on true
      join public.equipment_usage_logs as log
        on log.node_id = node.node_id
       and log.timestamp = target.timestamp
      group by node.node_id
      having count(*) <> 72
    ) as incomplete
  ),
  0::bigint,
  'Each equipment node has exactly one reading at each canonical timestamp'
);

select is(
  (
    select count(*)::bigint
    from public.equipment_usage_logs as log
    join public.equipment_nodes as node on node.node_id = log.node_id
    cross join target_equipment_usage_days as target
    where log.log_id = md5(
      'mysumber-normal-backfill-v1|' || node.node_id::text || '|' ||
      ((target.timestamp at time zone 'UTC')::date)::text
    )::uuid
      and log.timestamp = target.timestamp
      and log.is_anomaly
  ),
  0::bigint,
  'Every generated reading is non-anomalous'
);

select ok(
  not exists (
    select 1
    from public.equipment_nodes as node
    where node.status not in ('Active', 'Maintenance')
  ),
  'Every non-Maintenance equipment node finishes Active'
);

select is(
  (
    select count(*)::bigint
    from (
      select log.node_id, log.timestamp
      from public.equipment_usage_logs as log
      group by log.node_id, log.timestamp
      having count(*) > 1
    ) as duplicate
  ),
  0::bigint,
  'No duplicate node and timestamp pair exists'
);

select * from finish();
rollback;
