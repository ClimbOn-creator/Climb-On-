import 'package:latlong2/latlong.dart';

import '../models/ski_route.dart';

final skiRoutes = [
  const SkiRoute(
    id: 'brohm-ridge-tour',
    name: 'Brohm Ridge Tour',
    area: 'Garibaldi',
    region: 'Sea to Sky',
    location: LatLng(49.9120, -123.1050),
    trailhead: LatLng(49.8755, -123.1330),
    distanceKm: 13.5,
    elevationGainMeters: 980,
    difficulty: 'Intermediate',
    aspect: 'Southwest',
    avalancheTerrain: 'Complex',
    season: 'Mid winter through spring',
    description:
        'A broad ridge tour with big views and several descent options when conditions line up.',
    approachNotes:
        'Start from the winter parking approach and follow the road grade toward the ridge.',
    descentNotes:
        'Descend the ascent route or choose supported slopes only after assessing avalanche conditions.',
    dangerInfo:
        'Avalanche exposure, cornices, changing visibility, and snowmobile traffic.',
    imageUrl: 'https://images.unsplash.com/photo-1517824806704-9040b037703b',
  ),
  const SkiRoute(
    id: 'paul-ridge-meadows',
    name: 'Paul Ridge Meadows',
    area: 'Garibaldi',
    region: 'Sea to Sky',
    location: LatLng(49.9650, -123.0710),
    trailhead: LatLng(49.9574, -123.1202),
    distanceKm: 16.0,
    elevationGainMeters: 1120,
    difficulty: 'Advanced',
    aspect: 'North',
    avalancheTerrain: 'Challenging',
    season: 'Winter through spring',
    description:
        'A classic long tour into rolling alpine terrain with excellent views and many terrain choices.',
    approachNotes:
        'Use the park trail approach and continue toward the open ridge system.',
    descentNotes:
        'Return by the approach or choose mellow glades when hazard allows.',
    dangerInfo:
        'Long day, avalanche terrain, whiteout navigation, and cold exposure.',
    imageUrl: 'https://images.unsplash.com/photo-1488590528505-98d2b5aba04b',
  ),
  const SkiRoute(
    id: 'mt-cain-glades',
    name: 'Mount Cain Backside Glades',
    area: 'Mount Cain',
    region: 'Vancouver Island',
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
    approachNotes: 'Start near the ski area boundary and respect all closures.',
    descentNotes:
        'Lap supported glades and return to the same approach corridor.',
    dangerInfo: 'Tree wells, storm slabs, and boundary/closure management.',
    imageUrl: 'https://images.unsplash.com/photo-1551524559-8af4e6624178',
  ),
  const SkiRoute(
    id: 'duffey-lake-scout',
    name: 'Duffey Lake Scout Tour',
    area: 'Duffey Lake',
    region: 'Coast Mountains',
    location: LatLng(50.3760, -122.5320),
    trailhead: LatLng(50.3710, -122.5160),
    distanceKm: 9.8,
    elevationGainMeters: 880,
    difficulty: 'Advanced',
    aspect: 'Northeast',
    avalancheTerrain: 'Complex',
    season: 'Winter through spring',
    description:
        'A committing Coast Mountains tour with rewarding turns and serious terrain management.',
    approachNotes: 'Begin from a plowed pullout and skin into the drainage.',
    descentNotes:
        'Use conservative terrain choices and preserve energy for the exit.',
    dangerInfo:
        'Avalanche terrain, overhead hazard, creek crossings, and remote rescue.',
    imageUrl: 'https://images.unsplash.com/photo-1501706362039-c6e809e1b733',
  ),
];
