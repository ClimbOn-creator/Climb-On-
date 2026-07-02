-- Creator/admin ski route editor.
-- Run in Supabase SQL Editor after admin_map_editor_setup.sql.
-- Safe to run more than once.

create extension if not exists postgis;

create table if not exists public.ski_routes (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  area text not null,
  province text not null default 'BC',
  region text not null,
  location geography(point, 4326) not null,
  trailhead geography(point, 4326) not null,
  distance_km double precision not null,
  elevation_gain_meters integer not null,
  difficulty text not null,
  aspect text not null,
  avalanche_terrain text not null,
  season text not null,
  description text not null,
  approach_notes text not null,
  descent_notes text not null,
  danger_info text not null,
  image_url text not null,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

alter table public.ski_routes enable row level security;

drop policy if exists "Ski routes are readable" on public.ski_routes;
create policy "Ski routes are readable"
on public.ski_routes for select
using (true);

create table if not exists public.ski_route_submissions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  submitter_name text default '',
  route_name text not null,
  area text not null,
  region text not null,
  difficulty text not null,
  distance_km double precision not null,
  elevation_gain_meters integer not null,
  aspect text not null,
  avalanche_terrain text not null,
  season text not null,
  latitude double precision not null,
  longitude double precision not null,
  trailhead_latitude double precision not null,
  trailhead_longitude double precision not null,
  image_url text not null,
  description text not null,
  approach_notes text not null,
  descent_notes text not null,
  danger_info text not null,
  status text not null default 'pending',
  created_at timestamptz not null default now()
);

alter table public.ski_route_submissions enable row level security;

drop policy if exists "Anyone can submit ski routes" on public.ski_route_submissions;
create policy "Anyone can submit ski routes"
on public.ski_route_submissions for insert
with check (true);

drop policy if exists "Users read own ski submissions" on public.ski_route_submissions;
create policy "Users read own ski submissions"
on public.ski_route_submissions for select
using (auth.uid() = user_id);

alter table public.route_submissions
  add column if not exists photo_urls jsonb not null default '[]';

alter table public.ski_route_submissions
  add column if not exists photo_urls jsonb not null default '[]';

alter table public.ski_routes
  add column if not exists route_path geography(linestring, 4326),
  add column if not exists route_path_points jsonb not null default '[]',
  add column if not exists descent_path geography(linestring, 4326),
  add column if not exists descent_path_points jsonb not null default '[]',
  add column if not exists created_by uuid references auth.users(id) on delete set null;

alter table public.ski_routes
  add column if not exists source_url text not null default '';

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

create or replace function public.ski_catalog()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', s.id::text,
    'name', s.name,
    'area', s.area,
    'region', s.region,
    'lat', st_y(s.location::geometry),
    'lng', st_x(s.location::geometry),
    'trailheadLat', st_y(s.trailhead::geometry),
    'trailheadLng', st_x(s.trailhead::geometry),
    'distanceKm', s.distance_km,
    'elevationGainMeters', s.elevation_gain_meters,
    'difficulty', s.difficulty,
    'aspect', s.aspect,
    'avalancheTerrain', s.avalanche_terrain,
    'season', s.season,
    'description', s.description,
    'approachNotes', s.approach_notes,
    'descentNotes', s.descent_notes,
    'dangerInfo', s.danger_info,
    'imageUrl', s.image_url,
    'createdBy', coalesce(s.created_by::text, ''),
    'sourceUrl', s.source_url
  ) order by s.name), '[]'::jsonb)
  from public.ski_routes s
  where st_covers(
    st_geomfromtext(
      'POLYGON((-128.65 50.92,-127.10 51.00,-126.60 50.63,-125.05 50.15,-123.72 49.30,-123.27 48.78,-123.30 48.30,-124.30 48.30,-125.05 48.58,-126.15 49.10,-127.20 49.85,-128.35 50.50,-128.65 50.92))',
      4326
    ),
    s.location::geometry
  );
$$;

create or replace function public.admin_save_ski_route(
  route_id uuid,
  route_name text,
  route_area text,
  route_region text,
  route_difficulty text,
  route_distance_km double precision,
  route_elevation_gain_meters integer,
  route_aspect text,
  route_avalanche_terrain text,
  route_season text,
  route_lat double precision,
  route_lng double precision,
  route_trailhead_lat double precision,
  route_trailhead_lng double precision,
  route_description text,
  route_approach_notes text,
  route_descent_notes text,
  route_danger_info text,
  route_image_url text,
  ascent_points jsonb default '[]',
  descent_points jsonb default '[]'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  saved_id uuid;
begin
  if not public.is_app_admin() then
    raise exception 'Not authorized';
  end if;

  saved_id := coalesce(route_id, gen_random_uuid());

  insert into public.ski_routes (
    id,
    name,
    area,
    province,
    region,
    location,
    trailhead,
    distance_km,
    elevation_gain_meters,
    difficulty,
    aspect,
    avalanche_terrain,
    season,
    description,
    approach_notes,
    descent_notes,
    danger_info,
    image_url,
    route_path,
    route_path_points,
    descent_path,
    descent_path_points,
    created_by
  ) values (
    saved_id,
    trim(route_name),
    trim(route_area),
    'BC',
    trim(route_region),
    st_setsrid(st_makepoint(route_lng, route_lat), 4326)::geography,
    st_setsrid(st_makepoint(route_trailhead_lng, route_trailhead_lat), 4326)::geography,
    route_distance_km,
    route_elevation_gain_meters,
    trim(route_difficulty),
    trim(route_aspect),
    trim(route_avalanche_terrain),
    trim(route_season),
    trim(route_description),
    trim(route_approach_notes),
    trim(route_descent_notes),
    trim(route_danger_info),
    coalesce(nullif(trim(route_image_url), ''), 'https://images.unsplash.com/photo-1517824806704-9040b037703b'),
    case when jsonb_array_length(ascent_points) >= 2 then st_segmentize(public.path_from_lat_lng(ascent_points), 3.048) else null end,
    case when jsonb_array_length(ascent_points) >= 2 then ascent_points else '[]'::jsonb end,
    case when jsonb_array_length(descent_points) >= 2 then st_segmentize(public.path_from_lat_lng(descent_points), 3.048) else null end,
    case when jsonb_array_length(descent_points) >= 2 then descent_points else '[]'::jsonb end,
    auth.uid()
  )
  on conflict (id) do update set
    name = excluded.name,
    area = excluded.area,
    region = excluded.region,
    location = excluded.location,
    trailhead = excluded.trailhead,
    distance_km = excluded.distance_km,
    elevation_gain_meters = excluded.elevation_gain_meters,
    difficulty = excluded.difficulty,
    aspect = excluded.aspect,
    avalanche_terrain = excluded.avalanche_terrain,
    season = excluded.season,
    description = excluded.description,
    approach_notes = excluded.approach_notes,
    descent_notes = excluded.descent_notes,
    danger_info = excluded.danger_info,
    image_url = excluded.image_url,
    route_path = excluded.route_path,
    route_path_points = excluded.route_path_points,
    descent_path = excluded.descent_path,
    descent_path_points = excluded.descent_path_points;

  return (
    select jsonb_build_object(
      'id', s.id::text,
      'name', s.name,
      'area', s.area,
      'region', s.region,
      'lat', st_y(s.location::geometry),
      'lng', st_x(s.location::geometry),
      'trailheadLat', st_y(s.trailhead::geometry),
      'trailheadLng', st_x(s.trailhead::geometry),
      'distanceKm', s.distance_km,
      'elevationGainMeters', s.elevation_gain_meters,
      'difficulty', s.difficulty,
      'aspect', s.aspect,
      'avalancheTerrain', s.avalanche_terrain,
      'season', s.season,
      'description', s.description,
      'approachNotes', s.approach_notes,
      'descentNotes', s.descent_notes,
      'dangerInfo', s.danger_info,
      'imageUrl', s.image_url,
      'createdBy', coalesce(s.created_by::text, '')
    )
    from public.ski_routes s
    where s.id = saved_id
  );
end;
$$;

grant execute on function public.ski_catalog() to anon, authenticated;
grant execute on function public.admin_save_ski_route(
  uuid, text, text, text, text, double precision, integer, text, text, text,
  double precision, double precision, double precision, double precision,
  text, text, text, text, text, jsonb, jsonb
) to authenticated;
