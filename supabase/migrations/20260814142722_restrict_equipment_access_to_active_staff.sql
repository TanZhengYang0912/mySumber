-- The initial inventory migration allowed every authenticated user to read
-- and write equipment data. Supabase permissive policies are OR-ed together,
-- so the later admin-only policy did not override that access. Replace every
-- legacy policy with one staff-read/admin-write policy per inventory table.

drop policy if exists "Authenticated users can read equipment nodes"
  on public.equipment_nodes;
drop policy if exists "Admins can manage equipment nodes"
  on public.equipment_nodes;
create policy "Active staff can read equipment nodes"
  on public.equipment_nodes for select to authenticated
  using (exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid())
      and p.role in ('admin', 'worker')
      and p.status = 'active'
  ));
create policy "Active admins can manage equipment nodes"
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

drop policy if exists "Authenticated users can read equipment usage logs"
  on public.equipment_usage_logs;
drop policy if exists "Authenticated users can manage equipment usage logs"
  on public.equipment_usage_logs;
create policy "Active staff can read equipment usage logs"
  on public.equipment_usage_logs for select to authenticated
  using (exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid())
      and p.role in ('admin', 'worker')
      and p.status = 'active'
  ));
create policy "Active admins can manage equipment usage logs"
  on public.equipment_usage_logs for all to authenticated
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

drop policy if exists "Authenticated users can read facilities"
  on public.facilities;
drop policy if exists "Authenticated users can manage facilities"
  on public.facilities;
create policy "Active staff can read facilities"
  on public.facilities for select to authenticated
  using (exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid())
      and p.role in ('admin', 'worker')
      and p.status = 'active'
  ));
create policy "Active admins can manage facilities"
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

drop policy if exists "Authenticated users can read manufacturers"
  on public.manufacturers;
drop policy if exists "Authenticated users can manage manufacturers"
  on public.manufacturers;
create policy "Active staff can read manufacturers"
  on public.manufacturers for select to authenticated
  using (exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid())
      and p.role in ('admin', 'worker')
      and p.status = 'active'
  ));
create policy "Active admins can manage manufacturers"
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

drop policy if exists "Authenticated users can read equipment models"
  on public.equipment_models;
drop policy if exists "Authenticated users can manage equipment models"
  on public.equipment_models;
create policy "Active staff can read equipment models"
  on public.equipment_models for select to authenticated
  using (exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid())
      and p.role in ('admin', 'worker')
      and p.status = 'active'
  ));
create policy "Active admins can manage equipment models"
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

drop policy if exists "Authenticated users can read firmware catalog"
  on public.firmware_catalog;
drop policy if exists "Authenticated users can manage firmware catalog"
  on public.firmware_catalog;
create policy "Active staff can read firmware catalog"
  on public.firmware_catalog for select to authenticated
  using (exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid())
      and p.role in ('admin', 'worker')
      and p.status = 'active'
  ));
create policy "Active admins can manage firmware catalog"
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
