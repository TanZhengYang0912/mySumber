-- Two legacy seed locations carried duplicate physical types. Rename the
-- duplicate nodes to missing types of the same utility so their 60-day usage
-- history remains intact while each Mall Monitoring card has a clean taxonomy.
update public.equipment_nodes
set equipment_type = 'Toilet', node_name = 'Toilet'
where asset_tag = 'TRX-MWP-001'
  and facility_name = 'The Exchange TRX'
  and utility_type = 'Water';

update public.equipment_nodes
set equipment_type = 'Water Pipe', node_name = 'Water Pipe'
where asset_tag = 'TRX-MWP-002'
  and facility_name = 'The Exchange TRX'
  and utility_type = 'Water';

update public.equipment_nodes
set equipment_type = 'Chiller', node_name = 'Chiller'
where asset_tag = 'LEGACY-7dd37865cdf54f829224ac10e94fc003'
  and facility_name = 'Vivacity Megamall'
  and utility_type = 'Electricity';
