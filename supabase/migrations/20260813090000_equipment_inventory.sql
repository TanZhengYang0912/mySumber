-- Module 1: equipment inventory and its historical usage readings.
-- Paste this file into Supabase Dashboard -> SQL Editor and run it once.

create table if not exists public.equipment_nodes (
  node_id uuid primary key,
  node_name text not null,
  utility_type text not null check (utility_type in ('Water', 'Electricity')),
  zone_id text,
  facility_name text,
  facility_city text,
  status text not null check (status in ('Active', 'Warning', 'Critical', 'Maintenance')),
  created_at timestamptz not null default now(),
  manufacturer text,
  installation_date timestamptz,
  last_maintenance_date timestamptz,
  next_maintenance_date timestamptz,
  health_score integer not null default 100 check (health_score between 0 and 100),
  firmware_version text,
  ip_address text
);

create table if not exists public.equipment_usage_logs (
  log_id uuid primary key,
  node_id uuid not null references public.equipment_nodes (node_id) on delete cascade,
  timestamp timestamptz not null,
  usage_value double precision not null check (usage_value >= 0),
  is_anomaly boolean not null default false,
  unique (node_id, timestamp)
);

create index if not exists equipment_nodes_location_idx
  on public.equipment_nodes (zone_id, facility_name);
create index if not exists equipment_usage_logs_node_timestamp_idx
  on public.equipment_usage_logs (node_id, timestamp);

alter table public.equipment_nodes enable row level security;
alter table public.equipment_usage_logs enable row level security;

grant select, insert, update, delete on public.equipment_nodes to authenticated;
grant select, insert, update, delete on public.equipment_usage_logs to authenticated;

drop policy if exists "Authenticated users can read equipment nodes" on public.equipment_nodes;
drop policy if exists "Authenticated users can manage equipment nodes" on public.equipment_nodes;
create policy "Authenticated users can read equipment nodes"
  on public.equipment_nodes for select to authenticated using (true);
create policy "Authenticated users can manage equipment nodes"
  on public.equipment_nodes for all to authenticated using (true) with check (true);

drop policy if exists "Authenticated users can read equipment usage logs" on public.equipment_usage_logs;
drop policy if exists "Authenticated users can manage equipment usage logs" on public.equipment_usage_logs;
create policy "Authenticated users can read equipment usage logs"
  on public.equipment_usage_logs for select to authenticated using (true);
create policy "Authenticated users can manage equipment usage logs"
  on public.equipment_usage_logs for all to authenticated using (true) with check (true);
