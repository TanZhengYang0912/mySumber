-- Backfill legacy alerts into the source/utility model used by the unified
-- review workflow. Keep real historical rows; remove only the confirmed test
-- alert identified during the 2026-08-21 audit.

begin;

delete from public.reports where alert_id = 83;
delete from public.alerts where id = 83;

update public.alerts
set source_scope = case
  when household_id is not null then 'household'
  when equipment_node_id is not null or facility_name is not null then 'mall'
  else 'state'
end
where source_scope is null;

update public.alerts
set utility_type = case
  when alert_type in ('nrw_hotspot', 'household') then 'water'
  else 'electricity'
end
where utility_type is null;

-- Fault rejection is now performed before Worker alert creation. Preserve the
-- historical rows without presenting a removed status in the application.
update public.alerts
set status = 'dismissed'
where status = 'faults';

commit;
