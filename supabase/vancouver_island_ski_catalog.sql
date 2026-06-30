-- Focus the ski catalogue on Vancouver Island and add researched starter tours.
-- Run after admin_ski_route_editor.sql. Safe to run more than once.
--
-- Route points and statistics are planning aids from the public source_url.
-- No ascent/descent polyline is inserted: field-verify and record/draw those in
-- the creator tools before treating them as navigation data.

create extension if not exists postgis;

alter table public.ski_routes
  add column if not exists source_url text not null default '';

create or replace function public.is_on_vancouver_island(point geography)
returns boolean
language sql
immutable
strict
set search_path = public
as $$
  select st_covers(
    st_geomfromtext(
      'POLYGON((-128.65 50.92,-127.10 51.00,-126.60 50.63,-125.05 50.15,-123.72 49.30,-123.27 48.78,-123.30 48.30,-124.30 48.30,-125.05 48.58,-126.15 49.10,-127.20 49.85,-128.35 50.50,-128.65 50.92))',
      4326
    ),
    point::geometry
  );
$$;

-- Remove mainland catalogue entries instead of merely hiding their markers.
delete from public.ski_routes
where not public.is_on_vancouver_island(location);

insert into public.ski_routes (
  id, name, area, province, region, location, trailhead, distance_km,
  elevation_gain_meters, difficulty, aspect, avalanche_terrain, season,
  description, approach_notes, descent_notes, danger_info, image_url,
  source_url
) values
  (
    '40000000-0000-0000-0000-000000000010',
    'Mount Cain Backside Glades', 'Mount Cain', 'BC',
    'North Vancouver Island',
    st_setsrid(st_makepoint(-126.3200, 50.2350), 4326)::geography,
    st_setsrid(st_makepoint(-126.3140, 50.2320), 4326)::geography,
    7.2, 640, 'Intermediate', 'Northwest', 'Challenging', 'Mid winter',
    'Sheltered glade touring near Mount Cain with short laps and colder snow.',
    'Start near the ski area boundary and confirm current boundary rules and closures.',
    'Use supported glades and return through the same familiar approach corridor.',
    'Tree wells, storm slabs, limited visibility, and ski-area boundary management.',
    'https://images.unsplash.com/photo-1551698618-1dfe5d97d256', ''
  ),
  (
    '40000000-0000-0000-0000-000000000011',
    'Forbidden Plateau Meadows', 'Forbidden Plateau', 'BC', 'Strathcona',
    st_setsrid(st_makepoint(-125.3070, 49.7100), 4326)::geography,
    st_setsrid(st_makepoint(-125.2920, 49.7030), 4326)::geography,
    10.0, 520, 'Beginner to Intermediate', 'Rolling', 'Simple', 'Winter',
    'A mellow tour through rolling meadows and forest openings from Paradise Meadows.',
    'Use the Paradise Meadows access and established winter corridors.',
    'Return along the approach and watch for thin coverage around creeks and lakes.',
    'Storm navigation, creek holes, lake ice, tree wells, and rapidly warming coastal snow.',
    'https://images.unsplash.com/photo-1483664852095-d6cc6870702d',
    'https://bcparks.ca/strathcona-park/'
  ),
  (
    '40000000-0000-0000-0000-000000000012',
    'Mount Becher', 'Forbidden Plateau', 'BC', 'Strathcona',
    st_setsrid(st_makepoint(-125.3200, 49.6940), 4326)::geography,
    st_setsrid(st_makepoint(-125.2920, 49.7030), 4326)::geography,
    12.5, 820, 'Intermediate', 'East and North', 'Challenging',
    'Winter through spring',
    'An accessible Island summit objective with short ski options above Forbidden Plateau.',
    'Travel from the plateau access through forest and open benches toward Mount Becher.',
    'Retrace the approach or use supported glades only after confirming conditions.',
    'Fog navigation, cornices, coastal storm slabs, thin coverage, and terrain traps.',
    'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee',
    'https://www.wildisle.ca/turnsandtours/Forbidden.pdf'
  ),
  (
    '40000000-0000-0000-0000-000000000013',
    'Mount Elma', 'Forbidden Plateau', 'BC', 'Strathcona',
    st_setsrid(st_makepoint(-125.323884, 49.707658), 4326)::geography,
    st_setsrid(st_makepoint(-125.2920, 49.7030), 4326)::geography,
    14.0, 560, 'Intermediate', 'West and Northwest', 'Challenging',
    'Winter through spring',
    'A broad summit plateau above Lake Helen Mackenzie with gentle upper-mountain terrain.',
    'Approach from Paradise Meadows via the Lake Trail area and assess all lake crossings.',
    'The west side toward the Brooks-Elma col offers options when stability and visibility allow.',
    'A short exposed step, avalanche terrain, frozen lake travel, tree wells, and whiteout navigation.',
    'https://images.unsplash.com/photo-1519681393784-d120267933ba',
    'https://wildisle.ca/magazine/backissues/pdfs/WI_14.pdf'
  ),
  (
    '40000000-0000-0000-0000-000000000014',
    'Mount Allan Brooks', 'Forbidden Plateau', 'BC', 'Strathcona',
    st_setsrid(st_makepoint(-125.343056, 49.716111), 4326)::geography,
    st_setsrid(st_makepoint(-125.2920, 49.7030), 4326)::geography,
    17.0, 720, 'Advanced', 'North and East', 'Complex',
    'Winter through spring',
    'A varied Forbidden Plateau objective with forest travel, a north ridge, and open upper slopes.',
    'Start from Paradise Meadows and use the Lake Trail side of Lake Helen Mackenzie.',
    'Retrace the north ridge or choose supported terrain appropriate to the day''s hazard.',
    'Steep treed slopes, avalanche terrain, creek crossings, cornices, and difficult navigation.',
    'https://images.unsplash.com/photo-1517824806704-9040b037703b',
    'https://wildisle.ca/magazine/backissues/pdfs/WI_14.pdf'
  ),
  (
    '40000000-0000-0000-0000-000000000015',
    'Castlecrag Circuit', 'Forbidden Plateau', 'BC', 'Strathcona',
    st_setsrid(st_makepoint(-125.386667, 49.662222), 4326)::geography,
    st_setsrid(st_makepoint(-125.2920, 49.7030), 4326)::geography,
    30.0, 1300, 'Expert / multi-day', 'All aspects', 'Complex', 'Spring',
    'A serious circuit around Moat Lake linking remote alpine terrain near Castlecrag and Mount Albert Edward.',
    'The public description begins at Paradise Meadows and reaches the Circlet-Moat Lake area before the circuit.',
    'Multiple alpine descents are possible; select the final line from current conditions in the field.',
    'Remote complex avalanche terrain, cornices, exposed traverses, lake travel, whiteouts, and a very long exit.',
    'https://images.unsplash.com/photo-1454496522488-7a8e488e8606',
    'https://www.wildisle.ca/turnsandtours/Forbidden.pdf'
  ),
  (
    '40000000-0000-0000-0000-000000000016',
    '5040 Peak West Ridge', 'Sutton Pass', 'BC',
    'Central Vancouver Island',
    st_setsrid(st_makepoint(-125.282476, 49.191611), 4326)::geography,
    st_setsrid(st_makepoint(-125.3150, 49.2050), 4326)::geography,
    8.0, 930, 'Expert', 'West and North', 'Complex',
    'Winter through spring',
    'A steep approach to the Hišimy̓awiƛ Hut and committing ski terrain around 5040 Peak.',
    'Access uses Marion Creek Main; winter road conditions can substantially lengthen the trip.',
    'The west-ridge benches provide the most moderate published option; descend only after field assessment.',
    'Very steep approach, complex avalanche terrain, cliffs, gullies, remote rescue, and unreliable winter road access.',
    'https://images.unsplash.com/photo-1491555103944-7c647fd857e6',
    'https://www.10adventures.com/ski-touring-acc-5040-hut/'
  ),
  (
    '40000000-0000-0000-0000-000000000017',
    'Mount Myra Southwest Ridge', 'Buttle Lake', 'BC', 'Strathcona',
    st_setsrid(st_makepoint(-125.606389, 49.544167), 4326)::geography,
    st_setsrid(st_makepoint(-125.5830, 49.5680), 4326)::geography,
    16.0, 1450, 'Expert', 'Southwest', 'Complex',
    'Winter through spring',
    'A remote, high-commitment Island objective approached from the Myra Falls mine side.',
    'The published trip report approaches Tennant Lake before a steep couloir gains the southwest ridge.',
    'No default descent is implied; use a verified line selected for current snow and access conditions.',
    '45-degree-plus terrain, cliff bands, complex avalanche exposure, industrial access, and remote rescue.',
    'https://images.unsplash.com/photo-1549880338-65ddcdfd017b',
    'https://thecollectivemags.ca/van-isle-ski-touring/'
  ),
  (
    '40000000-0000-0000-0000-000000000018',
    'Mount Arrowsmith Alpine', 'Arrowsmith Massif', 'BC',
    'Central Vancouver Island',
    st_setsrid(st_makepoint(-124.594444, 49.223611), 4326)::geography,
    st_setsrid(st_makepoint(-124.6020, 49.2370), 4326)::geography,
    10.0, 850, 'Advanced', 'North and East', 'Complex',
    'Winter through spring',
    'A rugged alpine tour on Vancouver Island''s prominent Arrowsmith massif.',
    'Access is via logging roads and the old ski-area side; confirm gates and road conditions before leaving.',
    'Published reports show several possibilities, but no unverified line is presented as a navigation track.',
    'Avalanche terrain, cliff bands, rapidly changing visibility, variable road access, and no facilities.',
    'https://images.unsplash.com/photo-1501706362039-c6e809e1b733',
    'https://citizenclass.ca/ski-touring-mount-arrowsmith/'
  )
on conflict (id) do update set
  name = excluded.name,
  area = excluded.area,
  province = excluded.province,
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
  source_url = excluded.source_url;

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
  where public.is_on_vancouver_island(s.location);
$$;

grant execute on function public.ski_catalog() to anon, authenticated;
