import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/sample_ski_routes.dart' as sample_data;
import '../models/ski_route.dart';
import '../services/database_service.dart';
import '../utils/vancouver_island.dart';

final skiRouteCatalogProvider = FutureProvider<List<SkiRoute>>((ref) async {
  final cloudRoutes = await const DatabaseService().loadSkiRoutes();
  final islandRoutes = cloudRoutes
      .where((route) => isOnVancouverIsland(route.location))
      .toList(growable: false);
  return islandRoutes.isEmpty ? sample_data.skiRoutes : islandRoutes;
});
