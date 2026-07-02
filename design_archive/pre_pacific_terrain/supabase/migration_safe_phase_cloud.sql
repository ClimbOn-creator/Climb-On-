create extension if not exists postgis;

alter table public.crags
add column if not exists created_by uuid references auth.users(id) on delete set null;

alter table public.routes
add column if not exists created_by uuid references auth.users(id) on delete set null;

alter table public.routes
add column if not exists image_url text not null default '';

create table if not exists public.route_attempts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  route_id uuid not null references public.routes(id) on delete cascade,
  note text default '',
  attempted_at timestamptz not null default now()
);

create table if not exists public.route_grade_opinions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  route_id uuid not null references public.routes(id) on delete cascade,
  suggested_grade text not null,
  created_at timestamptz not null default now(),
  unique (user_id, route_id)
);

create table if not exists public.route_comments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  route_id uuid not null references public.routes(id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.route_photos (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  route_id uuid not null references public.routes(id) on delete cascade,
  url text not null,
  storage_path text not null default '',
  caption text default '',
  created_at timestamptz not null default now()
);

alter table public.route_photos
add column if not exists storage_path text not null default '';

create table if not exists public.user_projects (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  route_id uuid not null references public.routes(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (user_id, route_id)
);

create table if not exists public.route_submissions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  submitter_name text default '',
  crag_name text not null,
  wall_name text not null,
  route_name text not null,
  grade text not null,
  route_type text not null,
  pitch_type text not null,
  angle text not null,
  bolts integer not null,
  height_meters integer not null,
  route_length integer not null,
  rope_length integer not null,
  top_rope boolean not null default false,
  latitude double precision not null,
  longitude double precision not null,
  photo_url text not null,
  description text not null,
  approach_notes text not null,
  descent_notes text not null,
  danger_info text not null,
  gear_notes text not null,
  status text not null default 'pending',
  created_at timestamptz not null default now()
);

alter table public.route_submissions
add column if not exists crag_id uuid references public.crags(id) on delete set null;

alter table public.route_submissions
add column if not exists wall_id uuid references public.walls(id) on delete set null;

alter table public.profiles enable row level security;
alter table public.user_sends enable row level security;
alter table public.route_attempts enable row level security;
alter table public.route_grade_opinions enable row level security;
alter table public.route_comments enable row level security;
alter table public.route_photos enable row level security;
alter table public.user_projects enable row level security;
alter table public.route_submissions enable row level security;

drop policy if exists "Users manage own attempts" on public.route_attempts;
create policy "Users manage own attempts"
on public.route_attempts for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "Users manage own grade opinions" on public.route_grade_opinions;
create policy "Users manage own grade opinions"
on public.route_grade_opinions for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "Route comments are readable" on public.route_comments;
create policy "Route comments are readable"
on public.route_comments for select
using (true);

drop policy if exists "Users manage own comments" on public.route_comments;
create policy "Users manage own comments"
on public.route_comments for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "Route photos are readable" on public.route_photos;
create policy "Route photos are readable"
on public.route_photos for select
using (true);

drop policy if exists "Users manage own photos" on public.route_photos;
create policy "Users manage own photos"
on public.route_photos for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "Users manage own projects" on public.user_projects;
create policy "Users manage own projects"
on public.user_projects for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "Anyone can submit routes" on public.route_submissions;
create policy "Anyone can submit routes"
on public.route_submissions for insert
with check (true);

drop policy if exists "Users read own submissions" on public.route_submissions;
create policy "Users read own submissions"
on public.route_submissions for select
using (auth.uid() = user_id);

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
          'lat', coalesce((
            select st_y(routes.location::geometry)
            from public.routes
            where routes.wall_id = walls.id and routes.location is not null
            limit 1
          ), st_y(crags.location::geometry)),
          'lng', coalesce((
            select st_x(routes.location::geometry)
            from public.routes
            where routes.wall_id = walls.id and routes.location is not null
            limit 1
          ), st_x(crags.location::geometry)),
          'routes', coalesce((
            select jsonb_agg(jsonb_build_object(
              'id', routes.id::text,
              'name', routes.name,
              'grade', coalesce(routes.grade, ''),
              'rating', coalesce(routes.rating, 0),
              'lat', case when routes.location is null then null else st_y(routes.location::geometry) end,
              'lng', case when routes.location is null then null else st_x(routes.location::geometry) end,
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
