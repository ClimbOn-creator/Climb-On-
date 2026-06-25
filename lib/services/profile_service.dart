import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../models/user_profile.dart';

class ProfileService {
  const ProfileService();

  SupabaseClient get _client => Supabase.instance.client;

  User? get currentUser {
    if (!SupabaseConfig.isConfigured) return null;
    return _client.auth.currentUser;
  }

  Future<UserProfile?> loadCurrentProfile() async {
    final user = currentUser;
    if (user == null) return null;

    final rows = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .limit(1);

    if (rows.isEmpty) return null;
    return UserProfile.fromJson(Map<String, Object?>.from(rows.first));
  }

  Future<void> saveProfile({
    required String displayName,
    required String username,
    required String homeArea,
    required String climbingStyle,
    required String bio,
    required bool isPublic,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw const AuthException('Sign in before saving your profile.');
    }

    final metadataName = user.userMetadata?['full_name']?.toString() ?? '';
    final avatarUrl = user.userMetadata?['avatar_url']?.toString();

    await _client.from('profiles').upsert({
      'id': user.id,
      'display_name': displayName.trim().isEmpty
          ? metadataName
          : displayName.trim(),
      'username': _cleanUsername(username),
      'avatar_url': avatarUrl,
      'home_area': homeArea.trim(),
      'climbing_style': climbingStyle.trim(),
      'bio': bio.trim(),
      'is_public': isPublic,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'id');
  }

  String _cleanUsername(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]+'), '_');
  }
}
