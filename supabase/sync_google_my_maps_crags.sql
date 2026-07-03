-- Synchronize published crag pins with the supplied Victoria Bouldering Areas
-- Google My Maps layer and merge Cordova Bay's Fleming Beach wall into the
-- existing Fleming Beach crag. Safe to rerun.

begin;

with mapped(name, lng, lat) as (values
  ('Cyberia', -123.4568024, 48.5260413),
  ('Head Cut Off Cliff', -123.4648919, 48.4931251),
  ('Hundred Acre Wood', -123.4622526, 48.4921723),
  ('Pike Lake Boulder', -123.4613460, 48.4927589),
  ('Lone Boulder', -123.4528434, 48.4882438),
  ('Petropolis', -123.5201883, 48.5464584),
  ('Cordova Bay', -123.3537466, 48.5081678),
  ('Cordova Bay Boulders', -123.3537466, 48.5081678),
  ('Fleming Beach', -123.4104538, 48.4200589),
  ('Government House Bluffs', -123.3402443, 48.4163846),
  ('Gonzales Hill Tall Overhang', -123.3199131, 48.4106093),
  ('Gonzales Hill Orange wall', -123.3199158, 48.4114229),
  ('Gordon''s Beach', -123.8300961, 48.3634028),
  ('Francis King Wall', -123.4456712, 48.4888695),
  ('Flea Beach', -123.9315856, 48.3818723),
  ('Flea Beach Boulders', -123.9315856, 48.3818723),
  ('Sombrio', -124.2976373, 48.4944440),
  ('Sombrio Beach', -124.2976373, 48.4944440),
  ('Sombrio Sea Stack', -124.2938098, 48.4923430),
  ('The Dark Side Boulders', -123.9061106, 49.0718531),
  ('Foster St', -123.4218264, 48.4261428),
  ('Millstream Boulders', -123.5115892, 48.4846189),
  ('Millstream Bluff', -123.5115892, 48.4846189),
  ('Muir Creek', -123.8730780, 48.3997420),
  ('Saxe Point', -123.4162429, 48.4219224),
  ('Mt Newton', -123.4417043, 48.6116583),
  ('Mount Newton', -123.4417043, 48.6116583),
  ('Utgard Boulders', -123.4061837, 48.5463447),
  ('Babylon Sector Jordan River', -124.0520006, 48.4330661),
  ('Green Cave', -124.0063060, 48.4101253),
  ('Otter Point', -123.8221652, 48.3572708),
  ('Feisty Rock', -123.4301426, 48.5219674),
  ('Mt Work', -123.4836220, 48.5231043),
  ('Mt Work Boulders', -123.4836220, 48.5231043),
  ('Devonian Park Bouldering', -123.5350803, 48.3610819),
  ('Mill Hill Grad Boulder', -123.4809638, 48.4575025),
  ('Wasteland Boulder', -123.5188016, 48.4523658),
  ('Mount Wells', -123.5565824, 48.4436232),
  ('Mt Wells Cave', -123.5565824, 48.4436232),
  ('Scafe Hill', -123.4838006, 48.4881488),
  ('Munn Road', -123.460333475, 48.491575025)
), points as (
  select
    name,
    st_setsrid(st_makepoint(lng, lat), 4326)::geography as point
  from mapped
)
update public.crags c
set location = points.point,
    parking_location = coalesce(c.parking_location, points.point)
from points
where lower(trim(c.name)) = lower(points.name);

do $$
declare
  target_crag_id uuid;
  source_wall_id uuid;
  target_wall_id uuid;
begin
  select id into target_crag_id
  from public.crags
  where lower(trim(name)) = 'fleming beach'
  order by (id = '10000000-0000-0000-0000-000000000003'::uuid) desc,
           created_at
  limit 1;

  select w.id into source_wall_id
  from public.walls w
  join public.crags c on c.id = w.crag_id
  where lower(trim(c.name)) = 'cordova bay'
    and lower(trim(w.name)) = 'fleming beach'
  limit 1;

  if target_crag_id is not null and source_wall_id is not null then
    select id into target_wall_id
    from public.walls
    where crag_id = target_crag_id
      and lower(trim(name)) = 'fleming beach'
    limit 1;

    if target_wall_id is null then
      update public.walls
      set crag_id = target_crag_id
      where id = source_wall_id;
    else
      update public.routes
      set wall_id = target_wall_id
      where wall_id = source_wall_id;
      delete from public.walls where id = source_wall_id;
    end if;
  end if;
end;
$$;

commit;
