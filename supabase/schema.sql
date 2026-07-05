create extension if not exists postgis;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  avatar_url text,
  bio text default '',
  created_at timestamptz not null default now()
);

create table public.crags (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  province text not null,
  region text not null,
  location geography(point, 4326) not null,
  parking_location geography(point, 4326),
  approach_trail text default '',
  access_notes text default '',
  season text default '',
  danger_info text default '',
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create index crags_location_gix on public.crags using gist (location);

create table public.walls (
  id uuid primary key default gen_random_uuid(),
  crag_id uuid not null references public.crags(id) on delete cascade,
  name text not null,
  created_at timestamptz not null default now()
);

create table public.routes (
  id uuid primary key default gen_random_uuid(),
  wall_id uuid not null references public.walls(id) on delete cascade,
  name text not null,
  grade text,
  route_type text,
  pitch_type text,
  angle text,
  height_meters integer,
  bolts integer,
  gear_notes text default '',
  route_length integer,
  rope_length integer,
  top_rope boolean not null default false,
  location geography(point, 4326),
  description text default '',
  approach_notes text default '',
  descent_notes text default '',
  danger_info text default '',
  rating double precision default 0,
  image_url text not null default '',
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create index routes_location_gix on public.routes using gist (location);
create index routes_grade_idx on public.routes (grade);
create index routes_type_idx on public.routes (route_type);
create index routes_pitch_type_idx on public.routes (pitch_type);

create table public.user_sends (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  route_id uuid not null references public.routes(id) on delete cascade,
  style text default 'Redpoint',
  sent_at timestamptz not null default now(),
  unique (user_id, route_id)
);

create table public.route_attempts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  route_id uuid not null references public.routes(id) on delete cascade,
  note text default '',
  attempted_at timestamptz not null default now()
);

create table public.route_grade_opinions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  route_id uuid not null references public.routes(id) on delete cascade,
  suggested_grade text not null,
  created_at timestamptz not null default now(),
  unique (user_id, route_id)
);

create table public.route_comments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  route_id uuid not null references public.routes(id) on delete cascade,
  parent_comment_id uuid references public.route_comments(id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now()
);

create table public.route_photos (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  route_id uuid not null references public.routes(id) on delete cascade,
  url text not null,
  storage_path text not null default '',
  caption text default '',
  created_at timestamptz not null default now()
);

create table public.user_projects (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  route_id uuid not null references public.routes(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (user_id, route_id)
);

alter table public.profiles enable row level security;
alter table public.user_sends enable row level security;
alter table public.route_attempts enable row level security;
alter table public.route_grade_opinions enable row level security;
alter table public.route_comments enable row level security;
alter table public.route_photos enable row level security;
alter table public.user_projects enable row level security;

create policy "Profiles are readable"
on public.profiles for select
using (true);

create policy "Users manage own profile"
on public.profiles for all
using (auth.uid() = id)
with check (auth.uid() = id);

create policy "Users read own sends"
on public.user_sends for select
using (auth.uid() = user_id);

create policy "Users insert own sends"
on public.user_sends for insert
with check (auth.uid() = user_id);

create policy "Users update own sends"
on public.user_sends for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "Users delete own sends"
on public.user_sends for delete
using (auth.uid() = user_id);

create policy "Users manage own attempts"
on public.route_attempts for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "Users manage own grade opinions"
on public.route_grade_opinions for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "Route comments are readable"
on public.route_comments for select
using (true);

create policy "Users manage own comments"
on public.route_comments for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "Route photos are readable"
on public.route_photos for select
using (true);

create policy "Users manage own photos"
on public.route_photos for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "Users manage own projects"
on public.user_projects for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create or replace function public.crags_in_bounds(
  south double precision,
  west double precision,
  north double precision,
  east double precision
)
returns setof public.crags
language sql
stable
as $$
  select *
  from public.crags
  where location && st_makeenvelope(west, south, east, north, 4326)::geography;
$$;

create or replace function public.crags_within_radius(
  lat double precision,
  lng double precision,
  radius_meters double precision
)
returns setof public.crags
language sql
stable
as $$
  select *
  from public.crags
  where st_dwithin(location, st_setsrid(st_makepoint(lng, lat), 4326)::geography, radius_meters);
$$;

create or replace function public.search_routes(
  search_text text default '',
  grade_filter text default null,
  route_type_filter text default null,
  pitch_type_filter text default null,
  south double precision default null,
  west double precision default null,
  north double precision default null,
  east double precision default null
)
returns table (
  route_id uuid,
  route_name text,
  grade text,
  route_type text,
  pitch_type text,
  wall_id uuid,
  crag_id uuid,
  crag_name text,
  region text,
  province text
)
language sql
stable
as $$
  select
    routes.id,
    routes.name,
    routes.grade,
    routes.route_type,
    routes.pitch_type,
    walls.id,
    crags.id,
    crags.name,
    crags.region,
    crags.province
  from public.routes
  join public.walls on walls.id = routes.wall_id
  join public.crags on crags.id = walls.crag_id
  where
    (search_text = '' or routes.name ilike '%' || search_text || '%' or crags.name ilike '%' || search_text || '%')
    and (grade_filter is null or routes.grade = grade_filter)
    and (route_type_filter is null or routes.route_type = route_type_filter)
    and (pitch_type_filter is null or routes.pitch_type = pitch_type_filter)
    and (
      south is null
      or routes.location && st_makeenvelope(west, south, east, north, 4326)::geography
    );
$$;

create or replace function public.climb_catalog()
returns jsonb
language sql
stable
as $$
  select coalesce(jsonb_agg(crag_doc order by crag_doc->>'name'), '[]'::jsonb)
  from (
    select jsonb_build_object(
      'id', crags.id::text,
      'name', crags.name,
      'province', crags.province,
      'region', crags.region,
      'lat', st_y(crags.location::geometry),
      'lng', st_x(crags.location::geometry),
      'parkingLat', coalesce(st_y(crags.parking_location::geometry), st_y(crags.location::geometry)),
      'parkingLng', coalesce(st_x(crags.parking_location::geometry), st_x(crags.location::geometry)),
      'approachTrail', crags.approach_trail,
      'accessNotes', crags.access_notes,
      'season', crags.season,
      'dangerInfo', crags.danger_info,
      'createdBy', coalesce(crags.created_by::text, ''),
      'walls', coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', walls.id::text,
          'name', walls.name,
          'lat', coalesce(st_y((
            select routes.location::geometry
            from public.routes
            where routes.wall_id = walls.id and routes.location is not null
            limit 1
          )), st_y(crags.location::geometry)),
          'lng', coalesce(st_x((
            select routes.location::geometry
            from public.routes
            where routes.wall_id = walls.id and routes.location is not null
            limit 1
          )), st_x(crags.location::geometry)),
          'routes', coalesce((
            select jsonb_agg(jsonb_build_object(
              'id', routes.id::text,
              'name', routes.name,
              'grade', coalesce(routes.grade, ''),
              'rating', coalesce(routes.rating, 0),
              'lat', st_y(routes.location::geometry),
              'lng', st_x(routes.location::geometry),
              'description', routes.description,
              'type', routes.route_type,
              'pitchType', routes.pitch_type,
              'angle', routes.angle,
              'heightMeters', routes.height_meters,
              'bolts', routes.bolts,
              'gearNotes', routes.gear_notes,
              'routeLength', routes.route_length,
              'ropeLength', routes.rope_length,
              'topRope', routes.top_rope,
              'approachNotes', routes.approach_notes,
              'descentNotes', routes.descent_notes,
              'dangerInfo', routes.danger_info,
              'imageUrl', routes.image_url,
              'createdBy', coalesce(routes.created_by::text, '')
            ) order by routes.name)
            from public.routes
            where routes.wall_id = walls.id
          ), '[]'::jsonb)
        ) order by walls.name)
        from public.walls
        where walls.crag_id = crags.id
      ), '[]'::jsonb)
    ) as crag_doc
    from public.crags
  ) catalog;
$$;
