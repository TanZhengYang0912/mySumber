-- Canonical equipment deployment metadata for real imports and admin creation.
-- Existing text fields remain for backwards-compatible display and are
-- backfilled into the canonical tables below.

create table if not exists public.facilities (
  facility_id uuid primary key default gen_random_uuid(),
  facility_code text not null unique,
  name text not null,
  city text not null,
  state text not null,
  address text,
  status text not null default 'Active'
    check (status in ('Active', 'Inactive')),
  created_at timestamptz not null default now()
);

create table if not exists public.manufacturers (
  manufacturer_id uuid primary key default gen_random_uuid(),
  name text not null unique,
  created_at timestamptz not null default now()
);

create table if not exists public.equipment_models (
  model_id uuid primary key default gen_random_uuid(),
  equipment_type text not null,
  utility_type text not null
    check (utility_type in ('Water', 'Electricity')),
  manufacturer_id uuid not null references public.manufacturers (manufacturer_id),
  model_name text not null,
  created_at timestamptz not null default now(),
  unique (manufacturer_id, equipment_type, model_name)
);

create table if not exists public.firmware_catalog (
  firmware_id uuid primary key default gen_random_uuid(),
  model_id uuid not null references public.equipment_models (model_id)
    on delete cascade,
  version text not null,
  is_supported boolean not null default true,
  released_at timestamptz,
  created_at timestamptz not null default now(),
  unique (model_id, version)
);

alter table public.equipment_nodes
  add column if not exists asset_tag text,
  add column if not exists equipment_type text,
  add column if not exists facility_id uuid,
  add column if not exists facility_code text,
  add column if not exists model_id uuid,
  add column if not exists model_name text,
  add column if not exists serial_number text,
  add column if not exists manufacturer_id uuid,
  add column if not exists firmware_id uuid,
  add column if not exists ip_assignment text not null default 'Not Assigned';

-- Backfill canonical facilities from the existing display fields. The hash
-- keeps the generated code stable without guessing a real business code.
insert into public.facilities (facility_code, name, city, state)
select distinct on (n.facility_name, coalesce(n.facility_city, ''), coalesce(n.zone_id, ''))
  'LEGACY-' || substr(md5(
    coalesce(n.facility_name, '') || '|' ||
    coalesce(n.facility_city, '') || '|' ||
    coalesce(n.zone_id, '')
  ), 1, 10),
  n.facility_name,
  coalesce(n.facility_city, 'Unknown'),
  coalesce(n.zone_id, 'Unknown')
from public.equipment_nodes n
where n.facility_name is not null
on conflict (facility_code) do nothing;

insert into public.manufacturers (name)
select distinct on (lower(n.manufacturer)) n.manufacturer
from public.equipment_nodes n
where n.manufacturer is not null
order by lower(n.manufacturer), n.manufacturer
on conflict (name) do nothing;

-- Collapse any pre-existing case-only duplicates before the canonical
-- case-insensitive manufacturer index is created.
delete from public.manufacturers duplicate
using public.manufacturers keeper
where lower(duplicate.name) = lower(keeper.name)
  and duplicate.manufacturer_id > keeper.manufacturer_id;

update public.equipment_nodes n
set equipment_type = regexp_replace(
      coalesce(nullif(n.equipment_type, ''), n.node_name),
      '[[:space:]]+[A-Za-z][0-9]+$',
      ''
    ),
    ip_assignment = case
      when n.ip_address is not null then 'Static'
      else coalesce(n.ip_assignment, 'Not Assigned')
    end
;

insert into public.equipment_models (
  equipment_type,
  utility_type,
  manufacturer_id,
  model_name
)
select distinct
  regexp_replace(
    coalesce(nullif(n.equipment_type, ''), n.node_name),
    '[[:space:]]+[A-Za-z][0-9]+$',
    ''
  ),
  n.utility_type,
  m.manufacturer_id,
  coalesce(nullif(n.model_name, ''), 'Unspecified')
from public.equipment_nodes n
join public.manufacturers m on lower(m.name) = lower(n.manufacturer)
where n.manufacturer is not null
on conflict (manufacturer_id, equipment_type, model_name) do nothing;

insert into public.firmware_catalog (model_id, version)
select distinct em.model_id, n.firmware_version
from public.equipment_nodes n
join public.manufacturers m on lower(m.name) = lower(n.manufacturer)
join public.equipment_models em
  on em.manufacturer_id = m.manufacturer_id
 and em.equipment_type = regexp_replace(
   coalesce(nullif(n.equipment_type, ''), n.node_name),
   '[[:space:]]+[A-Za-z][0-9]+$',
   ''
 )
 and em.utility_type = n.utility_type
 and em.model_name = coalesce(nullif(n.model_name, ''), 'Unspecified')
where n.firmware_version is not null
on conflict (model_id, version) do nothing;

update public.equipment_nodes n
set facility_id = f.facility_id,
    facility_code = f.facility_code
from public.facilities f
where n.facility_name = f.name
  and coalesce(n.facility_city, '') = case
    when f.city = 'Unknown' then ''
    else f.city
  end
  and coalesce(n.zone_id, '') = case
    when f.state = 'Unknown' then ''
    else f.state
  end;

update public.equipment_nodes n
set manufacturer_id = m.manufacturer_id
from public.manufacturers m
where n.manufacturer is not null
  and lower(m.name) = lower(n.manufacturer);

update public.equipment_nodes n
set model_id = em.model_id,
    model_name = coalesce(nullif(n.model_name, ''), em.model_name)
from public.equipment_models em
where em.manufacturer_id = n.manufacturer_id
  and em.equipment_type = regexp_replace(
    coalesce(nullif(n.equipment_type, ''), n.node_name),
    '[[:space:]]+[A-Za-z][0-9]+$',
    ''
  )
  and em.utility_type = n.utility_type
  and em.model_name = coalesce(nullif(n.model_name, ''), 'Unspecified');

update public.equipment_nodes n
set firmware_id = fc.firmware_id
from public.firmware_catalog fc
where n.model_id = fc.model_id
  and n.firmware_version = fc.version;

-- Existing rows need a stable identity before asset_tag becomes required.
update public.equipment_nodes
set asset_tag = 'LEGACY-' || replace(node_id::text, '-', '')
where asset_tag is null;

alter table public.equipment_nodes
  alter column asset_tag set not null;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'equipment_nodes_facility_id_fkey'
  ) then
    alter table public.equipment_nodes
      add constraint equipment_nodes_facility_id_fkey
      foreign key (facility_id) references public.facilities (facility_id);
  end if;
  if not exists (
    select 1 from pg_constraint
    where conname = 'equipment_nodes_manufacturer_id_fkey'
  ) then
    alter table public.equipment_nodes
      add constraint equipment_nodes_manufacturer_id_fkey
      foreign key (manufacturer_id) references public.manufacturers (manufacturer_id);
  end if;
  if not exists (
    select 1 from pg_constraint
    where conname = 'equipment_nodes_model_id_fkey'
  ) then
    alter table public.equipment_nodes
      add constraint equipment_nodes_model_id_fkey
      foreign key (model_id) references public.equipment_models (model_id);
  end if;
  if not exists (
    select 1 from pg_constraint
    where conname = 'equipment_nodes_firmware_id_fkey'
  ) then
    alter table public.equipment_nodes
      add constraint equipment_nodes_firmware_id_fkey
      foreign key (firmware_id) references public.firmware_catalog (firmware_id);
  end if;
  if not exists (
    select 1 from pg_constraint
    where conname = 'equipment_nodes_ip_assignment_check'
  ) then
    alter table public.equipment_nodes
      add constraint equipment_nodes_ip_assignment_check
      check (ip_assignment in ('Static', 'DHCP', 'Not Assigned'));
  end if;
end $$;

create unique index if not exists equipment_nodes_asset_tag_key
  on public.equipment_nodes (asset_tag);
create unique index if not exists equipment_nodes_static_ip_key
  on public.equipment_nodes (ip_address)
  where ip_address is not null and ip_assignment = 'Static';
create unique index if not exists manufacturers_lower_name_key
  on public.manufacturers (lower(name));
create index if not exists equipment_models_lookup_idx
  on public.equipment_models (utility_type, equipment_type, manufacturer_id);
create index if not exists firmware_catalog_model_idx
  on public.firmware_catalog (model_id, is_supported);

alter table public.facilities enable row level security;
alter table public.manufacturers enable row level security;
alter table public.equipment_models enable row level security;
alter table public.firmware_catalog enable row level security;

grant select, insert, update, delete on public.facilities to authenticated;
grant select, insert, update, delete on public.manufacturers to authenticated;
grant select, insert, update, delete on public.equipment_models to authenticated;
grant select, insert, update, delete on public.firmware_catalog to authenticated;

drop policy if exists "Authenticated users can read facilities" on public.facilities;
create policy "Authenticated users can read facilities"
  on public.facilities for select to authenticated using (true);
drop policy if exists "Authenticated users can manage facilities" on public.facilities;
create policy "Authenticated users can manage facilities"
  on public.facilities for all to authenticated
  using (exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid())
      and p.role = 'admin'
      and p.status = 'active'
  ))
  with check (exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid())
      and p.role = 'admin'
      and p.status = 'active'
  ));

drop policy if exists "Authenticated users can read manufacturers" on public.manufacturers;
create policy "Authenticated users can read manufacturers"
  on public.manufacturers for select to authenticated using (true);
drop policy if exists "Authenticated users can manage manufacturers" on public.manufacturers;
create policy "Authenticated users can manage manufacturers"
  on public.manufacturers for all to authenticated
  using (exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid())
      and p.role = 'admin'
      and p.status = 'active'
  ))
  with check (exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid())
      and p.role = 'admin'
      and p.status = 'active'
  ));

drop policy if exists "Authenticated users can read equipment models" on public.equipment_models;
create policy "Authenticated users can read equipment models"
  on public.equipment_models for select to authenticated using (true);
drop policy if exists "Authenticated users can manage equipment models" on public.equipment_models;
create policy "Authenticated users can manage equipment models"
  on public.equipment_models for all to authenticated
  using (exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid())
      and p.role = 'admin'
      and p.status = 'active'
  ))
  with check (exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid())
      and p.role = 'admin'
      and p.status = 'active'
  ));

drop policy if exists "Authenticated users can read firmware catalog" on public.firmware_catalog;
create policy "Authenticated users can read firmware catalog"
  on public.firmware_catalog for select to authenticated using (true);
drop policy if exists "Authenticated users can manage firmware catalog" on public.firmware_catalog;
create policy "Authenticated users can manage firmware catalog"
  on public.firmware_catalog for all to authenticated
  using (exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid())
      and p.role = 'admin'
      and p.status = 'active'
  ))
  with check (exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid())
      and p.role = 'admin'
      and p.status = 'active'
  ));

-- Inventory writes are an Admin-only operation; authenticated staff may still
-- read the equipment rows through the existing select policy.
drop policy if exists "Authenticated users can manage equipment nodes"
  on public.equipment_nodes;
create policy "Admins can manage equipment nodes"
  on public.equipment_nodes for all to authenticated
  using (exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid())
      and p.role = 'admin'
      and p.status = 'active'
  ))
  with check (exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid())
      and p.role = 'admin'
      and p.status = 'active'
  ));
