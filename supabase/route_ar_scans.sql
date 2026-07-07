-- Lightweight route AR metadata.
-- Stores URLs and editor hints only; keep heavy scans/models outside Supabase
-- storage so the project stays within the small storage quota.
-- Run after admin_catalog_route_editor.sql and route_trailhead_images.sql.

create table if not exists public.route_ar_scans (
  id uuid primary key default gen_random_uuid(),
  route_id uuid not null references public.routes(id) on delete cascade,
  asset_url text not null default '',
  anchor_image_url text not null default '',
  instructions text not null default '',
  scale_hint_meters double precision,
  beta_overlay jsonb not null default '{}'::jsonb,
  display_priority integer not null default 100,
  enabled boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (route_id),
  constraint route_ar_scans_scale_positive
    check (scale_hint_meters is null or scale_hint_meters > 0),
  constraint route_ar_scans_enabled_requires_asset
    check (not enabled or trim(asset_url) <> '')
);

alter table public.route_ar_scans
add column if not exists beta_overlay jsonb not null default '{}'::jsonb;

create index if not exists route_ar_scans_route_enabled_idx
on public.route_ar_scans (route_id, enabled);

create index if not exists route_ar_scans_priority_idx
on public.route_ar_scans (display_priority, updated_at desc)
where enabled;

alter table public.route_ar_scans enable row level security;

drop policy if exists "Route AR scans are readable" on public.route_ar_scans;
create policy "Route AR scans are readable"
on public.route_ar_scans for select
using (enabled);

drop policy if exists "Admins manage route AR scans" on public.route_ar_scans;
create policy "Admins manage route AR scans"
on public.route_ar_scans for all
to authenticated
using (public.is_app_admin())
with check (public.is_app_admin());

grant select on public.route_ar_scans to anon, authenticated;
grant insert, update, delete on public.route_ar_scans to authenticated;

create or replace function public.route_ar_scan_doc(scan public.route_ar_scans)
returns jsonb
language sql
stable
set search_path = public
as $$
  select jsonb_build_object(
    'id', scan.id::text,
    'routeId', scan.route_id::text,
    'assetUrl', scan.asset_url,
    'anchorImageUrl', scan.anchor_image_url,
    'instructions', scan.instructions,
    'scaleHintMeters', scan.scale_hint_meters,
    'betaOverlay', scan.beta_overlay,
    'displayPriority', scan.display_priority,
    'enabled', scan.enabled,
    'createdBy', coalesce(scan.created_by::text, ''),
    'createdAt', scan.created_at,
    'updatedAt', scan.updated_at
  );
$$;

grant execute on function public.route_ar_scan_doc(public.route_ar_scans)
to anon, authenticated;

create or replace function public.admin_save_route_ar_scan(
  target_route_id uuid,
  new_enabled boolean,
  new_asset_url text,
  new_anchor_image_url text default '',
  new_instructions text default '',
  new_scale_hint_meters double precision default null,
  new_display_priority integer default 100,
  new_beta_overlay jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  saved_scan public.route_ar_scans;
begin
  if not public.is_app_admin() then raise exception 'Not authorized'; end if;
  if not exists (select 1 from public.routes where id = target_route_id) then
    raise exception 'Route not found';
  end if;
  if new_enabled and trim(coalesce(new_asset_url, '')) = '' then
    raise exception 'AR asset URL is required when AR is enabled';
  end if;

  insert into public.route_ar_scans (
    route_id,
    asset_url,
    anchor_image_url,
    instructions,
    scale_hint_meters,
    beta_overlay,
    display_priority,
    enabled,
    created_by,
    updated_at
  ) values (
    target_route_id,
    trim(coalesce(new_asset_url, '')),
    trim(coalesce(new_anchor_image_url, '')),
    trim(coalesce(new_instructions, '')),
    new_scale_hint_meters,
    coalesce(new_beta_overlay, '{}'::jsonb),
    coalesce(new_display_priority, 100),
    new_enabled,
    auth.uid(),
    now()
  )
  on conflict (route_id) do update set
    asset_url = excluded.asset_url,
    anchor_image_url = excluded.anchor_image_url,
    instructions = excluded.instructions,
    scale_hint_meters = excluded.scale_hint_meters,
    beta_overlay = excluded.beta_overlay,
    display_priority = excluded.display_priority,
    enabled = excluded.enabled,
    updated_at = now()
  returning * into saved_scan;

  return public.route_ar_scan_doc(saved_scan);
end;
$$;

grant execute on function public.admin_save_route_ar_scan(
  uuid, boolean, text, text, text, double precision, integer, jsonb
) to authenticated;

create or replace function public.route_ar_candidates_for_crag(
  target_crag_id uuid,
  max_routes integer default 5
)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(jsonb_agg(candidate order by (candidate->>'popularityScore')::integer desc, candidate->>'routeName'), '[]'::jsonb)
  from (
    select jsonb_build_object(
      'routeId', routes.id::text,
      'routeName', routes.name,
      'wallName', walls.name,
      'grade', coalesce(routes.grade, ''),
      'rating', coalesce(routes.rating, 0),
      'sendCount', count(distinct user_sends.id),
      'commentCount', count(distinct route_comments.id),
      'hasAR', route_ar_scans.id is not null and route_ar_scans.enabled,
      'popularityScore',
        (count(distinct user_sends.id) * 4
          + count(distinct route_comments.id) * 2
          + floor(coalesce(routes.rating, 0) * 10)::integer)
    ) as candidate
    from public.routes
    join public.walls on walls.id = routes.wall_id
    left join public.user_sends on user_sends.route_id = routes.id
    left join public.route_comments on route_comments.route_id = routes.id
    left join public.route_ar_scans on route_ar_scans.route_id = routes.id
    where walls.crag_id = target_crag_id
    group by
      routes.id,
      routes.name,
      routes.grade,
      routes.rating,
      walls.name,
      route_ar_scans.id,
      route_ar_scans.enabled
    order by
      (count(distinct user_sends.id) * 4
        + count(distinct route_comments.id) * 2
        + floor(coalesce(routes.rating, 0) * 10)::integer) desc,
      routes.name
    limit greatest(1, least(coalesce(max_routes, 5), 10))
  ) ranked;
$$;

grant execute on function public.route_ar_candidates_for_crag(uuid, integer)
to anon, authenticated;

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
              'trailheadImageUrl', routes.trailhead_image_url,
              'createdBy', coalesce(routes.created_by::text, ''),
              'arScan', (
                select public.route_ar_scan_doc(route_ar_scans)
                from public.route_ar_scans
                where route_ar_scans.route_id = routes.id
                  and route_ar_scans.enabled
                limit 1
              )
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

grant execute on function public.climb_catalog() to anon, authenticated;
