-- Full administrator route editor for every crag and wall.
-- Self-contained after schema.sql: rerun safely whenever this file changes.

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
    select 1 from public.app_admins where user_id = auth.uid()
  );
$$;

insert into public.app_admins (user_id)
select id from auth.users
where id = '519cee87-e5fb-4374-a61b-5dd45d912c81'
on conflict (user_id) do nothing;

alter table public.crags
add column if not exists created_by uuid references auth.users(id) on delete set null;

alter table public.routes
add column if not exists created_by uuid references auth.users(id) on delete set null;

alter table public.routes
add column if not exists image_url text not null default '';

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'submission-photos',
  'submission-photos',
  true,
  10485760,
  array['image/jpeg', 'image/png', 'image/webp', 'image/heic']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Submission pictures are public" on storage.objects;
create policy "Submission pictures are public"
on storage.objects for select
using (bucket_id = 'submission-photos');

drop policy if exists "Users upload submission pictures" on storage.objects;
create policy "Users upload submission pictures"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'submission-photos'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "Users remove submission pictures" on storage.objects;
create policy "Users remove submission pictures"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'submission-photos'
  and owner_id = auth.uid()::text
);

create or replace function public.admin_resolve_catalog_wall(
  target_crag_id uuid,
  target_wall_id uuid,
  new_crag_name text,
  new_wall_name text,
  target_lat double precision,
  target_lng double precision,
  new_crag_warning text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  resolved_crag_id uuid := target_crag_id;
  resolved_wall_id uuid := target_wall_id;
begin
  if not public.is_app_admin() then raise exception 'Not authorized'; end if;
  if resolved_wall_id is not null then return resolved_wall_id; end if;

  if resolved_crag_id is null then
    insert into public.crags (
      name, province, region, location, parking_location, approach_trail,
      access_notes, season, danger_info, created_by
    ) values (
      trim(new_crag_name),
      'BC',
      'Victoria',
      st_setsrid(st_makepoint(target_lng, target_lat), 4326)::geography,
      st_setsrid(st_makepoint(target_lng, target_lat), 4326)::geography,
      'Approach details awaiting confirmation.',
      'Confirm access and parking before visiting.',
      'Confirm local conditions',
      trim(new_crag_warning),
      auth.uid()
    ) returning id into resolved_crag_id;
  end if;

  insert into public.walls (crag_id, name)
  values (resolved_crag_id, trim(new_wall_name))
  returning id into resolved_wall_id;

  return resolved_wall_id;
end;
$$;

grant execute on function public.admin_resolve_catalog_wall(
  uuid, uuid, text, text, double precision, double precision, text
) to authenticated;

create or replace function public.admin_save_catalog_route(
  target_route_id uuid,
  target_wall_id uuid,
  route_name text,
  route_grade text,
  route_rating double precision,
  route_type_value text,
  pitch_type_value text,
  route_angle text,
  route_height integer,
  route_bolts integer,
  route_gear_notes text,
  route_length_value integer,
  route_rope_length integer,
  route_top_rope boolean,
  route_lat double precision,
  route_lng double precision,
  route_description text,
  route_approach_notes text,
  route_descent_notes text,
  route_danger_info text,
  route_image_url text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  saved_id uuid := coalesce(target_route_id, gen_random_uuid());
begin
  if not public.is_app_admin() then raise exception 'Not authorized'; end if;
  if trim(route_name) = '' then raise exception 'Route name is required'; end if;
  if trim(route_grade) = '' then raise exception 'Grade is required'; end if;

  insert into public.routes (
    id, wall_id, name, grade, rating, route_type, pitch_type, angle,
    height_meters, bolts, gear_notes, route_length, rope_length, top_rope,
    location, description, approach_notes, descent_notes, danger_info,
    image_url, created_by
  ) values (
    saved_id,
    target_wall_id,
    trim(route_name),
    trim(route_grade),
    route_rating,
    route_type_value,
    pitch_type_value,
    route_angle,
    route_height,
    route_bolts,
    route_gear_notes,
    route_length_value,
    route_rope_length,
    route_top_rope,
    case
      when route_lat is null or route_lng is null then null
      else st_setsrid(st_makepoint(route_lng, route_lat), 4326)::geography
    end,
    route_description,
    route_approach_notes,
    route_descent_notes,
    route_danger_info,
    coalesce(route_image_url, ''),
    auth.uid()
  )
  on conflict (id) do update set
    wall_id = excluded.wall_id,
    name = excluded.name,
    grade = excluded.grade,
    rating = excluded.rating,
    route_type = excluded.route_type,
    pitch_type = excluded.pitch_type,
    angle = excluded.angle,
    height_meters = excluded.height_meters,
    bolts = excluded.bolts,
    gear_notes = excluded.gear_notes,
    route_length = excluded.route_length,
    rope_length = excluded.rope_length,
    top_rope = excluded.top_rope,
    location = excluded.location,
    description = excluded.description,
    approach_notes = excluded.approach_notes,
    descent_notes = excluded.descent_notes,
    danger_info = excluded.danger_info,
    image_url = case
      when excluded.image_url = '' then public.routes.image_url
      else excluded.image_url
    end;

  return saved_id;
end;
$$;

grant execute on function public.admin_save_catalog_route(
  uuid, uuid, text, text, double precision, text, text, text, integer,
  integer, text, integer, integer, boolean, double precision,
  double precision, text, text, text, text, text
) to authenticated;

create or replace function public.admin_update_route_image(
  target_route_id uuid,
  new_image_url text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_app_admin() then raise exception 'Not authorized'; end if;
  update public.routes set image_url = trim(new_image_url)
  where id = target_route_id;
  if not found then raise exception 'Route not found'; end if;
end;
$$;

grant execute on function public.admin_update_route_image(uuid, text)
to authenticated;

create or replace function public.climb_catalog()
returns jsonb
language sql
stable
security definer
set search_path = public
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

grant select on public.app_admins to authenticated;
grant execute on function public.is_app_admin() to authenticated;
grant execute on function public.climb_catalog() to anon, authenticated;
