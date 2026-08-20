-- Remove the debugging leftover from an earlier session.
delete from public.equipment_usage_logs
where node_id in (
  select node_id from public.equipment_nodes
  where facility_name = 'Trigger Test Mall'
);
delete from public.alerts
where equipment_node_id in (
  select node_id::text from public.equipment_nodes
  where facility_name = 'Trigger Test Mall'
);
delete from public.equipment_nodes where facility_name = 'Trigger Test Mall';

-- Rename the three repeated legacy types onto the new taxonomy, preserving
-- each node's usage history.
update public.equipment_nodes
set equipment_type = 'Cooling Tower', node_name = 'Cooling Tower'
where equipment_type = 'Cooling Tower Valve';

update public.equipment_nodes
set equipment_type = 'Water Pump', node_name = 'Water Pump'
where equipment_type = 'Main Water Pump';

update public.equipment_nodes
set equipment_type = 'Transformer', node_name = 'Transformer'
where equipment_type = 'Sub-Transformer';

-- Give each mall an uneven extra mix. abs(hashtext(facility_name)) is stable
-- across runs, so re-running this migration produces the same layout.
insert into public.equipment_nodes (
  node_id, asset_tag, node_name, equipment_type, utility_type, status,
  zone_id, facility_id, facility_code, facility_name, facility_city,
  ip_assignment
)
select
  gen_random_uuid(),
  'MALL-' || upper(substr(md5(facility.facility_name), 1, 10)) || '-' ||
    extra.slot::text,
  extra.equipment_type,
  extra.equipment_type,
  extra.utility_type,
  'Active',
  facility.zone_id,
  facility.facility_id,
  facility.facility_code,
  facility.facility_name,
  facility.facility_city,
  'DHCP'
from (
  select distinct facility_name, facility_city, zone_id,
         facility_id, facility_code
  from public.equipment_nodes
  where facility_name is not null
) as facility
cross join (values
  ('Valve', 'Water', 0),
  ('Toilet', 'Water', 1),
  ('Water Pipe', 'Water', 2),
  ('HVAC', 'Electricity', 3),
  ('Chiller', 'Electricity', 4),
  ('Lighting', 'Electricity', 5),
  ('Escalator', 'Electricity', 6)
) as extra(equipment_type, utility_type, slot)
where ((abs(hashtext(facility.facility_name)) / power(2, extra.slot)::int) % 2) = 1
  and not exists (
    select 1 from public.equipment_nodes existing
    where existing.facility_name = facility.facility_name
      and existing.equipment_type = extra.equipment_type
  );
