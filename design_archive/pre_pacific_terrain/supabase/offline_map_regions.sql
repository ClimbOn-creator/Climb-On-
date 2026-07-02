-- Admin-editable offline download region polygons.
-- Run after admin_map_editor_setup.sql. Safe to run more than once.

create table if not exists public.offline_map_regions (
  id text primary key,
  boundary_polygons jsonb not null,
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now(),
  constraint offline_map_regions_polygons_are_arrays check (
    jsonb_typeof(boundary_polygons) = 'array'
  )
);

alter table public.offline_map_regions enable row level security;

drop policy if exists "Anyone reads offline map regions"
on public.offline_map_regions;
create policy "Anyone reads offline map regions"
on public.offline_map_regions for select
using (true);

create or replace function public.admin_update_offline_map_region(
  region_id text,
  boundary_polygons jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  polygon jsonb;
begin
  if not public.is_app_admin() then
    raise exception 'Not authorized';
  end if;

  if region_id not in (
    'the-islands',
    'the-coast',
    'vancouver-coast-mountains',
    'thompson-okanagan',
    'bc-rockies',
    'cariboo-chilcotin-coast',
    'northern-bc',
    'alberta-rockies-coming-soon'
  ) then
    raise exception 'Unknown offline map region';
  end if;

  if jsonb_typeof(boundary_polygons) <> 'array'
     or jsonb_array_length(boundary_polygons) < 1 then
    raise exception 'At least one polygon is required';
  end if;

  for polygon in select value from jsonb_array_elements(boundary_polygons)
  loop
    if jsonb_typeof(polygon) <> 'array'
       or jsonb_array_length(polygon) < 3
       or jsonb_array_length(polygon) > 10000 then
      raise exception 'Each polygon requires 3 to 10000 points';
    end if;
  end loop;

  insert into public.offline_map_regions (
    id,
    boundary_polygons,
    updated_by,
    updated_at
  ) values (
    region_id,
    boundary_polygons,
    auth.uid(),
    now()
  )
  on conflict (id) do update
  set boundary_polygons = excluded.boundary_polygons,
      updated_by = excluded.updated_by,
      updated_at = excluded.updated_at;
end;
$$;

grant select on public.offline_map_regions to anon, authenticated;
grant execute on function public.admin_update_offline_map_region(text, jsonb)
  to authenticated;
