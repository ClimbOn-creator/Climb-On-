import 'package:latlong2/latlong.dart';

import 'geo_bounds.dart';

class OfflineBcRegion {
  const OfflineBcRegion({
    required this.id,
    required this.name,
    required this.description,
    required this.bounds,
    required this.center,
  });

  final String id;
  final String name;
  final String description;
  final GeoBounds bounds;
  final LatLng center;

  bool contains(LatLng point) {
    return point.latitude >= bounds.south &&
        point.latitude <= bounds.north &&
        point.longitude >= bounds.west &&
        point.longitude <= bounds.east;
  }
}

const bcMapBounds = GeoBounds(
  south: 48.20,
  west: -139.10,
  north: 60.05,
  east: -113.80,
);

const offlineBcRegions = <OfflineBcRegion>[
  OfflineBcRegion(
    id: 'vancouver-island',
    name: '1 · Vancouver Island',
    description:
        'Victoria, Island crags, Strathcona, Mount Cain, and west coast.',
    bounds: GeoBounds(south: 48.20, west: -128.90, north: 51.05, east: -123.05),
    center: LatLng(49.65, -125.55),
  ),
  OfflineBcRegion(
    id: 'vancouver-sea-to-sky',
    name: '2 · Vancouver & Sea to Sky',
    description: 'Metro Vancouver, Squamish, Whistler, and Pemberton.',
    bounds: GeoBounds(south: 48.80, west: -124.20, north: 50.65, east: -121.90),
    center: LatLng(49.75, -123.05),
  ),
  OfflineBcRegion(
    id: 'coast-chilcotin',
    name: '3 · Coast Mountains & Chilcotin',
    description:
        'Duffey, South Chilcotin, Bella Coola, and central Coast Range.',
    bounds: GeoBounds(south: 50.00, west: -128.80, north: 54.20, east: -121.00),
    center: LatLng(52.10, -124.85),
  ),
  OfflineBcRegion(
    id: 'thompson-okanagan',
    name: '4 · Thompson & Okanagan',
    description: 'Kamloops, Coquihalla, Okanagan, Monashees, and Revelstoke.',
    bounds: GeoBounds(south: 48.80, west: -122.20, north: 52.80, east: -117.50),
    center: LatLng(50.75, -119.80),
  ),
  OfflineBcRegion(
    id: 'kootenays',
    name: '5 · Kootenays',
    description: 'Selkirks, Purcells, Rockies, Nelson, Golden, and Fernie.',
    bounds: GeoBounds(south: 48.80, west: -118.60, north: 53.00, east: -113.80),
    center: LatLng(50.85, -116.40),
  ),
  OfflineBcRegion(
    id: 'northern-bc',
    name: '6 · Northern BC',
    description:
        'Cariboo north through the Skeena, Cassiar, and northern Rockies.',
    bounds: GeoBounds(south: 52.00, west: -139.10, north: 60.05, east: -113.80),
    center: LatLng(56.00, -126.50),
  ),
];
