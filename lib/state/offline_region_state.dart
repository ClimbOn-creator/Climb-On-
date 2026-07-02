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
  final saved = await savedFuture;
  final official = await officialFuture;
  return [
    for (final region in offlineBcRegions)
      region.copyWith(
        polygons: saved[region.id] ?? official[region.id] ?? region.polygons,
      ),
  ];
});

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
    LatLng(border.last.latitude, -109.80),
    const LatLng(49.00, -109.80),
    const LatLng(49.00, -114.05),
  ];
}

double _averageLongitude(List<LatLng> points) {
  return points.fold<double>(0, (sum, point) => sum + point.longitude) /
      points.length;
}
