import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../models/offline_bc_region.dart';
import '../services/database_service.dart';

final offlineRegionCatalogProvider = FutureProvider<List<OfflineBcRegion>>((
  ref,
) async {
  final savedFuture = const DatabaseService().loadOfflineRegionPolygons();
  final officialFuture = _loadOfficialTourismRegions();
  final coastlineFuture = _loadDetailedCoastlineRegions();
  final saved = await savedFuture;
  final official = await officialFuture;
  final coastline = await coastlineFuture;
  return [
    for (final region in offlineBcRegions) ...[
      if (region.id == 'the-coast')
        region.copyWith(
          polygons:
              saved[region.id] ??
              _withSavedVancouverIsland(
                coastline[region.id],
                saved['the-islands'],
              ) ??
              official[region.id] ??
              region.polygons,
          downloadPolygons:
              saved[region.id] ?? official[region.id] ?? region.polygons,
        )
      else
        region.copyWith(
          polygons:
              saved[region.id] ??
              coastline[region.id] ??
              official[region.id] ??
              region.polygons,
          downloadPolygons:
              saved[region.id] ?? official[region.id] ?? region.polygons,
        ),
    ],
  ];
});

List<List<LatLng>>? _withSavedVancouverIsland(
  List<List<LatLng>>? coastline,
  List<List<LatLng>>? savedIsland,
) {
  if (coastline == null || savedIsland == null || savedIsland.isEmpty) {
    return coastline;
  }
  return [
    for (final polygon in coastline)
      if (_isVancouverIsland(polygon)) ...savedIsland else polygon,
  ];
}

bool _isVancouverIsland(List<LatLng> polygon) {
  if (polygon.isEmpty) return false;
  final south = polygon
      .map((point) => point.latitude)
      .reduce((a, b) => a < b ? a : b);
  final north = polygon
      .map((point) => point.latitude)
      .reduce((a, b) => a > b ? a : b);
  final west = polygon
      .map((point) => point.longitude)
      .reduce((a, b) => a < b ? a : b);
  final east = polygon
      .map((point) => point.longitude)
      .reduce((a, b) => a > b ? a : b);
  return south < 48.5 && north > 50.7 && west < -128 && east > -123.5;
}

const _officialRegionIds = <String, String>{
  'A': 'the-coast',
  'B': 'vancouver-coast-mountains',
  'C': 'thompson-okanagan',
  'D': 'bc-rockies',
  'E': 'cariboo-chilcotin-coast',
  'F': 'northern-bc',
};

Future<Map<String, List<List<LatLng>>>> _loadOfficialTourismRegions() async {
  try {
    final source = await rootBundle.loadString(
      'assets/data/bc_tourism_regions.geojson',
    );
    return parseOfficialTourismRegions(source);
  } catch (_) {
    return const {};
  }
}

Future<Map<String, List<List<LatLng>>>> _loadDetailedCoastlineRegions() async {
  try {
    final source = await rootBundle.loadString(
      'assets/data/bc_coastline_regions.geojson',
    );
    return parseDetailedCoastlineRegions(source);
  } catch (_) {
    return const {};
  }
}

Map<String, List<List<LatLng>>> parseDetailedCoastlineRegions(String source) {
  final collection = jsonDecode(source) as Map<String, dynamic>;
  final result = <String, List<List<LatLng>>>{};
  for (final value in collection['features'] as List<dynamic>) {
    final feature = value as Map<String, dynamic>;
    final properties = feature['properties'] as Map<String, dynamic>;
    final regionId = properties['region_id'] as String?;
    if (regionId == null || regionId.isEmpty) continue;
    final geometry = feature['geometry'] as Map<String, dynamic>;
    final coordinates = geometry['coordinates'] as List<dynamic>;
    final polygonValues = geometry['type'] == 'MultiPolygon'
        ? coordinates
        : <dynamic>[coordinates];
    result[regionId] = [
      for (final polygonValue in polygonValues)
        _ringToPoints((polygonValue as List<dynamic>).first as List<dynamic>),
    ];
  }
  return result;
}

List<LatLng> _ringToPoints(List<dynamic> ring) {
  return [
    for (final value in ring)
      LatLng(
        ((value as List<dynamic>)[1] as num).toDouble(),
        (value[0] as num).toDouble(),
      ),
  ];
}

Map<String, List<List<LatLng>>> parseOfficialTourismRegions(String source) {
  final collection = jsonDecode(source) as Map<String, dynamic>;
  final result = <String, List<List<LatLng>>>{};
  for (final value in collection['features'] as List<dynamic>) {
    final feature = value as Map<String, dynamic>;
    final properties = feature['properties'] as Map<String, dynamic>;
    final regionId = _officialRegionIds[properties['TOURISM_REGION_ID']];
    if (regionId == null) continue;
    final geometry = feature['geometry'] as Map<String, dynamic>;
    final coordinates = geometry['coordinates'] as List<dynamic>;
    final polygonValues = geometry['type'] == 'MultiPolygon'
        ? coordinates
        : <dynamic>[coordinates];
    result[regionId] = [
      for (final polygonValue in polygonValues)
        for (final ringValue in polygonValue as List<dynamic>)
          [
            for (final value in ringValue as List<dynamic>)
              LatLng(
                ((value as List<dynamic>)[1] as num).toDouble(),
                (value[0] as num).toDouble(),
              ),
          ],
    ];
  }
  final rockies = result['bc-rockies']?.firstOrNull;
  if (rockies != null) {
    result['alberta-rockies-coming-soon'] = [_albertaSideOfRockies(rockies)];
  }
  return result;
}

List<LatLng> _albertaSideOfRockies(List<LatLng> rockies) {
  var eastIndex = 0;
  var northIndex = 0;
  for (var index = 1; index < rockies.length; index++) {
    if (rockies[index].longitude > rockies[eastIndex].longitude) {
      eastIndex = index;
    }
    if (rockies[index].latitude > rockies[northIndex].latitude) {
      northIndex = index;
    }
  }

  List<LatLng> path(int step) {
    final result = <LatLng>[];
    var index = eastIndex;
    while (true) {
      result.add(rockies[index]);
      if (index == northIndex) return result;
      index = (index + step) % rockies.length;
      if (index < 0) index += rockies.length;
    }
  }

  final first = path(1);
  final second = path(-1);
  final border = _averageLongitude(first) > _averageLongitude(second)
      ? first
      : second;
  return [
    ...border,
    const LatLng(53.25, -118.90),
    const LatLng(54.25, -119.75),
    const LatLng(55.00, -120.00),
    const LatLng(55.00, -113.75),
    const LatLng(49.00, -113.75),
    const LatLng(49.00, -114.05),
  ];
}

double _averageLongitude(List<LatLng> points) {
  return points.fold<double>(0, (sum, point) => sum + point.longitude) /
      points.length;
}
