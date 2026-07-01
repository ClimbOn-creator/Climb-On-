-- Editable trailhead pictures for climbing routes.
-- Run after admin_catalog_route_editor.sql. Safe to rerun.

alter table public.routes
add column if not exists trailhead_image_url text not null default '';

create or replace function public.admin_update_route_trailhead_image(
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
  update public.routes set trailhead_image_url = trim(new_image_url)
  where id = target_route_id;
  if not found then raise exception 'Route not found'; end if;
end;
$$;

grant execute on function public.admin_update_route_trailhead_image(uuid, text)
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
              'trailheadImageUrl', routes.trailhead_image_url,
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

grant execute on function public.climb_catalog() to anon, authenticated;
