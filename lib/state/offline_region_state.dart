import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/offline_bc_region.dart';
import '../services/database_service.dart';

final offlineRegionCatalogProvider = FutureProvider<List<OfflineBcRegion>>((
  ref,
) async {
  final saved = await const DatabaseService().loadOfflineRegionPolygons();
  return [
    for (final region in offlineBcRegions)
      region.copyWith(polygons: saved[region.id]),
  ];
});
