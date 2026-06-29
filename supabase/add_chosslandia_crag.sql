-- Adds Chosslandia and its Main wall near UVic.
-- The coordinates are intentionally marked approximate until confirmed on site.
-- Safe to run more than once.

begin;

alter table public.crags
add column if not exists created_by uuid references auth.users(id) on delete set null;

insert into public.crags (
  id,
  name,
  province,
  region,
  location,
  parking_location,
  approach_trail,
  access_notes,
  season,
  danger_info,
  created_by
) values (
  '10000000-0000-0000-0000-000000000007',
  'Chosslandia',
  'BC',
  'Victoria / UVic',
  st_setsrid(st_makepoint(-123.31170, 48.46340), 4326)::geography,
  st_setsrid(st_makepoint(-123.31170, 48.46340), 4326)::geography,
  'Approximate UVic-area pin. Record or submit the confirmed approach before visiting.',
  'Confirm the exact location, land access, parking, and current climbing permission.',
  'Confirm local conditions',
  'New crag entry with an approximate location. Expect loose rock and verify all hazards before climbing.',
  (
    select id from auth.users
    where id = '519cee87-e5fb-4374-a61b-5dd45d912c81'
  )
)
on conflict (id) do update set
  name = excluded.name,
  province = excluded.province,
  region = excluded.region,
  location = excluded.location,
  parking_location = excluded.parking_location,
  approach_trail = excluded.approach_trail,
  access_notes = excluded.access_notes,
  season = excluded.season,
  danger_info = excluded.danger_info,
  created_by = coalesce(public.crags.created_by, excluded.created_by);

insert into public.walls (id, crag_id, name) values (
  '20000000-0000-0000-0000-000000000013',
  '10000000-0000-0000-0000-000000000007',
  'Main'
)
on conflict (id) do update set
  crag_id = excluded.crag_id,
  name = excluded.name;

commit;
