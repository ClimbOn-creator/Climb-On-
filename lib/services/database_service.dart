import 'dart:convert';

import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../data/sample_crags.dart' as sample_data;
import '../models/climb_route.dart';
import '../models/crag.dart';
import '../models/geo_bounds.dart';
import '../models/wall.dart';
import '../state/climb_log_state.dart';

class DatabaseService {
  const DatabaseService();

  static const _catalogCacheKey = 'climb_on_catalog_cache_v1';

  User? get _currentUser {
    if (!SupabaseConfig.isConfigured) return null;
    return Supabase.instance.client.auth.currentUser;
  }

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

  Future<void> saveComment(LocalRouteComment comment) async {
    final user = _currentUser;
    if (user == null) return;

    await Supabase.instance.client.from('route_comments').insert({
      'user_id': user.id,
      'route_id': comment.routeId,
      'body': comment.body,
      'created_at': comment.createdAt.toIso8601String(),
    });
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

  Future<void> submitRoute(Map<String, Object?> submission) async {
    if (!SupabaseConfig.isConfigured) {
      throw StateError('Supabase is not configured.');
    }

    final user = _currentUser;
    await Supabase.instance.client.from('route_submissions').insert({
      ...submission,
      'user_id': user?.id,
    });
  }

  Future<void> submitSkiRoute(Map<String, Object?> submission) async {
    if (!SupabaseConfig.isConfigured) {
      throw StateError('Supabase is not configured.');
    }

    final user = _currentUser;
    await Supabase.instance.client.from('ski_route_submissions').insert({
      ...submission,
      'user_id': user?.id,
    });
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
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_catalogCacheKey, jsonEncode(catalog));
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
    );
  }

  List<Map> _list(Object? value) {
    if (value is List) return value.whereType<Map>().toList();
    return const [];
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
