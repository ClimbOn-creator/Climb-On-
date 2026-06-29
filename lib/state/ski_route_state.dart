import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/sample_ski_routes.dart' as sample_data;
import '../models/ski_route.dart';
import '../services/database_service.dart';

final skiRouteCatalogProvider = FutureProvider<List<SkiRoute>>((ref) async {
  final cloudRoutes = await const DatabaseService().loadSkiRoutes();
  return cloudRoutes.isEmpty ? sample_data.skiRoutes : cloudRoutes;
});
