-- Fill only missing daily equipment usage readings from 2026-06-22 through
-- 2026-09-01. Existing readings are never overwritten.

begin;

set local statement_timeout = '60s';
set local lock_timeout = '10s';

create temporary table equipment_usage_backfill_seed on commit drop as
select
  node.node_id,
  coalesce(
    (
      select avg(recent.usage_value)
      from (
        select log.usage_value
        from public.equipment_usage_logs as log
        where log.node_id = node.node_id
          and log.is_anomaly = false
        order by log.timestamp desc
        limit 7
      ) as recent
    ),
    case lower(coalesce(node.equipment_type, node.node_name, ''))
      when 'cooling tower' then 71.0
      when 'water pump' then 119.0
      when 'main water pump' then 119.0
      when 'toilet' then 99.0
      when 'water pipe' then 92.0
      when 'valve' then 65.0
      when 'transformer' then 6860.0
      when 'chiller' then 8170.0
      when 'hvac' then 5000.0
      when 'lighting' then 1400.0
      when 'escalator' then 900.0
      else case
        when node.utility_type = 'Water' then 90.0
        else 3000.0
      end
    end
  )::double precision as baseline_usage,
  0.96 + (
    (
      ('x' || substr(md5(node.node_id::text || ':node'), 1, 8))
        ::bit(32)::bigint % 9
    )::double precision / 100.0
  ) as node_factor,
  (
    ('x' || substr(md5(node.node_id::text || ':phase'), 1, 8))
      ::bit(32)::bigint % 628
  )::double precision / 100.0 as phase
from public.equipment_nodes as node;

do $backfill$
declare
  target_day date;
  inserted_for_day integer;
  inserted_total integer := 0;
begin
  for target_day in
    select generated.day::date
    from generate_series(
      date '2026-06-22',
      date '2026-09-01',
      interval '1 day'
    ) as generated(day)
    order by generated.day
  loop
    insert into public.equipment_usage_logs (
      log_id,
      node_id,
      timestamp,
      usage_value,
      is_anomaly
    )
    select
      md5(
        'mysumber-normal-backfill-v1|' || node.node_id::text || '|' ||
        target_day::text
      )::uuid,
      node.node_id,
      (target_day + time '00:00') at time zone 'UTC',
      round((
        seed.baseline_usage
        * seed.node_factor
        * case extract(isodow from target_day)
            when 5 then 1.03
            when 6 then 1.10
            when 7 then 1.07
            else 1.00
          end
        * (1.0 + 0.02 * sin(
            (2.0 * pi() * (target_day - date '2026-06-22') / 14.0)
            + seed.phase
          ))
        * (
          0.98 + (
            (
              ('x' || substr(md5(
                node.node_id::text || ':' || target_day::text
              ), 1, 8))::bit(32)::bigint % 5
            )::double precision / 100.0
          )
        )
      )::numeric, 2)::double precision,
      false
    from public.equipment_nodes as node
    join equipment_usage_backfill_seed as seed
      on seed.node_id = node.node_id
    where not exists (
      select 1
      from public.equipment_usage_logs as existing
      where existing.node_id = node.node_id
        and existing.timestamp =
          (target_day + time '00:00') at time zone 'UTC'
    )
    order by node.node_id
    on conflict (node_id, timestamp) do nothing;

    get diagnostics inserted_for_day = row_count;
    inserted_total := inserted_total + inserted_for_day;
  end loop;

  raise notice 'Inserted % missing equipment usage readings', inserted_total;
end
$backfill$;

-- Recovery reference only; do not run during normal deployment.
-- It removes only rows whose deterministic IDs belong to this backfill:
--
-- delete from public.equipment_usage_logs as log
-- using public.equipment_nodes as node,
--   generate_series(
--     date '2026-06-22', date '2026-09-01', interval '1 day'
--   ) as generated(day)
-- where log.node_id = node.node_id
--   and log.log_id = md5(
--     'mysumber-normal-backfill-v1|' || node.node_id::text || '|' ||
--     generated.day::date::text
--   )::uuid;

commit;
