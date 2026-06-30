import 'package:latlong2/latlong.dart';

import '../models/ski_route.dart';

// Vancouver Island starter catalogue. Locations and trip statistics are
// planning aids gathered from the linked public sources, not verified GPS
// tracks. Admin-drawn or recorded ascent/descent lines remain the source of
// truth for navigation geometry.
final skiRoutes = [
  const SkiRoute(
    id: 'mt-cain-glades',
    name: 'Mount Cain Backside Glades',
    area: 'Mount Cain',
    region: 'North Vancouver Island',
    location: LatLng(50.2350, -126.3200),
    trailhead: LatLng(50.2320, -126.3140),
    distanceKm: 7.2,
    elevationGainMeters: 640,
    difficulty: 'Intermediate',
    aspect: 'Northwest',
    avalancheTerrain: 'Challenging',
    season: 'Mid winter',
    description:
        'Sheltered glade touring near Mount Cain with short laps and colder snow.',
    approachNotes:
        'Start near the ski area boundary and confirm current boundary rules and closures.',
    descentNotes:
        'Use supported glades and return through the same familiar approach corridor.',
    dangerInfo:
        'Tree wells, storm slabs, limited visibility, and ski-area boundary management.',
    imageUrl: 'https://images.unsplash.com/photo-1551698618-1dfe5d97d256',
  ),
  const SkiRoute(
    id: 'forbidden-plateau-meadows',
    name: 'Forbidden Plateau Meadows',
    area: 'Forbidden Plateau',
    region: 'Strathcona',
    location: LatLng(49.7100, -125.3070),
    trailhead: LatLng(49.7030, -125.2920),
    distanceKm: 10.0,
    elevationGainMeters: 520,
    difficulty: 'Beginner to Intermediate',
    aspect: 'Rolling',
    avalancheTerrain: 'Simple',
    season: 'Winter',
    description:
        'A mellow tour through rolling meadows and forest openings from Paradise Meadows.',
    approachNotes:
        'Use the Paradise Meadows access and established winter corridors.',
    descentNotes:
        'Return along the approach and watch for thin coverage around creeks and lakes.',
    dangerInfo:
        'Storm navigation, creek holes, lake ice, tree wells, and rapidly warming coastal snow.',
    imageUrl: 'https://images.unsplash.com/photo-1483664852095-d6cc6870702d',
    sourceUrl: 'https://bcparks.ca/strathcona-park/',
  ),
  const SkiRoute(
    id: 'mount-becher',
    name: 'Mount Becher',
    area: 'Forbidden Plateau',
    region: 'Strathcona',
    location: LatLng(49.6940, -125.3200),
    trailhead: LatLng(49.7030, -125.2920),
    distanceKm: 12.5,
    elevationGainMeters: 820,
    difficulty: 'Intermediate',
    aspect: 'East and North',
    avalancheTerrain: 'Challenging',
    season: 'Winter through spring',
    description:
        'An accessible Island summit objective with short ski options above Forbidden Plateau.',
    approachNotes:
        'Travel from the plateau access through forest and open benches toward Mount Becher.',
    descentNotes:
        'Retrace the approach or use supported glades only after confirming conditions.',
    dangerInfo:
        'Fog navigation, cornices, coastal storm slabs, thin coverage, and terrain traps.',
    imageUrl: 'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee',
    sourceUrl: 'https://www.wildisle.ca/turnsandtours/Forbidden.pdf',
  ),
  const SkiRoute(
    id: 'mount-elma',
    name: 'Mount Elma',
    area: 'Forbidden Plateau',
    region: 'Strathcona',
    location: LatLng(49.707658, -125.323884),
    trailhead: LatLng(49.7030, -125.2920),
    distanceKm: 14.0,
    elevationGainMeters: 560,
    difficulty: 'Intermediate',
    aspect: 'West and Northwest',
    avalancheTerrain: 'Challenging',
    season: 'Winter through spring',
    description:
        'A broad summit plateau above Lake Helen Mackenzie with gentle upper-mountain terrain.',
    approachNotes:
        'Approach from Paradise Meadows via the Lake Trail area and assess all lake crossings.',
    descentNotes:
        'The west side toward the Brooks–Elma col offers options when stability and visibility allow.',
    dangerInfo:
        'A short exposed step, avalanche terrain, frozen lake travel, tree wells, and whiteout navigation.',
    imageUrl: 'https://images.unsplash.com/photo-1519681393784-d120267933ba',
    sourceUrl: 'https://wildisle.ca/magazine/backissues/pdfs/WI_14.pdf',
  ),
  const SkiRoute(
    id: 'mount-allan-brooks',
    name: 'Mount Allan Brooks',
    area: 'Forbidden Plateau',
    region: 'Strathcona',
    location: LatLng(49.716111, -125.343056),
    trailhead: LatLng(49.7030, -125.2920),
    distanceKm: 17.0,
    elevationGainMeters: 720,
    difficulty: 'Advanced',
    aspect: 'North and East',
    avalancheTerrain: 'Complex',
    season: 'Winter through spring',
    description:
        'A varied Forbidden Plateau objective with forest travel, a north ridge, and open upper slopes.',
    approachNotes:
        'Start from Paradise Meadows and use the Lake Trail side of Lake Helen Mackenzie.',
    descentNotes:
        'Retrace the north ridge or choose supported terrain appropriate to the day’s hazard.',
    dangerInfo:
        'Steep treed slopes, avalanche terrain, creek crossings, cornices, and difficult navigation.',
    imageUrl: 'https://images.unsplash.com/photo-1517824806704-9040b037703b',
    sourceUrl: 'https://wildisle.ca/magazine/backissues/pdfs/WI_14.pdf',
  ),
  const SkiRoute(
    id: 'castlecrag-circuit',
    name: 'Castlecrag Circuit',
    area: 'Forbidden Plateau',
    region: 'Strathcona',
    location: LatLng(49.662222, -125.386667),
    trailhead: LatLng(49.7030, -125.2920),
    distanceKm: 30.0,
    elevationGainMeters: 1300,
    difficulty: 'Expert / multi-day',
    aspect: 'All aspects',
    avalancheTerrain: 'Complex',
    season: 'Spring',
    description:
        'A serious circuit around Moat Lake linking remote alpine terrain near Castlecrag and Mount Albert Edward.',
    approachNotes:
        'The public description begins at Paradise Meadows and reaches the Circlet–Moat Lake area before the circuit.',
    descentNotes:
        'Multiple alpine descents are possible; the final line must be selected from current conditions in the field.',
    dangerInfo:
        'Remote complex avalanche terrain, cornices, exposed traverses, lake travel, whiteouts, and a very long exit.',
    imageUrl: 'https://images.unsplash.com/photo-1454496522488-7a8e488e8606',
    sourceUrl: 'https://www.wildisle.ca/turnsandtours/Forbidden.pdf',
  ),
  const SkiRoute(
    id: '5040-peak-west-ridge',
    name: '5040 Peak West Ridge',
    area: 'Sutton Pass',
    region: 'Central Vancouver Island',
    location: LatLng(49.191611, -125.282476),
    trailhead: LatLng(49.2050, -125.3150),
    distanceKm: 8.0,
    elevationGainMeters: 930,
    difficulty: 'Expert',
    aspect: 'West and North',
    avalancheTerrain: 'Complex',
    season: 'Winter through spring',
    description:
        'A steep approach to the Hišimy̓awiƛ Hut and committing ski terrain around 5040 Peak.',
    approachNotes:
        'Access uses Marion Creek Main; winter road conditions can substantially lengthen the trip.',
    descentNotes:
        'The west-ridge benches provide the most moderate published option; descend only after field assessment.',
    dangerInfo:
        'Very steep approach, complex avalanche terrain, cliffs, gullies, remote rescue, and unreliable winter road access.',
    imageUrl: 'https://images.unsplash.com/photo-1491555103944-7c647fd857e6',
    sourceUrl: 'https://www.10adventures.com/ski-touring-acc-5040-hut/',
  ),
  const SkiRoute(
    id: 'mount-myra-southwest-ridge',
    name: 'Mount Myra Southwest Ridge',
    area: 'Buttle Lake',
    region: 'Strathcona',
    location: LatLng(49.544167, -125.606389),
    trailhead: LatLng(49.5680, -125.5830),
    distanceKm: 16.0,
    elevationGainMeters: 1450,
    difficulty: 'Expert',
    aspect: 'Southwest',
    avalancheTerrain: 'Complex',
    season: 'Winter through spring',
    description:
        'A remote, high-commitment Island objective approached from the Myra Falls mine side.',
    approachNotes:
        'The published trip report approaches Tennant Lake before a steep couloir gains the southwest ridge.',
    descentNotes:
        'No default descent is implied; use a verified line selected for current snow and access conditions.',
    dangerInfo:
        '45-degree-plus terrain, cliff bands, complex avalanche exposure, industrial access, and remote rescue.',
    imageUrl: 'https://images.unsplash.com/photo-1549880338-65ddcdfd017b',
    sourceUrl: 'https://thecollectivemags.ca/van-isle-ski-touring/',
  ),
  const SkiRoute(
    id: 'mount-arrowsmith-alpine',
    name: 'Mount Arrowsmith Alpine',
    area: 'Arrowsmith Massif',
    region: 'Central Vancouver Island',
    location: LatLng(49.223611, -124.594444),
    trailhead: LatLng(49.2370, -124.6020),
    distanceKm: 10.0,
    elevationGainMeters: 850,
    difficulty: 'Advanced',
    aspect: 'North and East',
    avalancheTerrain: 'Complex',
    season: 'Winter through spring',
    description:
        'A rugged alpine tour on Vancouver Island’s prominent Arrowsmith massif.',
    approachNotes:
        'Access is via logging roads and the old ski-area side; confirm gates and road conditions before leaving.',
    descentNotes:
        'Published reports show several possibilities, but no unverified line is presented as a navigation track.',
    dangerInfo:
        'Avalanche terrain, cliff bands, rapidly changing visibility, variable road access, and no facilities.',
    imageUrl: 'https://images.unsplash.com/photo-1501706362039-c6e809e1b733',
    sourceUrl: 'https://citizenclass.ca/ski-touring-mount-arrowsmith/',
  ),
];
