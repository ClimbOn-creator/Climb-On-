import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/map_path_catalog.dart';
import '../services/database_service.dart';

final mapPathCatalogProvider = FutureProvider<MapPathCatalog>((ref) {
  return const DatabaseService().loadMapPaths();
});
