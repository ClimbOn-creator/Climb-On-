-- Creator-editable approach and ski route lines.
-- Safe to run more than once in Supabase > SQL Editor.

create extension if not exists postgis;

alter table public.crags
  add column if not exists approach_path geography(linestring, 4326),
  add column if not exists approach_path_points jsonb not null default '[]';

alter table public.ski_routes
  add column if not exists route_path geography(linestring, 4326),
  add column if not exists route_path_points jsonb not null default '[]',
  add column if not exists descent_path geography(linestring, 4326),
  add column if not exists descent_path_points jsonb not null default '[]';

create or replace function public.map_paths()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'crags', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', c.id::text,
        'points', c.approach_path_points
      ))
      from public.crags c
      where c.approach_path is not null
    ), '[]'::jsonb),
    'skiRoutes', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', s.id::text,
        'name', s.name,
        'points', s.route_path_points,
        'ascentPoints', s.route_path_points,
        'descentPoints', s.descent_path_points
      ))
      from public.ski_routes s
      where s.route_path is not null or s.descent_path is not null
    ), '[]'::jsonb)
  );
$$;

create or replace function public.path_from_lat_lng(points jsonb)
returns geography
language plpgsql
immutable
set search_path = public
as $$
declare
  result geography;
  point_count integer;
begin
  point_count := jsonb_array_length(points);
  if point_count < 2 or point_count > 10000 then
    raise exception 'A path requires 2 to 10000 points';
  end if;

  select st_makeline(array_agg(
    st_setsrid(st_makepoint(
      (point.value->>1)::double precision,
      (point.value->>0)::double precision
    ), 4326)
    order by point.ordinality
  ))::geography
  into result
  from jsonb_array_elements(points) with ordinality as point(value, ordinality);

  return result;
end;
$$;

create or replace function public.admin_update_crag_approach_path(
  crag_id uuid,
  points jsonb
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
  set approach_path = st_segmentize(public.path_from_lat_lng(points), 3.048),
      approach_path_points = points
  where id = crag_id;
end;
$$;

create or replace function public.admin_update_ski_route_path(
  route_name text,
  points jsonb
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

  update public.ski_routes
  set route_path = st_segmentize(public.path_from_lat_lng(points), 3.048),
      route_path_points = points
  where lower(name) = lower(route_name);
end;
$$;

create or replace function public.admin_update_ski_route_segment(
  route_name text,
  segment_kind text,
  points jsonb
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

  if lower(segment_kind) = 'ascent' then
    update public.ski_routes
    set route_path = st_segmentize(public.path_from_lat_lng(points), 3.048),
        route_path_points = points
    where lower(name) = lower(route_name);
  elsif lower(segment_kind) = 'descent' then
    update public.ski_routes
    set descent_path = st_segmentize(public.path_from_lat_lng(points), 3.048),
        descent_path_points = points
    where lower(name) = lower(route_name);
  else
    raise exception 'segment_kind must be ascent or descent';
  end if;
end;
$$;

grant execute on function public.map_paths() to anon, authenticated;
grant execute on function public.admin_update_crag_approach_path(uuid, jsonb)
  to authenticated;
grant execute on function public.admin_update_ski_route_path(text, jsonb)
  to authenticated;
grant execute on function public.admin_update_ski_route_segment(text, text, jsonb)
  to authenticated;
