-- Full administrator route editor for every crag and wall.
-- Run after schema.sql and admin_map_editor_setup.sql.

alter table public.routes
add column if not exists image_url text not null default '';

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
