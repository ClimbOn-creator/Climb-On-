import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

const climbOnOwnerUserId = '519cee87-e5fb-4374-a61b-5dd45d912c81';

final isOwnerAccountProvider = Provider<bool>((ref) {
  if (!SupabaseConfig.isConfigured) return false;
  return Supabase.instance.client.auth.currentUser?.id == climbOnOwnerUserId;
});

final isMapAdminProvider = FutureProvider.autoDispose<bool>((ref) async {
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
