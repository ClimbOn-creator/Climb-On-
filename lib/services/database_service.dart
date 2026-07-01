import 'dart:convert';
import 'dart:typed_data';

import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../data/sample_crags.dart' as sample_data;
import '../models/climb_route.dart';
import '../models/crag.dart';
import '../models/geo_bounds.dart';
import '../models/map_path_catalog.dart';
import '../models/ski_route.dart';
import '../models/social.dart';
import '../models/wall.dart';
import '../state/climb_log_state.dart';

class DatabaseService {
  const DatabaseService();

  static const _catalogCacheKey = 'climb_on_catalog_cache_v1';
  static const _skiCatalogCacheKey = 'climb_on_ski_catalog_cache_v1';
  static const _mapPathsCacheKey = 'climb_on_map_paths_cache_v1';
  static const _offlineRegionsCacheKey = 'climb_on_offline_regions_cache_v1';

  User? get _currentUser {
    if (!SupabaseConfig.isConfigured) return null;
    return Supabase.instance.client.auth.currentUser;
  }

  String? get currentUserId => _currentUser?.id;
  bool get isConfigured => SupabaseConfig.isConfigured;

  bool get isCloudReady {
    return _currentUser != null;
  }

  Future<List<Crag>> loadCrags() async {
    if (SupabaseConfig.isConfigured) {
      try {
        final result = await Supabase.instance.client.rpc('climb_catalog');
        final crags = _parseCatalog(result);
        if (crags.isNotEmpty) {
          await _cacheCatalog(result);
          return crags;
        }
      } catch (_) {
        // Fall back to cached or sample data when the cloud is unavailable.
      }
    }

    final cached = await _loadCachedCatalog();
    if (cached.isNotEmpty) return cached;

    return sample_data.crags;
  }

  Future<List<Crag>> loadCragsInBounds(GeoBounds bounds) async {
    final crags = await loadCrags();
    return crags.where((crag) {
      final lat = crag.location.latitude;
      final lng = crag.location.longitude;
      return lat >= bounds.south &&
          lat <= bounds.north &&
          lng >= bounds.west &&
          lng <= bounds.east;
    }).toList();
  }

  Future<List<ClimbRoute>> searchRoutes({
    required String query,
    String? grade,
    String? routeType,
    String? pitchType,
    GeoBounds? bounds,
  }) async {
    final crags = await loadCrags();
    final routes = [
      for (final crag in crags)
        for (final wall in crag.walls) ...wall.routes,
    ];

    final needle = query.trim().toLowerCase();
    return routes.where((route) {
      final matchesQuery =
          needle.isEmpty ||
          route.name.toLowerCase().contains(needle) ||
          route.grade.toLowerCase().contains(needle) ||
          route.typeLabel.toLowerCase().contains(needle);
      final matchesGrade = grade == null || route.grade == grade;
      final matchesRouteType =
          routeType == null ||
          route.typeLabel.toLowerCase() == routeType.toLowerCase();
      final matchesPitchType =
          pitchType == null ||
          route.pitchLabel.toLowerCase() == pitchType.toLowerCase();
      final matchesBounds =
          bounds == null ||
          (route.location != null &&
              route.location!.latitude >= bounds.south &&
              route.location!.latitude <= bounds.north &&
              route.location!.longitude >= bounds.west &&
              route.location!.longitude <= bounds.east);
      return matchesQuery &&
          matchesGrade &&
          matchesRouteType &&
          matchesPitchType &&
          matchesBounds;
    }).toList();
  }

  Future<void> saveCompletedRoute(Send send) async {
    final user = _currentUser;
    if (user == null) return;

    await Supabase.instance.client.from('user_sends').upsert({
      'user_id': user.id,
      'route_id': send.routeId,
      'style': send.style,
      'sent_at': send.sentAt.toIso8601String(),
    }, onConflict: 'user_id,route_id');
  }

  Future<void> deleteCompletedRoute(String routeId) async {
    final user = _currentUser;
    if (user == null) return;

    await Supabase.instance.client
        .from('user_sends')
        .delete()
        .eq('user_id', user.id)
        .eq('route_id', routeId);
  }

  Future<void> saveAttempt(Attempt attempt) async {
    final user = _currentUser;
    if (user == null) return;

    await Supabase.instance.client.from('route_attempts').insert({
      'user_id': user.id,
      'route_id': attempt.routeId,
      'note': attempt.note,
      'attempted_at': attempt.attemptedAt.toIso8601String(),
    });
  }

  Future<void> saveGradeOpinion(GradeOpinion opinion) async {
    final user = _currentUser;
    if (user == null) return;

    await Supabase.instance.client.from('route_grade_opinions').upsert({
      'user_id': user.id,
      'route_id': opinion.routeId,
      'suggested_grade': opinion.suggestedGrade,
      'created_at': opinion.createdAt.toIso8601String(),
    }, onConflict: 'user_id,route_id');
  }

  Future<LocalRouteComment> saveComment(String routeId, String body) async {
    final user = _currentUser;
    if (user == null) {
      throw const AuthException('Sign in before commenting.');
    }

    final row = await Supabase.instance.client
        .from('route_comments')
        .insert({'user_id': user.id, 'route_id': routeId, 'body': body})
        .select()
        .single();
    final profiles = await _loadProfiles({user.id});
    final comment = LocalRouteComment.fromCloudJson(row, profiles[user.id]);
    if (comment == null) throw StateError('The saved comment was invalid.');
    return comment;
  }

  Future<List<LocalRouteComment>> loadComments(String routeId) async {
    if (!SupabaseConfig.isConfigured) return const [];

    final result = await Supabase.instance.client.rpc(
      'route_comments_with_authors',
      params: {'target_route_id': routeId},
    );
    final rows = result is List ? result.whereType<Map>().toList() : const [];
    return rows
        .map(
          (row) =>
              LocalRouteComment.fromCloudJson(Map<String, dynamic>.from(row), {
                'username': row['author_username'],
                'display_name': row['author_display_name'],
                'avatar_url': row['author_avatar_url'],
                'bio': row['author_bio'],
                'home_area': row['author_home_area'],
              }),
        )
        .whereType<LocalRouteComment>()
        .toList(growable: false);
  }

  Future<Map<String, Map<String, dynamic>>> _loadProfiles(
    Set<String> userIds,
  ) async {
    if (userIds.isEmpty) return const {};
    final rows = await Supabase.instance.client
        .from('profiles')
        .select('id, username, display_name, avatar_url, bio, home_area')
        .inFilter('id', userIds.toList());
    return {for (final row in rows) row['id'].toString(): row};
  }

  Future<void> savePhoto(LocalRoutePhoto photo) async {
    final user = _currentUser;
    if (user == null) return;

    await Supabase.instance.client.from('route_photos').insert({
      'user_id': user.id,
      'route_id': photo.routeId,
      'url': photo.url,
      'caption': photo.caption,
      'created_at': photo.createdAt.toIso8601String(),
    });
  }

  Future<List<LocalRoutePhoto>> loadPhotos(String routeId) async {
    if (!SupabaseConfig.isConfigured) return const [];

    final rows = await Supabase.instance.client
        .from('route_photos')
        .select()
        .eq('route_id', routeId)
        .order('created_at', ascending: false);
    return rows
        .map(LocalRoutePhoto.fromCloudJson)
        .whereType<LocalRoutePhoto>()
        .toList(growable: false);
  }

  Future<LocalRoutePhoto> uploadPhoto({
    required String routeId,
    required List<int> bytes,
    required String fileName,
    required String contentType,
    required String caption,
  }) async {
    final user = _currentUser;
    if (user == null) {
      throw const AuthException('Sign in before adding a route picture.');
    }

    final extension = fileName.contains('.')
        ? fileName
              .split('.')
              .last
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-z0-9]'), '')
        : 'jpg';
    final safeExtension = extension.isEmpty ? 'jpg' : extension;
    final storagePath =
        '${user.id}/$routeId/${DateTime.now().microsecondsSinceEpoch}.$safeExtension';
    final storage = Supabase.instance.client.storage.from('route-photos');

    await storage.uploadBinary(
      storagePath,
      Uint8List.fromList(bytes),
      fileOptions: FileOptions(contentType: contentType, upsert: false),
    );

    try {
      final url = storage.getPublicUrl(storagePath);
      final row = await Supabase.instance.client
          .from('route_photos')
          .insert({
            'user_id': user.id,
            'route_id': routeId,
            'url': url,
            'storage_path': storagePath,
            'caption': caption,
          })
          .select()
          .single();
      final photo = LocalRoutePhoto.fromCloudJson(row);
      if (photo == null) throw StateError('The uploaded picture was invalid.');
      return photo;
    } catch (_) {
      await storage.remove([storagePath]);
      rethrow;
    }
  }

  Future<void> deletePhoto(LocalRoutePhoto photo) async {
    final user = _currentUser;
    if (user == null || user.id != photo.userId) {
      throw const AuthException(
        'Only the person who added this picture can remove it.',
      );
    }

    if (photo.storagePath.isNotEmpty) {
      await Supabase.instance.client.storage.from('route-photos').remove([
        photo.storagePath,
      ]);
    }
    await Supabase.instance.client
        .from('route_photos')
        .delete()
        .eq('id', photo.id)
        .eq('user_id', user.id);
  }

  Future<void> setProject(String routeId, bool saved) async {
    final user = _currentUser;
    if (user == null) return;

    final table = Supabase.instance.client.from('user_projects');
    if (saved) {
      await table.upsert({
        'user_id': user.id,
        'route_id': routeId,
      }, onConflict: 'user_id,route_id');
    } else {
      await table.delete().eq('user_id', user.id).eq('route_id', routeId);
    }
  }

  Future<List<FriendProfile>> loadFriends() async {
    if (_currentUser == null) return const [];
    final result = await Supabase.instance.client.rpc('my_friends');
    return _maps(result)
        .map(FriendProfile.fromJson)
        .where((profile) => profile.id.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<FriendProfile>> searchClimbers(String query) async {
    if (_currentUser == null || query.trim().isEmpty) return const [];
    final result = await Supabase.instance.client.rpc(
      'search_climbers',
      params: {'search_text': query.trim()},
    );
    return _maps(result)
        .map(FriendProfile.fromJson)
        .where((profile) => profile.id.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> addFriend(String friendId) async {
    final user = _currentUser;
    if (user == null) throw const AuthException('Sign in to add friends.');
    await Supabase.instance.client.from('user_friends').upsert({
      'user_id': user.id,
      'friend_id': friendId,
    });
  }

  Future<void> removeFriend(String friendId) async {
    final user = _currentUser;
    if (user == null) return;
    await Supabase.instance.client
        .from('user_friends')
        .delete()
        .eq('user_id', user.id)
        .eq('friend_id', friendId);
  }

  Future<List<FriendSendActivity>> loadFriendSends() async {
    if (_currentUser == null) return const [];
    final result = await Supabase.instance.client.rpc('friend_send_feed');
    return _maps(result)
        .map(FriendSendActivity.fromJson)
        .where((activity) => activity.routeId.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<UserRouteComment>> loadMyRecentComments() async {
    if (_currentUser == null) return const [];
    final result = await Supabase.instance.client.rpc('my_recent_comments');
    return _maps(result)
        .map(UserRouteComment.fromJson)
        .where((comment) => comment.id.isNotEmpty)
        .toList(growable: false);
  }

  List<Map<String, dynamic>> _maps(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  Future<void> submitRoute(
    Map<String, Object?> submission, {
    required List<int> photoBytes,
    required String photoName,
    required String photoContentType,
  }) async {
    await _submitWithPhoto(
      table: 'route_submissions',
      imageColumn: 'photo_url',
      submission: submission,
      photoBytes: photoBytes,
      photoName: photoName,
      photoContentType: photoContentType,
    );
  }

  Future<void> submitRouteWithPhotos(
    Map<String, Object?> submission, {
    required List<UploadPhotoPayload> photos,
  }) async {
    await _submitWithPhotos(
      table: 'route_submissions',
      imageColumn: 'photo_url',
      submission: submission,
      photos: photos,
    );
  }

  Future<void> submitSkiRoute(
    Map<String, Object?> submission, {
    required List<int> photoBytes,
    required String photoName,
    required String photoContentType,
  }) async {
    await _submitWithPhoto(
      table: 'ski_route_submissions',
      imageColumn: 'image_url',
      submission: submission,
      photoBytes: photoBytes,
      photoName: photoName,
      photoContentType: photoContentType,
    );
  }

  Future<void> submitSkiRouteWithPhotos(
    Map<String, Object?> submission, {
    required List<UploadPhotoPayload> photos,
  }) async {
    await _submitWithPhotos(
      table: 'ski_route_submissions',
      imageColumn: 'image_url',
      submission: submission,
      photos: photos,
    );
  }

  Future<void> _submitWithPhoto({
    required String table,
    required String imageColumn,
    required Map<String, Object?> submission,
    required List<int> photoBytes,
    required String photoName,
    required String photoContentType,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      throw StateError('Supabase is not configured.');
    }
    final user = _currentUser;
    if (user == null) {
      throw const AuthException('Sign in before submitting a route.');
    }

    final extension = photoName.contains('.')
        ? photoName
              .split('.')
              .last
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-z0-9]'), '')
        : 'jpg';
    final storagePath =
        '${user.id}/${DateTime.now().microsecondsSinceEpoch}.${extension.isEmpty ? 'jpg' : extension}';
    final storage = Supabase.instance.client.storage.from('submission-photos');
    await storage.uploadBinary(
      storagePath,
      Uint8List.fromList(photoBytes),
      fileOptions: FileOptions(contentType: photoContentType, upsert: false),
    );

    try {
      await Supabase.instance.client.from(table).insert({
        ...submission,
        'user_id': user.id,
        imageColumn: storage.getPublicUrl(storagePath),
      });
    } catch (_) {
      await storage.remove([storagePath]);
      rethrow;
    }
  }

  Future<void> _submitWithPhotos({
    required String table,
    required String imageColumn,
    required Map<String, Object?> submission,
    required List<UploadPhotoPayload> photos,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      throw StateError('Supabase is not configured.');
    }
    if (photos.isEmpty) {
      throw StateError('Add at least one picture.');
    }
    final user = _currentUser;
    if (user == null) {
      throw const AuthException('Sign in before submitting a route.');
    }

    final storage = Supabase.instance.client.storage.from('submission-photos');
    final uploadedPaths = <String>[];
    final urls = <String>[];

    try {
      for (var index = 0; index < photos.length; index++) {
        final photo = photos[index];
        final extension = _safeFileExtension(photo.fileName);
        final storagePath =
            '${user.id}/${DateTime.now().microsecondsSinceEpoch}_$index.$extension';
        await storage.uploadBinary(
          storagePath,
          Uint8List.fromList(photo.bytes),
          fileOptions: FileOptions(
            contentType: photo.contentType,
            upsert: false,
          ),
        );
        uploadedPaths.add(storagePath);
        urls.add(storage.getPublicUrl(storagePath));
      }

      await Supabase.instance.client.from(table).insert({
        ...submission,
        'user_id': user.id,
        imageColumn: urls.first,
        'photo_urls': urls,
      });
    } catch (_) {
      if (uploadedPaths.isNotEmpty) await storage.remove(uploadedPaths);
      rethrow;
    }
  }

  Future<void> updateCragLocation({
    required String cragId,
    required double latitude,
    required double longitude,
  }) async {
    await _adminCoordinateUpdate('admin_update_crag_location', {
      'crag_id': cragId,
      'lat': latitude,
      'lng': longitude,
    });
  }

  Future<void> updateCragParkingLocation({
    required String cragId,
    required double latitude,
    required double longitude,
  }) async {
    await _adminCoordinateUpdate('admin_update_crag_parking_location', {
      'crag_id': cragId,
      'lat': latitude,
      'lng': longitude,
    });
  }

  Future<void> updateCreatorCragWarning({
    required String cragId,
    required String warning,
  }) async {
    await _creatorUpdate('creator_update_crag_warning', {
      'target_crag_id': cragId,
      'new_warning': warning.trim(),
    });
  }

  Future<void> updateCreatorRouteWarning({
    required String routeId,
    required String warning,
  }) async {
    await _creatorUpdate('creator_update_route_warning', {
      'target_route_id': routeId,
      'new_warning': warning.trim(),
    });
  }

  Future<String> adminSaveCatalogRoute({
    String? routeId,
    required String wallId,
    required Map<String, Object?> values,
    List<int>? imageBytes,
    String imageName = '',
    String imageContentType = 'image/jpeg',
  }) async {
    final user = _currentUser;
    if (user == null) throw const AuthException('Sign in to edit routes.');

    String imageUrl = values['route_image_url']?.toString() ?? '';
    String? uploadedPath;
    if (imageBytes != null && imageBytes.isNotEmpty) {
      final extension = imageName.contains('.')
          ? imageName
                .split('.')
                .last
                .toLowerCase()
                .replaceAll(RegExp(r'[^a-z0-9]'), '')
          : 'jpg';
      uploadedPath =
          '${user.id}/catalog/${DateTime.now().microsecondsSinceEpoch}.${extension.isEmpty ? 'jpg' : extension}';
      final storage = Supabase.instance.client.storage.from(
        'submission-photos',
      );
      await storage.uploadBinary(
        uploadedPath,
        Uint8List.fromList(imageBytes),
        fileOptions: FileOptions(contentType: imageContentType, upsert: false),
      );
      imageUrl = storage.getPublicUrl(uploadedPath);
    }

    try {
      final result = await Supabase.instance.client.rpc(
        'admin_save_catalog_route',
        params: {
          'target_route_id': routeId,
          'target_wall_id': wallId,
          ...values,
          'route_image_url': imageUrl,
        },
      );
      return result?.toString() ?? '';
    } catch (_) {
      if (uploadedPath != null) {
        await Supabase.instance.client.storage.from('submission-photos').remove(
          [uploadedPath],
        );
      }
      rethrow;
    }
  }

  Future<String> adminResolveCatalogWall({
    String? cragId,
    String? wallId,
    required String cragName,
    required String wallName,
    required double latitude,
    required double longitude,
    required String cragWarning,
  }) async {
    final result = await Supabase.instance.client.rpc(
      'admin_resolve_catalog_wall',
      params: {
        'target_crag_id': cragId,
        'target_wall_id': wallId,
        'new_crag_name': cragName,
        'new_wall_name': wallName,
        'target_lat': latitude,
        'target_lng': longitude,
        'new_crag_warning': cragWarning,
      },
    );
    return result?.toString() ?? '';
  }

  Future<String> adminReplaceRouteImage({
    required String routeId,
    required List<int> imageBytes,
    required String imageName,
    required String imageContentType,
  }) async {
    return _adminReplaceCatalogImage(
      routeId: routeId,
      imageBytes: imageBytes,
      imageName: imageName,
      imageContentType: imageContentType,
      functionName: 'admin_update_route_image',
    );
  }

  Future<String> adminReplaceRouteTrailheadImage({
    required String routeId,
    required List<int> imageBytes,
    required String imageName,
    required String imageContentType,
  }) {
    return _adminReplaceCatalogImage(
      routeId: routeId,
      imageBytes: imageBytes,
      imageName: imageName,
      imageContentType: imageContentType,
      functionName: 'admin_update_route_trailhead_image',
    );
  }

  Future<String> _adminReplaceCatalogImage({
    required String routeId,
    required List<int> imageBytes,
    required String imageName,
    required String imageContentType,
    required String functionName,
  }) async {
    final user = _currentUser;
    if (user == null) throw const AuthException('Sign in to edit routes.');
    final extension = imageName.contains('.')
        ? imageName
              .split('.')
              .last
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-z0-9]'), '')
        : 'jpg';
    final path =
        '${user.id}/catalog/${DateTime.now().microsecondsSinceEpoch}.${extension.isEmpty ? 'jpg' : extension}';
    final storage = Supabase.instance.client.storage.from('submission-photos');
    await storage.uploadBinary(
      path,
      Uint8List.fromList(imageBytes),
      fileOptions: FileOptions(contentType: imageContentType, upsert: false),
    );
    final imageUrl = storage.getPublicUrl(path);
    try {
      await Supabase.instance.client.rpc(
        functionName,
        params: {'target_route_id': routeId, 'new_image_url': imageUrl},
      );
      return imageUrl;
    } catch (_) {
      await storage.remove([path]);
      rethrow;
    }
  }

  Future<void> _creatorUpdate(
    String functionName,
    Map<String, Object?> params,
  ) async {
    if (_currentUser == null) {
      throw const AuthException('Sign in before editing this warning.');
    }
    await Supabase.instance.client.rpc(functionName, params: params);
  }

  Future<void> updateRouteLocation({
    required String routeId,
    required double latitude,
    required double longitude,
  }) async {
    await _adminCoordinateUpdate('admin_update_route_location', {
      'route_id': routeId,
      'lat': latitude,
      'lng': longitude,
    });
  }

  Future<void> updateWallRouteLocations({
    required String wallId,
    required double latitude,
    required double longitude,
  }) async {
    await _adminCoordinateUpdate('admin_update_wall_route_locations', {
      'wall_id': wallId,
      'lat': latitude,
      'lng': longitude,
    });
  }

  Future<MapPathCatalog> loadMapPaths() async {
    if (SupabaseConfig.isConfigured) {
      try {
        final result = await Supabase.instance.client.rpc('map_paths');
        final value = result is String ? jsonDecode(result) : result;
        final paths = _parseMapPaths(value);
        await _cacheJson(_mapPathsCacheKey, value);
        return paths;
      } catch (_) {
        // Use the last downloaded paths below.
      }
    }

    final cached = await _loadCachedJson(_mapPathsCacheKey);
    return _parseMapPaths(cached);
  }

  Future<void> updateCragApproachPath({
    required String cragId,
    required List<LatLng> points,
  }) async {
    await _adminCoordinateUpdate('admin_update_crag_approach_path', {
      'crag_id': cragId,
      'points': _pathJson(points),
    });
  }

  Future<void> updateSkiRoutePath({
    required String routeName,
    required String segmentKind,
    required List<LatLng> points,
  }) async {
    await _adminCoordinateUpdate('admin_update_ski_route_segment', {
      'route_name': routeName,
      'segment_kind': segmentKind,
      'points': _pathJson(points),
    });
  }

  Future<Map<String, List<List<LatLng>>>> loadOfflineRegionPolygons() async {
    Object? value;
    if (SupabaseConfig.isConfigured) {
      try {
        value = await Supabase.instance.client
            .from('offline_map_regions')
            .select('id, boundary_polygons');
        await _cacheJson(_offlineRegionsCacheKey, value);
      } catch (_) {
        // Use the last downloaded region boundaries below.
      }
    }
    value ??= await _loadCachedJson(_offlineRegionsCacheKey);
    return _parseOfflineRegionPolygons(value);
  }

  Future<void> updateOfflineRegionPolygons({
    required String regionId,
    required List<List<LatLng>> polygons,
  }) async {
    await _adminCoordinateUpdate('admin_update_offline_map_region', {
      'region_id': regionId,
      'boundary_polygons': [for (final polygon in polygons) _pathJson(polygon)],
    });
  }

  Future<List<SkiRoute>> loadSkiRoutes() async {
    if (SupabaseConfig.isConfigured) {
      try {
        final result = await Supabase.instance.client.rpc('ski_catalog');
        final value = result is String ? jsonDecode(result) : result;
        final routes = _parseSkiRoutes(value);
        if (routes.isNotEmpty) await _cacheJson(_skiCatalogCacheKey, value);
        return routes;
      } catch (_) {
        // Use the last downloaded ski catalogue below.
      }
    }

    return _parseSkiRoutes(await _loadCachedJson(_skiCatalogCacheKey));
  }

  Future<SkiRoute> adminSaveSkiRoute({
    String? routeId,
    required Map<String, Object?> values,
    List<int>? imageBytes,
    String imageName = '',
    String imageContentType = 'image/jpeg',
    List<LatLng> ascentPoints = const [],
    List<LatLng> descentPoints = const [],
  }) async {
    if (!SupabaseConfig.isConfigured) {
      throw StateError('Supabase is not configured.');
    }

    String imageUrl = values['route_image_url']?.toString() ?? '';
    String? uploadedPath;
    if (imageBytes != null && imageBytes.isNotEmpty) {
      final extension = _safeFileExtension(imageName);
      uploadedPath =
          '${_currentUser?.id ?? 'admin'}/ski-route-${DateTime.now().microsecondsSinceEpoch}.$extension';
      final storage = Supabase.instance.client.storage.from(
        'submission-photos',
      );
      await storage.uploadBinary(
        uploadedPath,
        Uint8List.fromList(imageBytes),
        fileOptions: FileOptions(contentType: imageContentType, upsert: false),
      );
      imageUrl = storage.getPublicUrl(uploadedPath);
    }

    try {
      final result = await Supabase.instance.client.rpc(
        'admin_save_ski_route',
        params: {
          'route_id': routeId,
          ...values,
          'route_image_url': imageUrl,
          'ascent_points': _pathJson(ascentPoints),
          'descent_points': _pathJson(descentPoints),
        },
      );
      final value = result is String ? jsonDecode(result) : result;
      return _skiRouteFromJson(Map<String, Object?>.from(value as Map));
    } catch (_) {
      if (uploadedPath != null) {
        await Supabase.instance.client.storage.from('submission-photos').remove(
          [uploadedPath],
        );
      }
      rethrow;
    }
  }

  Future<String> submitRecordedPath({
    required String name,
    required String kind,
    required List<LatLng> points,
    required double distanceMeters,
    String? cragId,
    String? skiRouteName,
  }) async {
    if (_currentUser == null) {
      throw const AuthException('Sign in before submitting a GPS recording.');
    }
    if (points.length < 2) {
      throw StateError('Record at least two GPS points.');
    }
    final result = await Supabase.instance.client.rpc(
      'submit_recorded_path',
      params: {
        'path_name': name.trim(),
        'submitted_kind': kind,
        'target_crag_id': cragId,
        'target_ski_route_name': skiRouteName,
        'submitted_points': [
          for (final point in points) [point.latitude, point.longitude],
        ],
        'submitted_distance_meters': distanceMeters,
      },
    );
    return result?.toString() ?? '';
  }

  Future<void> clearCatalogCache() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_catalogCacheKey);
  }

  Future<void> _adminCoordinateUpdate(
    String functionName,
    Map<String, Object?> params,
  ) async {
    if (!SupabaseConfig.isConfigured) {
      throw StateError('Supabase is not configured.');
    }

    await Supabase.instance.client.rpc(functionName, params: params);
    await clearCatalogCache();
  }

  Future<void> _cacheCatalog(Object? catalog) async {
    await _cacheJson(_catalogCacheKey, catalog);
  }

  Future<void> _cacheJson(String key, Object? value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(key, jsonEncode(value));
  }

  Future<Object?> _loadCachedJson(String key) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  List<SkiRoute> _parseSkiRoutes(Object? value) {
    return _list(value)
        .map((item) => _skiRouteFromJson(Map<String, Object?>.from(item)))
        .toList(growable: false);
  }

  MapPathCatalog _parseMapPaths(Object? value) {
    if (value is! Map) return const MapPathCatalog();
    final json = Map<String, Object?>.from(value);
    return MapPathCatalog(
      cragApproaches: _pathMap(json['crags'], keyName: 'id'),
      skiAscents: _pathMap(
        json['skiRoutes'],
        keyName: 'name',
        pointsName: 'ascentPoints',
        legacyPointsName: 'points',
      ),
      skiDescents: _pathMap(
        json['skiRoutes'],
        keyName: 'name',
        pointsName: 'descentPoints',
      ),
    );
  }

  Map<String, List<List<LatLng>>> _parseOfflineRegionPolygons(Object? value) {
    final result = <String, List<List<LatLng>>>{};
    for (final item in _list(value)) {
      final json = Map<String, Object?>.from(item);
      final id = _string(json['id']);
      final polygons = <List<LatLng>>[];
      final rawPolygons = json['boundary_polygons'];
      for (final rawPolygon in rawPolygons is List ? rawPolygons : const []) {
        final polygon = <LatLng>[];
        for (final point in rawPolygon is List ? rawPolygon : const []) {
          if (point is! List || point.length < 2) continue;
          polygon.add(LatLng(_double(point[0]), _double(point[1])));
        }
        if (polygon.length >= 3) polygons.add(polygon);
      }
      if (id.isNotEmpty && polygons.isNotEmpty) result[id] = polygons;
    }
    return result;
  }

  Future<List<Crag>> _loadCachedCatalog() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_catalogCacheKey);
    if (raw == null || raw.isEmpty) return const [];

    try {
      return _parseCatalog(jsonDecode(raw));
    } catch (_) {
      return const [];
    }
  }

  List<Crag> _parseCatalog(Object? value) {
    final list = value is String ? jsonDecode(value) : value;
    if (list is! List) return const [];

    return list
        .whereType<Map>()
        .map((item) => _cragFromJson(Map<String, Object?>.from(item)))
        .toList();
  }

  Crag _cragFromJson(Map<String, Object?> json) {
    final lat = _double(json['lat']);
    final lng = _double(json['lng']);
    return Crag(
      id: _string(json['id']),
      name: _string(json['name']),
      province: _string(json['province']),
      region: _string(json['region']),
      location: LatLng(lat, lng),
      parking: LatLng(
        _double(json['parkingLat'], lat),
        _double(json['parkingLng'], lng),
      ),
      approachTrail: _string(json['approachTrail']),
      accessNotes: _string(json['accessNotes']),
      season: _string(json['season']),
      dangerInfo: _string(json['dangerInfo']),
      createdBy: _string(json['createdBy']),
      walls: _list(
        json['walls'],
      ).map((item) => _wallFromJson(Map<String, Object?>.from(item))).toList(),
    );
  }

  Wall _wallFromJson(Map<String, Object?> json) {
    return Wall(
      id: _string(json['id']),
      name: _string(json['name']),
      location: LatLng(_double(json['lat']), _double(json['lng'])),
      routes: _list(
        json['routes'],
      ).map((item) => _routeFromJson(Map<String, Object?>.from(item))).toList(),
    );
  }

  ClimbRoute _routeFromJson(Map<String, Object?> json) {
    final lat = json['lat'];
    final lng = json['lng'];
    return ClimbRoute(
      id: _string(json['id']),
      name: _string(json['name']),
      grade: _string(json['grade']),
      rating: _double(json['rating']),
      location: lat == null || lng == null
          ? null
          : LatLng(_double(lat), _double(lng)),
      description: _string(json['description']),
      type: _routeType(_string(json['type'])),
      pitchType: _pitchType(_string(json['pitchType'])),
      angle: _string(json['angle'], 'Vertical'),
      heightMeters: _int(json['heightMeters']),
      bolts: _int(json['bolts']),
      gearNotes: _string(json['gearNotes'], 'No gear notes listed yet.'),
      routeLength: _int(json['routeLength']),
      ropeLength: _int(json['ropeLength'], 60),
      topRope: json['topRope'] == true,
      approachNotes: _string(
        json['approachNotes'],
        'Approach notes coming soon.',
      ),
      descentNotes: _string(json['descentNotes'], 'Descent notes coming soon.'),
      dangerInfo: _string(json['dangerInfo']),
      imageUrl: _string(
        json['imageUrl'],
        'https://images.squarespace-cdn.com/content/v1/53f4116fe4b0fc4173f54f3f/b372d92d-f15e-4605-8a1b-76629df27e73/Main-Wall-2.jpg',
      ),
      trailheadImageUrl: _string(
        json['trailheadImageUrl'],
        'https://images.unsplash.com/photo-1522163182402-834f871fd851',
      ),
      createdBy: _string(json['createdBy']),
    );
  }

  SkiRoute _skiRouteFromJson(Map<String, Object?> json) {
    return SkiRoute(
      id: _string(json['id']),
      name: _string(json['name']),
      area: _string(json['area']),
      region: _string(json['region']),
      location: LatLng(_double(json['lat']), _double(json['lng'])),
      trailhead: LatLng(
        _double(json['trailheadLat']),
        _double(json['trailheadLng']),
      ),
      distanceKm: _double(json['distanceKm']),
      elevationGainMeters: _int(json['elevationGainMeters']),
      difficulty: _string(json['difficulty'], 'Intermediate'),
      aspect: _string(json['aspect'], 'North'),
      avalancheTerrain: _string(json['avalancheTerrain'], 'Challenging'),
      season: _string(json['season']),
      description: _string(json['description']),
      approachNotes: _string(json['approachNotes']),
      descentNotes: _string(json['descentNotes']),
      dangerInfo: _string(json['dangerInfo']),
      imageUrl: _string(json['imageUrl']),
      createdBy: _string(json['createdBy']),
      sourceUrl: _string(json['sourceUrl']),
    );
  }

  List<Map> _list(Object? value) {
    if (value is List) return value.whereType<Map>().toList();
    return const [];
  }

  Map<String, List<LatLng>> _pathMap(
    Object? value, {
    required String keyName,
    String pointsName = 'points',
    String? legacyPointsName,
  }) {
    final result = <String, List<LatLng>>{};
    for (final item in _list(value)) {
      final json = Map<String, Object?>.from(item);
      final key = _string(json[keyName]);
      final points = <LatLng>[];
      final rawPoints =
          json[pointsName] ??
          (legacyPointsName == null ? null : json[legacyPointsName]);
      for (final point in rawPoints is List ? rawPoints : const []) {
        if (point is! List || point.length < 2) continue;
        points.add(LatLng(_double(point[0]), _double(point[1])));
      }
      if (key.isNotEmpty && points.length >= 2) result[key] = points;
    }
    return result;
  }

  List<List<double>> _pathJson(List<LatLng> points) {
    return [
      for (final point in points) [point.latitude, point.longitude],
    ];
  }

  String _string(Object? value, [String fallback = '']) {
    if (value == null) return fallback;
    final text = value.toString();
    return text.isEmpty ? fallback : text;
  }

  int _int(Object? value, [int fallback = 0]) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  double _double(Object? value, [double fallback = 0]) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  String _safeFileExtension(String fileName) {
    final extension = fileName.contains('.')
        ? fileName
              .split('.')
              .last
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-z0-9]'), '')
        : 'jpg';
    return extension.isEmpty ? 'jpg' : extension;
  }

  ClimbRouteType _routeType(String value) {
    return switch (value.toLowerCase()) {
      'trad' => ClimbRouteType.trad,
      'boulder' => ClimbRouteType.boulder,
      'ice' => ClimbRouteType.ice,
      'mixed' => ClimbRouteType.mixed,
      _ => ClimbRouteType.sport,
    };
  }

  PitchType _pitchType(String value) {
    return switch (value.toLowerCase()) {
      'boulder' => PitchType.boulder,
      'multi_pitch' || 'multipitch' || 'multi pitch' => PitchType.multiPitch,
      _ => PitchType.singlePitch,
    };
  }
}

class UploadPhotoPayload {
  const UploadPhotoPayload({
    required this.bytes,
    required this.fileName,
    required this.contentType,
  });

  final List<int> bytes;
  final String fileName;
  final String contentType;
}
