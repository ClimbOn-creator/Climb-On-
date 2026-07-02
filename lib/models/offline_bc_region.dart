import 'package:latlong2/latlong.dart';

import 'geo_bounds.dart';

class OfflineBcRegion {
  const OfflineBcRegion({
    required this.id,
    required this.name,
    required this.description,
    required this.bounds,
    required this.center,
    required this.polygons,
    required this.colorValue,
  });

  final String id;
  final String name;
  final String description;
  final GeoBounds bounds;
  final LatLng center;
  final List<List<LatLng>> polygons;
  final int colorValue;

  bool get isComingSoon => id == 'alberta-rockies-coming-soon';

  OfflineBcRegion copyWith({List<List<LatLng>>? polygons}) {
    return OfflineBcRegion(
      id: id,
      name: name,
      description: description,
      bounds: bounds,
      center: center,
      polygons: polygons ?? this.polygons,
      colorValue: colorValue,
    );
  }

  bool contains(LatLng point) {
    return polygons.any((polygon) => _containsPoint(polygon, point));
  }

  List<GeoBounds> downloadBounds({int bandsPerPolygon = 16}) {
    final result = <GeoBounds>[];
    for (final polygon in polygons) {
      if (polygon.length < 3) continue;
      final latitudes = polygon.map((point) => point.latitude);
      final south = latitudes.reduce((a, b) => a < b ? a : b);
      final north = latitudes.reduce((a, b) => a > b ? a : b);
      final height = north - south;
      if (height <= 0) continue;

      for (var band = 0; band < bandsPerPolygon; band++) {
        final bandSouth = south + height * band / bandsPerPolygon;
        final bandNorth = south + height * (band + 1) / bandsPerPolygon;
        final latitude = (bandSouth + bandNorth) / 2;
        final intersections = <double>[];
        for (var index = 0; index < polygon.length; index++) {
          final first = polygon[index];
          final second = polygon[(index + 1) % polygon.length];
          final crosses =
              (first.latitude <= latitude && second.latitude > latitude) ||
              (second.latitude <= latitude && first.latitude > latitude);
          if (!crosses) continue;
          final fraction =
              (latitude - first.latitude) / (second.latitude - first.latitude);
          intersections.add(
            first.longitude + fraction * (second.longitude - first.longitude),
          );
        }
        intersections.sort();
        for (var index = 0; index + 1 < intersections.length; index += 2) {
          result.add(
            GeoBounds(
              south: bandSouth,
              west: intersections[index],
              north: bandNorth,
              east: intersections[index + 1],
            ),
          );
        }
      }
    }
    return result.isEmpty ? [bounds] : result;
  }

  static bool _containsPoint(List<LatLng> polygon, LatLng point) {
    var inside = false;
    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final a = polygon[i];
      final b = polygon[j];
      final crosses =
          (a.latitude > point.latitude) != (b.latitude > point.latitude) &&
          point.longitude <
              (b.longitude - a.longitude) *
                      (point.latitude - a.latitude) /
                      (b.latitude - a.latitude) +
                  a.longitude;
      if (crosses) inside = !inside;
    }
    return inside;
  }
}

const bcMapBounds = GeoBounds(
  south: 48.20,
  west: -139.10,
  north: 60.05,
  east: -109.80,
);

const offlineBcRegions = <OfflineBcRegion>[
  OfflineBcRegion(
    id: 'the-coast',
    name: 'The Coast',
    description:
        'Vancouver Island, the Gulf Islands, and the adjoining central coast.',
    bounds: GeoBounds(south: 48.20, west: -128.90, north: 51.10, east: -123.05),
    center: LatLng(49.55, -125.55),
    colorValue: 0xFF337EAA,
    polygons: [
      [
        LatLng(50.90, -128.55),
        LatLng(50.62, -127.05),
        LatLng(50.05, -126.00),
        LatLng(49.30, -124.85),
        LatLng(48.65, -123.10),
        LatLng(48.25, -123.25),
        LatLng(48.20, -124.05),
        LatLng(48.72, -125.55),
        LatLng(49.55, -127.05),
        LatLng(50.35, -128.55),
      ],
    ],
  ),
  OfflineBcRegion(
    id: 'vancouver-coast-mountains',
    name: 'Mainland and Sunshine Coast',
    description: 'Vancouver, the Fraser Valley, Sea to Sky, and south coast.',
    bounds: GeoBounds(south: 48.80, west: -128.50, north: 52.10, east: -121.00),
    center: LatLng(50.15, -123.40),
    colorValue: 0xFF138A92,
    polygons: [
      [
        LatLng(49.00, -123.35),
        LatLng(49.00, -121.55),
        LatLng(50.45, -121.45),
        LatLng(50.35, -123.00),
        LatLng(50.85, -125.00),
        LatLng(52.00, -128.00),
        LatLng(51.00, -127.00),
        LatLng(50.05, -125.10),
        LatLng(49.35, -124.15),
      ],
    ],
  ),
  OfflineBcRegion(
    id: 'thompson-okanagan',
    name: 'Thompson Okanagan',
    description: 'Kamloops, the Thompson valleys, Okanagan, and Shuswap.',
    bounds: GeoBounds(south: 48.80, west: -122.00, north: 53.20, east: -117.00),
    center: LatLng(50.45, -119.60),
    colorValue: 0xFF2F8292,
    polygons: [
      [
        LatLng(49.00, -121.55),
        LatLng(49.00, -118.70),
        LatLng(50.45, -118.00),
        LatLng(51.45, -118.30),
        LatLng(52.00, -118.20),
        LatLng(51.50, -119.00),
        LatLng(51.00, -120.00),
        LatLng(50.45, -121.45),
      ],
    ],
  ),
  OfflineBcRegion(
    id: 'bc-rockies',
    name: 'Rockies',
    description: 'The Kootenays, Columbia Mountains, and Canadian Rockies.',
    bounds: GeoBounds(south: 48.80, west: -119.00, north: 54.30, east: -113.80),
    center: LatLng(50.55, -116.20),
    colorValue: 0xFFAF83A9,
    polygons: [
      [
        LatLng(49.00, -118.70),
        LatLng(49.00, -114.00),
        LatLng(50.20, -114.55),
        LatLng(51.70, -116.00),
        LatLng(53.15, -117.00),
        LatLng(52.00, -118.20),
        LatLng(51.45, -118.30),
        LatLng(50.45, -118.00),
      ],
    ],
  ),
  OfflineBcRegion(
    id: 'cariboo-chilcotin-coast',
    name: 'Cariboo, Chilcotin Coast',
    description: 'The central coast, Chilcotin, Cariboo, and Fraser interior.',
    bounds: GeoBounds(south: 50.00, west: -131.00, north: 54.70, east: -116.50),
    center: LatLng(52.10, -122.90),
    colorValue: 0xFFD3BD79,
    polygons: [
      [
        LatLng(52.00, -128.00),
        LatLng(50.85, -125.00),
        LatLng(50.35, -123.00),
        LatLng(50.45, -121.45),
        LatLng(51.00, -120.00),
        LatLng(51.50, -119.00),
        LatLng(52.00, -118.20),
        LatLng(53.15, -117.00),
        LatLng(52.55, -120.20),
        LatLng(52.25, -122.20),
        LatLng(52.70, -126.00),
        LatLng(54.00, -130.50),
      ],
    ],
  ),
  OfflineBcRegion(
    id: 'northern-bc',
    name: 'Northern BC',
    description:
        'Haida Gwaii, the north coast, Cassiar, Peace, and north Rockies.',
    bounds: GeoBounds(south: 52.00, west: -139.10, north: 60.05, east: -113.80),
    center: LatLng(56.15, -126.25),
    colorValue: 0xFFB6003D,
    polygons: [
      [
        LatLng(60.00, -139.10),
        LatLng(60.00, -120.00),
        LatLng(56.90, -120.00),
        LatLng(54.70, -120.00),
        LatLng(54.20, -116.50),
        LatLng(53.15, -117.00),
        LatLng(52.55, -120.20),
        LatLng(52.25, -122.20),
        LatLng(52.70, -126.00),
        LatLng(54.00, -130.50),
        LatLng(56.00, -134.00),
        LatLng(58.10, -136.60),
      ],
      [
        LatLng(54.20, -133.20),
        LatLng(52.80, -131.60),
        LatLng(52.00, -131.90),
        LatLng(52.50, -133.30),
        LatLng(53.50, -133.90),
      ],
    ],
  ),
  OfflineBcRegion(
    id: 'alberta-rockies-coming-soon',
    name: 'Coming soon!',
    description: 'The Alberta side of the Canadian Rockies is coming soon.',
    bounds: GeoBounds(south: 48.90, west: -118.10, north: 52.60, east: -109.80),
    center: LatLng(50.85, -113.20),
    colorValue: 0xFF80868B,
    polygons: [
      [
        LatLng(49.00, -114.05),
        LatLng(50.00, -114.70),
        LatLng(51.00, -115.70),
        LatLng(52.50, -117.99),
        LatLng(52.50, -109.80),
        LatLng(49.00, -109.80),
      ],
    ],
  ),
];
