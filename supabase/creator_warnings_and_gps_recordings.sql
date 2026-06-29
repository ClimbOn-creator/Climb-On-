-- Run after schema.sql, admin_map_editor_setup.sql, and map_paths_setup.sql.
-- Enables creator-owned warning edits and user GPS path submissions.

alter table public.crags
add column if not exists created_by uuid references auth.users(id) on delete set null;

alter table public.routes
add column if not exists created_by uuid references auth.users(id) on delete set null;

alter table public.ski_routes
add column if not exists created_by uuid references auth.users(id) on delete set null;

create or replace function public.creator_update_crag_warning(
  target_crag_id uuid,
  new_warning text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'Sign in required'; end if;
  update public.crags
  set danger_info = trim(new_warning)
  where id = target_crag_id
    and (created_by = auth.uid() or public.is_app_admin());
  if not found then raise exception 'Only the crag creator or an administrator can edit this warning'; end if;
end;
$$;

create or replace function public.creator_update_route_warning(
  target_route_id uuid,
  new_warning text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'Sign in required'; end if;
  update public.routes
  set danger_info = trim(new_warning)
  where id = target_route_id
    and (created_by = auth.uid() or public.is_app_admin());
  if not found then raise exception 'Only the route creator or an administrator can edit this warning'; end if;
end;
$$;

grant execute on function public.creator_update_crag_warning(uuid, text)
to authenticated;
grant execute on function public.creator_update_route_warning(uuid, text)
to authenticated;

create table if not exists public.recorded_paths (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  path_kind text not null check (
    path_kind in ('climb_approach', 'ski_ascent', 'ski_descent')
  ),
  crag_id uuid references public.crags(id) on delete set null,
  ski_route_name text,
  points jsonb not null,
  path geography(linestring, 4326) not null,
  distance_meters double precision not null default 0,
  status text not null default 'pending' check (
    status in ('pending', 'approved', 'rejected')
  ),
  created_at timestamptz not null default now()
);

alter table public.recorded_paths enable row level security;

drop policy if exists "Users read own recorded paths" on public.recorded_paths;
create policy "Users read own recorded paths"
on public.recorded_paths for select
using (auth.uid() = user_id);

drop policy if exists "Users add own recorded paths" on public.recorded_paths;
create policy "Users add own recorded paths"
on public.recorded_paths for insert
with check (auth.uid() = user_id);

drop policy if exists "Users update own pending paths" on public.recorded_paths;
create policy "Users update own pending paths"
on public.recorded_paths for update
using (auth.uid() = user_id and status = 'pending')
with check (auth.uid() = user_id and status = 'pending');

drop policy if exists "Users delete own pending paths" on public.recorded_paths;
create policy "Users delete own pending paths"
on public.recorded_paths for delete
using (auth.uid() = user_id and status = 'pending');

drop policy if exists "Admins read all recorded paths" on public.recorded_paths;
create policy "Admins read all recorded paths"
on public.recorded_paths for select
using (public.is_app_admin());

drop policy if exists "Admins review recorded paths" on public.recorded_paths;
create policy "Admins review recorded paths"
on public.recorded_paths for update
using (public.is_app_admin())
with check (public.is_app_admin());

create or replace function public.submit_recorded_path(
  path_name text,
  submitted_kind text,
  target_crag_id uuid,
  target_ski_route_name text,
  submitted_points jsonb,
  submitted_distance_meters double precision
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  new_id uuid;
begin
  if auth.uid() is null then raise exception 'Sign in required'; end if;
  if submitted_kind not in ('climb_approach', 'ski_ascent', 'ski_descent') then
    raise exception 'Invalid path kind';
  end if;
  if submitted_kind = 'climb_approach' and target_crag_id is null then
    raise exception 'Select a crag for an approach recording';
  end if;
  if submitted_kind <> 'climb_approach' and target_ski_route_name is null then
    raise exception 'Select a ski route for this recording';
  end if;

  insert into public.recorded_paths (
    user_id,
    name,
    path_kind,
    crag_id,
    ski_route_name,
    points,
    path,
    distance_meters
  ) values (
    auth.uid(),
    trim(path_name),
    submitted_kind,
    target_crag_id,
    target_ski_route_name,
    submitted_points,
    public.path_from_lat_lng(submitted_points),
    greatest(submitted_distance_meters, 0)
  ) returning id into new_id;

  return new_id;
end;
$$;

grant execute on function public.submit_recorded_path(
  text, text, uuid, text, jsonb, double precision
) to authenticated;

create or replace function public.admin_approve_recorded_path(
  recording_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  recording public.recorded_paths%rowtype;
begin
  if not public.is_app_admin() then raise exception 'Not authorized'; end if;
  select * into recording
  from public.recorded_paths
  where id = recording_id and status = 'pending';
  if not found then raise exception 'Pending recording not found'; end if;

  if recording.path_kind = 'climb_approach' then
    update public.crags
    set approach_path = st_segmentize(recording.path, 3.048),
        approach_path_points = recording.points
    where id = recording.crag_id;
  elsif recording.path_kind = 'ski_ascent' then
    update public.ski_routes
    set route_path = st_segmentize(recording.path, 3.048),
        route_path_points = recording.points
    where lower(name) = lower(recording.ski_route_name);
  elsif recording.path_kind = 'ski_descent' then
    update public.ski_routes
    set descent_path = st_segmentize(recording.path, 3.048),
        descent_path_points = recording.points
    where lower(name) = lower(recording.ski_route_name);
  end if;

  update public.recorded_paths set status = 'approved'
  where id = recording_id;
end;
$$;

grant execute on function public.admin_approve_recorded_path(uuid)
to authenticated;

drop policy if exists "Users update own pending route submissions"
on public.route_submissions;
create policy "Users update own pending route submissions"
on public.route_submissions for update
using (auth.uid() = user_id and status = 'pending')
with check (auth.uid() = user_id and status = 'pending');
