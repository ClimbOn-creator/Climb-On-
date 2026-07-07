import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../models/user_profile.dart';
import 'object_storage_service.dart';

class ProfileService {
  const ProfileService();

  static const _storage = ObjectStorageService();

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
    required String avatarUrl,
    required String homeArea,
    required String bio,
    required bool isPublic,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw const AuthException('Sign in before saving your profile.');
    }

    final metadataName = user.userMetadata?['full_name']?.toString() ?? '';
    final googleAvatarUrl = user.userMetadata?['avatar_url']?.toString();
    final savedAvatarUrl = avatarUrl.trim().isEmpty
        ? googleAvatarUrl
        : avatarUrl.trim();

    await _client.from('profiles').upsert({
      'id': user.id,
      'display_name': displayName.trim().isEmpty
          ? metadataName
          : displayName.trim(),
      'username': _cleanUsername(username),
      'avatar_url': savedAvatarUrl,
      'home_area': homeArea.trim(),
      'bio': bio.trim(),
      'is_public': isPublic,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'id');
  }

  Future<bool> isUsernameAvailable(String username) async {
    final user = currentUser;
    if (user == null) return false;
    final result = await _client.rpc(
      'username_available',
      params: {'candidate': _cleanUsername(username)},
    );
    return result == true;
  }

  Future<String> uploadAvatar({
    required Uint8List bytes,
    required String extension,
    required String contentType,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw const AuthException('Sign in before changing your photo.');
    }

    final cleanExtension = extension.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
    final fileName =
        'avatar.${cleanExtension.isEmpty ? 'jpg' : cleanExtension}';
    final path = '${user.id}/$fileName';
    final uploaded = await _storage.upload(
      area: ObjectStorageArea.profileAvatars,
      path: path,
      bytes: bytes,
      contentType: contentType,
      upsert: true,
    );
    return Uri.parse(uploaded.url)
        .replace(
          queryParameters: {
            'v': DateTime.now().millisecondsSinceEpoch.toString(),
          },
        )
        .toString();
  }

  String _cleanUsername(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]+'), '_');
  }
}
