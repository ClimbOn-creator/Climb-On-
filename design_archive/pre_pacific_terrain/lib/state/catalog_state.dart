import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/climb_route.dart';
import '../models/crag.dart';
import '../services/database_service.dart';

final catalogProvider = FutureProvider<List<Crag>>((ref) {
  return const DatabaseService().loadCrags();
});

final allRoutesProvider = Provider<List<ClimbRoute>>((ref) {
  final catalog = ref.watch(catalogProvider).valueOrNull ?? const <Crag>[];
  return [
    for (final crag in catalog)
      for (final wall in crag.walls) ...wall.routes,
  ];
});
