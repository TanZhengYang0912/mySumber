-- Consolidate historical equipment rows that describe the same physical
-- device, then enforce normalized identity keys for future writes.
-- Run after 20260814120000_equipment_catalogs_and_asset_tags.sql.

begin;

-- Pick one keeper for every pair that shares a normalized asset tag, serial
-- number, or IP address. Real asset tags and records with more identity data
-- win over generated LEGACY-* rows. The node_id tie-breaker makes the result
-- deterministic and prevents two-way mappings.
create temporary table equipment_identity_pairs (
  duplicate_id uuid primary key,
  keeper_id uuid not null
) on commit drop;

with pairs as (
  select
    a.node_id as a_id,
    b.node_id as b_id,
    (
      case when nullif(trim(a.asset_tag), '') is not null
        and upper(trim(a.asset_tag)) not like 'LEGACY-%' then 100 else 0 end
      + case when nullif(trim(a.serial_number), '') is not null then 4 else 0 end
      + case when nullif(trim(a.ip_address), '') is not null then 4 else 0 end
      + case when a.facility_id is not null then 2 else 0 end
      + case when a.model_id is not null then 2 else 0 end
    ) as a_score,
    (
      case when nullif(trim(b.asset_tag), '') is not null
        and upper(trim(b.asset_tag)) not like 'LEGACY-%' then 100 else 0 end
      + case when nullif(trim(b.serial_number), '') is not null then 4 else 0 end
      + case when nullif(trim(b.ip_address), '') is not null then 4 else 0 end
      + case when b.facility_id is not null then 2 else 0 end
      + case when b.model_id is not null then 2 else 0 end
    ) as b_score
  from public.equipment_nodes a
  join public.equipment_nodes b on a.node_id < b.node_id
  where (
    nullif(trim(a.asset_tag), '') is not null
    and nullif(trim(b.asset_tag), '') is not null
    and upper(trim(a.asset_tag)) = upper(trim(b.asset_tag))
  ) or (
    nullif(trim(a.serial_number), '') is not null
    and nullif(trim(b.serial_number), '') is not null
    and upper(trim(a.serial_number)) = upper(trim(b.serial_number))
  ) or (
    nullif(trim(a.ip_address), '') is not null
    and nullif(trim(b.ip_address), '') is not null
    and upper(trim(a.ip_address)) = upper(trim(b.ip_address))
  )
), directed as (
  select
    case
      when a_score > b_score or (a_score = b_score and a_id < b_id)
        then b_id else a_id
    end as duplicate_id,
    case
      when a_score > b_score or (a_score = b_score and a_id < b_id)
        then a_id else b_id
    end as keeper_id
  from pairs
), ranked as (
  select
    duplicate_id,
    keeper_id,
    row_number() over (
      partition by duplicate_id
      order by keeper_id
    ) as row_number
  from directed
)
insert into equipment_identity_pairs (duplicate_id, keeper_id)
select duplicate_id, keeper_id
from ranked
where row_number = 1;

-- Resolve chains such as legacy row -> imported row -> corrected row.
create temporary table equipment_identity_roots (
  duplicate_id uuid primary key,
  keeper_id uuid not null
) on commit drop;

with recursive chain as (
  select duplicate_id, keeper_id
  from equipment_identity_pairs
  union all
  select chain.duplicate_id, pairs.keeper_id
  from chain
  join equipment_identity_pairs pairs
    on pairs.duplicate_id = chain.keeper_id
)
insert into equipment_identity_roots (duplicate_id, keeper_id)
select distinct on (chain.duplicate_id)
  chain.duplicate_id,
  chain.keeper_id
from chain
where not exists (
  select 1
  from equipment_identity_pairs next_pair
  where next_pair.duplicate_id = chain.keeper_id
)
order by chain.duplicate_id, chain.keeper_id;

-- Keep one usage reading per keeper/timestamp before moving history.
with mapped_logs as (
  select
    logs.log_id,
    coalesce(roots.keeper_id, logs.node_id) as keeper_id,
    row_number() over (
      partition by coalesce(roots.keeper_id, logs.node_id), logs.timestamp
      order by case when roots.duplicate_id is null then 0 else 1 end,
               logs.log_id
    ) as row_number
  from public.equipment_usage_logs logs
  left join equipment_identity_roots roots
    on roots.duplicate_id = logs.node_id
), duplicate_logs as (
  select log_id
  from mapped_logs
  where row_number > 1
)
delete from public.equipment_usage_logs logs
where logs.log_id in (select log_id from duplicate_logs);

update public.equipment_usage_logs logs
set node_id = roots.keeper_id
from equipment_identity_roots roots
where logs.node_id = roots.duplicate_id;

update public.alerts alerts
set equipment_node_id = roots.keeper_id::text
from equipment_identity_roots roots
where alerts.equipment_node_id = roots.duplicate_id::text;

delete from public.equipment_nodes nodes
using equipment_identity_roots roots
where nodes.node_id = roots.duplicate_id;

update public.equipment_nodes
set asset_tag = upper(trim(asset_tag)),
    serial_number = nullif(upper(trim(serial_number)), ''),
    ip_address = nullif(trim(ip_address), '')
where asset_tag <> upper(trim(asset_tag))
   or serial_number is not null
   or ip_address is not null;

create unique index if not exists equipment_nodes_asset_tag_normalized_key
  on public.equipment_nodes (upper(trim(asset_tag)));

create unique index if not exists equipment_nodes_serial_number_normalized_key
  on public.equipment_nodes (upper(trim(serial_number)))
  where nullif(trim(serial_number), '') is not null;

create unique index if not exists equipment_nodes_ip_address_normalized_key
  on public.equipment_nodes (trim(ip_address))
  where nullif(trim(ip_address), '') is not null;

commit;
