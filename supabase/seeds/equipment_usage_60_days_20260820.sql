-- Replace the current equipment usage demo logs with 60 daily readings per
-- equipment node. The old rows are preserved in a locked-down backup schema.
--
-- Data conventions:
--   Water       usage_value = cubic metres per day (m3/day)
--   Electricity usage_value = kilowatt-hours per day (kWh/day)
--
-- This seed intentionally does not update equipment_nodes.status. The later
-- automatic-classification trigger will own that transition.

begin;

set local statement_timeout = '30s';
set local lock_timeout = '10s';

create schema if not exists mysumber_backup;
revoke all on schema mysumber_backup from public, anon, authenticated;

lock table public.equipment_usage_logs in access exclusive mode;

do $$
begin
  if to_regclass(
    'mysumber_backup.equipment_usage_logs_before_60d_20260820'
  ) is null then
    execute $backup$
      create table mysumber_backup.equipment_usage_logs_before_60d_20260820
      as table public.equipment_usage_logs
    $backup$;
  elsif not exists (
    select 1
    from mysumber_backup.equipment_usage_logs_before_60d_20260820
  ) then
    raise exception
      'Existing backup table equipment_usage_logs_before_60d_20260820 is empty';
  end if;
end
$$;

revoke all on table
  mysumber_backup.equipment_usage_logs_before_60d_20260820
from public, anon, authenticated;

comment on table
  mysumber_backup.equipment_usage_logs_before_60d_20260820
is 'Snapshot of equipment_usage_logs immediately before the 2026-08-20 realistic 60-day demo seed.';

delete from public.equipment_usage_logs;

with day_series as (
  select
    day_index,
    current_date - (59 - day_index)::integer as reading_date
  from generate_series(0, 59) as generated(day_index)
),
equipment_profiles as (
  select
    node.node_id,
    node.utility_type,
    node.node_name,
    node.equipment_type,
    node.facility_code,
    node.facility_name,
    case
      when lower(coalesce(node.equipment_type, node.node_name))
        like '%main water pump%' then 108.0
      when lower(coalesce(node.equipment_type, node.node_name))
        like '%cooling tower valve%' then 64.0
      when lower(coalesce(node.equipment_type, node.node_name))
        like '%transformer%' then 6200.0
      when node.utility_type = 'Water' then 82.0
      else 5000.0
    end as equipment_baseline,
    0.85 + (
      (
        ('x' || substr(md5(coalesce(
          node.facility_code,
          node.facility_name,
          node.node_id::text
        )), 1, 8))::bit(32)::bigint % 41
      )::double precision / 100.0
    ) as facility_factor,
    0.96 + (
      (
        ('x' || substr(md5(node.node_id::text || ':node'), 1, 8))
          ::bit(32)::bigint % 9
      )::double precision / 100.0
    ) as node_factor,
    (
      ('x' || substr(md5(node.node_id::text || ':phase'), 1, 8))
        ::bit(32)::bigint % 628
    )::double precision / 100.0 as phase,
    (
      ('x' || substr(md5(node.node_id::text || ':scenario'), 1, 8))
        ::bit(32)::bigint % 20
    )::integer as scenario
  from public.equipment_nodes as node
),
daily_patterns as (
  select
    profile.*,
    day.day_index,
    day.reading_date,
    case extract(isodow from day.reading_date)
      when 5 then 1.04
      when 6 then 1.12
      when 7 then 1.08
      else 1.00
    end as mall_day_factor,
    1.0 + 0.04 * sin(
      (2.0 * pi() * day.day_index::double precision / 14.0) + profile.phase
    ) as seasonal_factor,
    0.96 + (
      (
        ('x' || substr(md5(
          profile.node_id::text || ':' || day.reading_date::text
        ), 1, 8))::bit(32)::bigint % 9
      )::double precision / 100.0
    ) as noise_factor,
    case
      -- About 5% of nodes end with a sudden critical spike.
      when profile.scenario = 0 and day.day_index = 59 then 1.70
      -- About 5% end with a current warning-level leak/overload.
      when profile.scenario = 1 and day.day_index = 59 then 1.48
      -- About 5% contain a resolved historical critical event.
      when profile.scenario = 2 and day.day_index = 36 then 1.65
      -- About 5% contain a short historical warning event.
      when profile.scenario = 3 and day.day_index in (30, 31) then 1.30
      else 1.00
    end as event_factor
  from equipment_profiles as profile
  cross join day_series as day
),
raw_readings as (
  select
    gen_random_uuid() as log_id,
    node_id,
    (reading_date + time '00:00') at time zone 'UTC' as timestamp,
    round((
      equipment_baseline
      * facility_factor
      * node_factor
      * mall_day_factor
      * seasonal_factor
      * noise_factor
      * event_factor
    )::numeric, 2)::double precision as usage_value,
    event_factor
  from daily_patterns
),
generated_readings as (
  select
    reading.log_id,
    reading.node_id,
    reading.timestamp,
    reading.usage_value,
    coalesce(
      baseline.sample_count >= 5
      and reading.usage_value >= baseline.average_usage * 1.25,
      false
    ) as is_anomaly
  from raw_readings as reading
  left join lateral (
    select
      count(*)::integer as sample_count,
      avg(previous.usage_value) as average_usage
    from (
      select candidate.usage_value
      from raw_readings as candidate
      where candidate.node_id = reading.node_id
        and candidate.timestamp < reading.timestamp
        and candidate.event_factor = 1.00
      order by candidate.timestamp desc
      limit 7
    ) as previous
  ) as baseline on true
)
insert into public.equipment_usage_logs (
  log_id,
  node_id,
  timestamp,
  usage_value,
  is_anomaly
)
select
  log_id,
  node_id,
  timestamp,
  usage_value,
  is_anomaly
from generated_readings;

do $$
declare
  equipment_count integer;
  generated_count integer;
  backup_count integer;
begin
  select count(*) into equipment_count
  from public.equipment_nodes;

  select count(*) into generated_count
  from public.equipment_usage_logs;

  select count(*) into backup_count
  from mysumber_backup.equipment_usage_logs_before_60d_20260820;

  if generated_count <> equipment_count * 60 then
    raise exception
      'Expected % generated readings but found %',
      equipment_count * 60,
      generated_count;
  end if;

  if exists (
    select 1
    from public.equipment_nodes as node
    left join public.equipment_usage_logs as log
      on log.node_id = node.node_id
    group by node.node_id
    having count(log.log_id) <> 60
  ) then
    raise exception 'At least one equipment node does not have 60 readings';
  end if;

  if backup_count = 0 then
    raise exception 'The backup table is unexpectedly empty';
  end if;
end
$$;

commit;
