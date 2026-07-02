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
  'A': 'the-islands',
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
  return result;
}
