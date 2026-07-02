import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_visuals.dart';
import '../services/database_service.dart';

final appVisualsProvider = FutureProvider<AppVisuals>((ref) async {
  return AppVisuals(await const DatabaseService().loadAppVisuals());
});
