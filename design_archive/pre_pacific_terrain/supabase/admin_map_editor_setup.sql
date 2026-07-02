-- Creator-only map editing support.
--
-- Run this once in Supabase, then add your signed-in Google user's UUID to
-- public.app_admins. You can find your UUID in Authentication > Users.

create extension if not exists postgis;

create table if not exists public.app_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.app_admins enable row level security;

drop policy if exists "Admins read own admin status" on public.app_admins;
create policy "Admins read own admin status"
on public.app_admins for select
using (auth.uid() = user_id);

create or replace function public.is_app_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.app_admins
    where user_id = auth.uid()
  );
$$;

create or replace function public.admin_update_crag_location(
  crag_id uuid,
  lat double precision,
  lng double precision
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_app_admin() then
    raise exception 'Not authorized';
  end if;

  update public.crags
  set location = st_setsrid(st_makepoint(lng, lat), 4326)::geography
  where id = crag_id;
end;
$$;

create or replace function public.admin_update_crag_parking_location(
  crag_id uuid,
  lat double precision,
  lng double precision
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_app_admin() then
    raise exception 'Not authorized';
  end if;

  update public.crags
  set parking_location = st_setsrid(st_makepoint(lng, lat), 4326)::geography
  where id = crag_id;
end;
$$;

create or replace function public.admin_update_route_location(
  route_id uuid,
  lat double precision,
  lng double precision
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_app_admin() then
    raise exception 'Not authorized';
  end if;

  update public.routes
  set location = st_setsrid(st_makepoint(lng, lat), 4326)::geography
  where id = route_id;
end;
$$;

create or replace function public.admin_update_wall_route_locations(
  wall_id uuid,
  lat double precision,
  lng double precision
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  updated_count integer;
begin
  if not public.is_app_admin() then
    raise exception 'Not authorized';
  end if;

  update public.routes
  set location = st_setsrid(st_makepoint(lng, lat), 4326)::geography
  where routes.wall_id = admin_update_wall_route_locations.wall_id;

  get diagnostics updated_count = row_count;
  return updated_count;
end;
$$;

grant usage on schema public to anon, authenticated;
grant select on public.app_admins to authenticated;
grant execute on function public.is_app_admin() to authenticated;
grant execute on function public.admin_update_crag_location(uuid, double precision, double precision) to authenticated;
grant execute on function public.admin_update_crag_parking_location(uuid, double precision, double precision) to authenticated;
grant execute on function public.admin_update_route_location(uuid, double precision, double precision) to authenticated;
grant execute on function public.admin_update_wall_route_locations(uuid, double precision, double precision) to authenticated;

