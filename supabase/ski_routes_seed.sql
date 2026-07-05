-- Climb On ski touring starter catalog.
--
-- Run this in Supabase SQL Editor after the main schema.
-- Safe to rerun: stable UUIDs + on conflict update.

create table if not exists public.ski_routes (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  area text not null,
  province text not null default 'BC',
  region text not null,
  location geography(point, 4326) not null,
  trailhead geography(point, 4326) not null,
  distance_km double precision not null,
  elevation_gain_meters integer not null,
  max_slope_angle_degrees integer not null default 0 check (max_slope_angle_degrees between 0 and 90),
  difficulty text not null,
  aspect text not null,
  avalanche_terrain text not null,
  season text not null,
  description text not null,
  approach_notes text not null,
  descent_notes text not null,
  danger_info text not null,
  image_url text not null,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

alter table public.ski_routes enable row level security;

drop policy if exists "Ski routes are readable" on public.ski_routes;
create policy "Ski routes are readable"
on public.ski_routes for select
using (true);

create table if not exists public.ski_route_submissions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  submitter_name text default '',
  route_name text not null,
  area text not null,
  region text not null,
  difficulty text not null,
  distance_km double precision not null,
  elevation_gain_meters integer not null,
  max_slope_angle_degrees integer not null default 0 check (max_slope_angle_degrees between 0 and 90),
  aspect text not null,
  avalanche_terrain text not null,
  season text not null,
  latitude double precision not null,
  longitude double precision not null,
  trailhead_latitude double precision not null,
  trailhead_longitude double precision not null,
  image_url text not null,
  description text not null,
  approach_notes text not null,
  descent_notes text not null,
  danger_info text not null,
  status text not null default 'pending',
  created_at timestamptz not null default now()
);

alter table public.ski_route_submissions enable row level security;

alter table public.ski_routes
  add column if not exists max_slope_angle_degrees integer not null default 0;

alter table public.ski_route_submissions
  add column if not exists max_slope_angle_degrees integer not null default 0;

drop policy if exists "Anyone can submit ski routes" on public.ski_route_submissions;
create policy "Anyone can submit ski routes"
on public.ski_route_submissions for insert
with check (true);

drop policy if exists "Users read own ski submissions" on public.ski_route_submissions;
create policy "Users read own ski submissions"
on public.ski_route_submissions for select
using (auth.uid() = user_id);

insert into public.ski_routes (
  id,
  name,
  area,
  province,
  region,
  location,
  trailhead,
  distance_km,
  elevation_gain_meters,
  difficulty,
  aspect,
  avalanche_terrain,
  season,
  description,
  approach_notes,
  descent_notes,
  danger_info,
  image_url
) values
  (
    '40000000-0000-0000-0000-000000000001',
    'Brohm Ridge Tour',
    'Garibaldi',
    'BC',
    'Sea to Sky',
    st_setsrid(st_makepoint(-123.1050, 49.9120), 4326)::geography,
    st_setsrid(st_makepoint(-123.1330, 49.8755), 4326)::geography,
    13.5,
    980,
    'Intermediate',
    'Southwest',
    'Complex',
    'Mid winter through spring',
    'A broad ridge tour with big views and several descent options when conditions line up.',
    'Start from the winter parking approach and follow the road grade toward the ridge.',
    'Descend the ascent route or choose supported slopes only after assessing avalanche conditions.',
    'Avalanche exposure, cornices, changing visibility, and snowmobile traffic.',
    'https://images.unsplash.com/photo-1517824806704-9040b037703b'
  ),
  (
    '40000000-0000-0000-0000-000000000002',
    'Paul Ridge Meadows',
    'Garibaldi',
    'BC',
    'Sea to Sky',
    st_setsrid(st_makepoint(-123.0710, 49.9650), 4326)::geography,
    st_setsrid(st_makepoint(-123.1202, 49.9574), 4326)::geography,
    16.0,
    1120,
    'Advanced',
    'North',
    'Challenging',
    'Winter through spring',
    'A long tour into rolling alpine terrain with excellent views and many terrain choices.',
    'Use the park trail approach and continue toward the open ridge system.',
    'Return by the approach or choose mellow glades when hazard allows.',
    'Long day, avalanche terrain, whiteout navigation, and cold exposure.',
    'https://images.unsplash.com/photo-1488590528505-98d2b5aba04b'
  ),
  (
    '40000000-0000-0000-0000-000000000003',
    'Red Heather to Elfin Lakes',
    'Garibaldi',
    'BC',
    'Sea to Sky',
    st_setsrid(st_makepoint(-123.0455, 49.7930), 4326)::geography,
    st_setsrid(st_makepoint(-123.0535, 49.7816), 4326)::geography,
    22.0,
    780,
    'Intermediate',
    'Rolling',
    'Simple to Challenging',
    'Winter through spring',
    'A classic access tour with rolling terrain, big views, and a hut destination.',
    'Skin from the Diamond Head trailhead toward Red Heather and continue toward Elfin Lakes.',
    'Return along the marked winter route, watching for faster downhill traffic.',
    'Avalanche hazard on adjacent slopes, weather exposure, and long travel time.',
    'https://images.unsplash.com/photo-1551524559-8af4e6624178'
  ),
  (
    '40000000-0000-0000-0000-000000000004',
    'Gin Peak',
    'Callaghan',
    'BC',
    'Sea to Sky',
    st_setsrid(st_makepoint(-123.2200, 50.1500), 4326)::geography,
    st_setsrid(st_makepoint(-123.2070, 50.1395), 4326)::geography,
    11.8,
    920,
    'Advanced',
    'Northwest',
    'Complex',
    'Mid winter through spring',
    'A popular Coast Mountains objective with alpine bowls and a summit finish.',
    'Approach from Callaghan road access and gain the ridge system conservatively.',
    'Descend supported bowls or ridge features depending on hazard.',
    'Avalanche exposure, cornices, wind slabs, and road access variability.',
    'https://images.unsplash.com/photo-1501706362039-c6e809e1b733'
  ),
  (
    '40000000-0000-0000-0000-000000000005',
    'Rainbow Lake Approach',
    'Whistler',
    'BC',
    'Sea to Sky',
    st_setsrid(st_makepoint(-123.0400, 50.0900), 4326)::geography,
    st_setsrid(st_makepoint(-122.9960, 50.1050), 4326)::geography,
    18.5,
    1020,
    'Advanced',
    'East',
    'Challenging',
    'Spring',
    'A long fitness-oriented tour toward alpine terrain above Whistler.',
    'Use the established access trail and expect a long approach before open terrain.',
    'Return the approach route unless conditions and group skill support alternatives.',
    'Long distance, creek crossings, changing snowline, and avalanche terrain overhead.',
    'https://images.unsplash.com/photo-1519681393784-d120267933ba'
  ),
  (
    '40000000-0000-0000-0000-000000000006',
    'Duffey Lake Scout Tour',
    'Duffey Lake',
    'BC',
    'Coast Mountains',
    st_setsrid(st_makepoint(-122.5320, 50.3760), 4326)::geography,
    st_setsrid(st_makepoint(-122.5160, 50.3710), 4326)::geography,
    9.8,
    880,
    'Advanced',
    'Northeast',
    'Complex',
    'Winter through spring',
    'A committing Coast Mountains tour with rewarding turns and serious terrain management.',
    'Begin from a plowed pullout and skin into the drainage.',
    'Use conservative terrain choices and preserve energy for the exit.',
    'Avalanche terrain, overhead hazard, creek crossings, and remote rescue.',
    'https://images.unsplash.com/photo-1517849845537-4d257902454a'
  ),
  (
    '40000000-0000-0000-0000-000000000007',
    'Cayoosh Shoulder',
    'Duffey Lake',
    'BC',
    'Coast Mountains',
    st_setsrid(st_makepoint(-122.5880, 50.4070), 4326)::geography,
    st_setsrid(st_makepoint(-122.5810, 50.3920), 4326)::geography,
    12.4,
    1180,
    'Expert',
    'North',
    'Complex',
    'Mid winter through spring',
    'A larger alpine objective with steep terrain options and serious exposure.',
    'Approach through forest and gain the shoulder using conservative spacing.',
    'Descend chosen alpine features only with strong stability confidence.',
    'Complex avalanche terrain, cornices, glaciers nearby, and high consequence slopes.',
    'https://images.unsplash.com/photo-1454496522488-7a8e488e8606'
  ),
  (
    '40000000-0000-0000-0000-000000000008',
    'Zoa Peak',
    'Coquihalla',
    'BC',
    'Coquihalla',
    st_setsrid(st_makepoint(-121.0770, 49.6040), 4326)::geography,
    st_setsrid(st_makepoint(-121.0850, 49.5940), 4326)::geography,
    8.5,
    720,
    'Intermediate',
    'Northwest',
    'Challenging',
    'Winter through spring',
    'A popular Coquihalla tour with accessible alpine-style terrain.',
    'Start near the highway pullout and gain the ridge through forest openings.',
    'Return through glades or along the approach depending on conditions.',
    'Highway weather, avalanche slopes, wind loading, and fast-changing visibility.',
    'https://images.unsplash.com/photo-1491555103944-7c647fd857e6'
  ),
  (
    '40000000-0000-0000-0000-000000000009',
    'Needle Peak Glades',
    'Coquihalla',
    'BC',
    'Coquihalla',
    st_setsrid(st_makepoint(-121.1110, 49.5940), 4326)::geography,
    st_setsrid(st_makepoint(-121.1040, 49.5890), 4326)::geography,
    7.0,
    650,
    'Advanced',
    'North',
    'Challenging',
    'Mid winter',
    'Shorter glade touring with steeper nearby terrain and quick weather changes.',
    'Approach from highway parking and stay in supported trees when hazard is elevated.',
    'Descend glades back toward the approach corridor.',
    'Tree wells, wind slabs, highway access, and terrain traps.',
    'https://images.unsplash.com/photo-1549880338-65ddcdfd017b'
  ),
  (
    '40000000-0000-0000-0000-000000000010',
    'Mount Cain Backside Glades',
    'Mount Cain',
    'BC',
    'Vancouver Island',
    st_setsrid(st_makepoint(-126.3200, 50.2350), 4326)::geography,
    st_setsrid(st_makepoint(-126.3140, 50.2320), 4326)::geography,
    7.2,
    640,
    'Intermediate',
    'Northwest',
    'Challenging',
    'Mid winter',
    'Sheltered glade touring near Mount Cain with short laps and colder snow.',
    'Start near the ski area boundary and respect all closures.',
    'Lap supported glades and return to the same approach corridor.',
    'Tree wells, storm slabs, and boundary or closure management.',
    'https://images.unsplash.com/photo-1551698618-1dfe5d97d256'
  ),
  (
    '40000000-0000-0000-0000-000000000011',
    'Forbidden Plateau Meadows',
    'Strathcona',
    'BC',
    'Vancouver Island',
    st_setsrid(st_makepoint(-125.3070, 49.7100), 4326)::geography,
    st_setsrid(st_makepoint(-125.2920, 49.7030), 4326)::geography,
    10.0,
    520,
    'Beginner to Intermediate',
    'Rolling',
    'Simple',
    'Winter',
    'A mellow rolling tour through meadows and forest openings.',
    'Follow established winter routes from the plateau access.',
    'Return along the approach, watching for thin snowpack around creeks.',
    'Navigation in storms, creek holes, and rapidly warming snow.',
    'https://images.unsplash.com/photo-1483664852095-d6cc6870702d'
  ),
  (
    '40000000-0000-0000-0000-000000000012',
    'Mount Becher Approach',
    'Strathcona',
    'BC',
    'Vancouver Island',
    st_setsrid(st_makepoint(-125.3200, 49.6940), 4326)::geography,
    st_setsrid(st_makepoint(-125.2920, 49.7030), 4326)::geography,
    12.5,
    820,
    'Intermediate',
    'East',
    'Challenging',
    'Winter through spring',
    'A scenic island tour toward alpine terrain above Forbidden Plateau.',
    'Use the plateau approach and gain elevation through forest and open benches.',
    'Return by the approach or supported glades when conditions allow.',
    'Fog navigation, cornices near alpine ridges, and coastal storm slabs.',
    'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee'
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
  image_url = excluded.image_url;

create or replace function public.ski_catalog()
returns jsonb
language sql
stable
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', id::text,
    'name', name,
    'area', area,
    'province', province,
    'region', region,
    'lat', st_y(location::geometry),
    'lng', st_x(location::geometry),
    'trailheadLat', st_y(trailhead::geometry),
    'trailheadLng', st_x(trailhead::geometry),
    'distanceKm', distance_km,
    'elevationGainMeters', elevation_gain_meters,
    'maxSlopeAngleDegrees', max_slope_angle_degrees,
    'difficulty', difficulty,
    'aspect', aspect,
    'avalancheTerrain', avalanche_terrain,
    'season', season,
    'description', description,
    'approachNotes', approach_notes,
    'descentNotes', descent_notes,
    'dangerInfo', danger_info,
    'imageUrl', image_url,
    'createdBy', coalesce(created_by::text, '')
  ) order by name), '[]'::jsonb)
  from public.ski_routes;
$$;
