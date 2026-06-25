import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

final isMapAdminProvider = FutureProvider<bool>((ref) async {
  if (!SupabaseConfig.isConfigured) return false;

  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) return false;

  try {
    final result = await client.rpc('is_app_admin');
    return result == true;
  } catch (_) {
    return false;
  }
});
