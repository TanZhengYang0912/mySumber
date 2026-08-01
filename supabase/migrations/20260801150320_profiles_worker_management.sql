create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete restrict,
  full_name text not null default '',
  email text not null,
  role text not null check (role in ('admin', 'worker', 'customer')),
  status text not null default 'active' check (status in ('active', 'inactive')),
  created_at timestamptz not null default now()
);

create index if not exists profiles_role_status_idx
  on public.profiles (role, status);

alter table public.profiles enable row level security;

create policy "Users can read their own profile"
  on public.profiles for select to authenticated
  using ((select auth.uid()) = id);

create policy "Admins can read all profiles"
  on public.profiles for select to authenticated
  using ((select auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

create schema if not exists private;

create or replace function private.create_customer_profile()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  insert into public.profiles (id, full_name, email, role, status)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'display_name', ''),
    new.email,
    'customer',
    'active'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

revoke all on function private.create_customer_profile() from public, anon, authenticated;

drop trigger if exists create_customer_profile_after_signup on auth.users;
create trigger create_customer_profile_after_signup
  after insert on auth.users
  for each row execute procedure private.create_customer_profile();

update auth.users
set raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb) ||
  jsonb_build_object(
    'role',
    case lower(email)
      when 'admin@mysumber.my' then 'admin'
      when 'worker@mysumber.my' then 'worker'
      else 'customer'
    end
  );

insert into public.profiles (id, full_name, email, role, status)
select
  id,
  coalesce(raw_user_meta_data ->> 'display_name', ''),
  email,
  coalesce(raw_app_meta_data ->> 'role', 'customer'),
  'active'
from auth.users
where email is not null
on conflict (id) do update
set email = excluded.email,
    role = excluded.role;

alter table public.reports
  add column if not exists worker_id uuid
  references public.profiles(id) on delete restrict;

create index if not exists reports_worker_id_idx
  on public.reports (worker_id);

create or replace function private.stamp_worker_report()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  current_profile public.profiles%rowtype;
begin
  select * into current_profile
  from public.profiles
  where id = auth.uid();

  if not found
      or current_profile.role <> 'worker'
      or current_profile.status <> 'active' then
    raise exception 'Active worker account required';
  end if;

  new.worker_id := current_profile.id;
  new.worker_name := current_profile.full_name;
  return new;
end;
$$;

revoke all on function private.stamp_worker_report() from public, anon, authenticated;

drop trigger if exists stamp_worker_report_before_insert on public.reports;
create trigger stamp_worker_report_before_insert
  before insert on public.reports
  for each row execute procedure private.stamp_worker_report();
