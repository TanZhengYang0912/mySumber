alter table public.alerts
  add column if not exists equipment_node_id text,
  add column if not exists facility_name text,
  add column if not exists facility_city text,
  add column if not exists equipment_name text;

create index if not exists alerts_facility_name_idx
  on public.alerts (facility_name);

create index if not exists alerts_equipment_node_id_idx
  on public.alerts (equipment_node_id);
