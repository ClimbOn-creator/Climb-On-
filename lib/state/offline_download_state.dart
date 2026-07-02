import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' as geo;
import 'package:maplibre_gl/maplibre_gl.dart' as ml;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/offline_map_config.dart';
import '../models/climb_route.dart';
import '../models/offline_bc_region.dart';
import '../state/catalog_state.dart';
import '../state/climb_log_state.dart';
import '../state/map_path_state.dart';
import '../state/ski_route_state.dart';

final offlineDownloadProvider = ChangeNotifierProvider<OfflineDownloadState>((
  ref,
) {
  return OfflineDownloadState(ref)..restore();
});

class OfflineRegionStatus {
  const OfflineRegionStatus({
    this.downloading = false,
    this.dataReady = false,
    this.mapsReady = false,
    this.terrainReady = false,
    this.progress = 0,
    this.downloadedAt,
    this.message = '',
  });

  final bool downloading;
  final bool dataReady;
  final bool mapsReady;
  final bool terrainReady;
  final double progress;
  final DateTime? downloadedAt;
  final String message;

  bool get ready => dataReady && mapsReady;

  Map<String, Object?> toJson() => {
    'dataReady': dataReady,
    'mapsReady': mapsReady,
    'terrainReady': terrainReady,
    'progress': progress,
    'downloadedAt': downloadedAt?.toIso8601String(),
    'message': message,
  };

  factory OfflineRegionStatus.fromJson(Map<String, Object?> json) {
    return OfflineRegionStatus(
      dataReady: json['dataReady'] == true,
      mapsReady: json['mapsReady'] == true,
      terrainReady: json['terrainReady'] == true,
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      downloadedAt: DateTime.tryParse(json['downloadedAt']?.toString() ?? ''),
      message: json['message']?.toString() ?? '',
    );
  }
}

class OfflineDownloadState extends ChangeNotifier {
  OfflineDownloadState(this.ref);

  static const _storageKey = 'climb_on_offline_regions_v1';
  final Ref ref;
  final Map<String, OfflineRegionStatus> _statuses = {};
  bool _disposed = false;

  OfflineRegionStatus statusFor(String regionId) {
    return _statuses[regionId] ?? const OfflineRegionStatus();
  }

  Future<void> restore() async {
    final store = await SharedPreferences.getInstance();
    final raw = store.getString(_storageKey);
    if (raw == null || raw.isEmpty) return;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return;
    for (final entry in decoded.entries) {
      if (entry.value is Map) {
        _statuses[entry.key.toString()] = OfflineRegionStatus.fromJson(
          Map<String, Object?>.from(entry.value as Map),
        );
      }
    }
    _notify();
  }

  Future<void> download(
    OfflineBcRegion region, {
    required bool includeTerrain3d,
  }) async {
    final previous = statusFor(region.id);
    if (previous.downloading) return;
    _set(
      region.id,
      OfflineRegionStatus(
        downloading: true,
        dataReady: previous.dataReady,
        mapsReady: previous.mapsReady,
        terrainReady: previous.terrainReady,
        progress: 0.01,
        message: 'Preparing route and tour information…',
      ),
    );

    try {
      final crags = await ref.read(catalogProvider.future);
      final skiRoutes = await ref.read(skiRouteCatalogProvider.future);
      await ref.read(mapPathCatalogProvider.future);
      final regionCrags = crags
          .where((crag) => region.contains(crag.location))
          .toList(growable: false);
      final routes = <ClimbRoute>[
        for (final crag in regionCrags)
          for (final wall in crag.walls) ...wall.routes,
      ];
      final regionTours = skiRoutes
          .where((route) => region.contains(route.location))
          .toList(growable: false);

      _set(
        region.id,
        const OfflineRegionStatus(
          downloading: true,
          progress: 0.08,
          message: 'Downloading route pages, comments, and pictures…',
        ),
      );

      final climbLog = ref.read(climbLogProvider);
      for (var index = 0; index < routes.length; index++) {
        final route = routes[index];
        await climbLog.loadCommentsFor(route);
        await climbLog.loadPhotosFor(route);
        _set(
          region.id,
          OfflineRegionStatus(
            downloading: true,
            progress:
                0.08 +
                (routes.isEmpty ? 0 : 0.18 * (index + 1) / routes.length),
            message: 'Saving ${route.name}…',
          ),
        );
      }

      final imageUrls = <String>{
        for (final route in routes) ...[
          route.imageUrl,
          route.trailheadImageUrl,
          for (final photo in climbLog.photosFor(route)) photo.url,
        ],
        for (final tour in regionTours) tour.imageUrl,
      }..removeWhere((url) => url.trim().isEmpty);

      var imageIndex = 0;
      for (final url in imageUrls) {
        try {
          await DefaultCacheManager().downloadFile(url);
        } catch (_) {
          // A single missing community picture should not discard the pack.
        }
        imageIndex++;
        _set(
          region.id,
          OfflineRegionStatus(
            downloading: true,
            progress:
                0.26 +
                (imageUrls.isEmpty ? 0 : 0.24 * imageIndex / imageUrls.length),
            message: 'Saving pictures $imageIndex of ${imageUrls.length}…',
          ),
        );
      }

      final points = [
        for (final crag in regionCrags) crag.location,
        for (final tour in regionTours) tour.location,
      ];
      final mapResult = await _downloadMapPacks(
        region,
        points,
        includeTerrain3d: includeTerrain3d,
      );
      final mapsReady = mapResult.mapsReady;
      final terrainReady = mapResult.terrainReady || previous.terrainReady;
      final now = DateTime.now();
      _set(
        region.id,
        OfflineRegionStatus(
          dataReady: true,
          mapsReady: mapsReady,
          terrainReady: terrainReady,
          progress: mapsReady ? 1 : 0.5,
          downloadedAt: now,
          message: mapsReady
              ? terrainReady
                    ? '2D, satellite, and 3D terrain are ready offline.'
                    : 'Clean 2D and satellite are ready offline.'
              : kIsWeb
              ? 'Route data and pictures are ready. Native map packs are available in the iPhone/Android app.'
              : 'Route data and pictures are ready. Add licensed offline map style URLs to enable map packs.',
        ),
      );
      await _persist();
    } catch (error) {
      _set(
        region.id,
        OfflineRegionStatus(
          dataReady: statusFor(region.id).dataReady,
          mapsReady: statusFor(region.id).mapsReady,
          terrainReady: statusFor(region.id).terrainReady,
          progress: statusFor(region.id).progress,
          message: 'Download paused: $error',
        ),
      );
      await _persist();
    }
  }

  Future<({bool mapsReady, bool terrainReady})> _downloadMapPacks(
    OfflineBcRegion region,
    List<geo.LatLng> points, {
    required bool includeTerrain3d,
  }) async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.iOS &&
            defaultTargetPlatform != TargetPlatform.android) ||
        !OfflineMapConfig.mapsConfigured) {
      return (mapsReady: false, terrainReady: false);
    }

    await ml.setOfflineTileCountLimit(2000000);
    await ml.setOfflineMaxConcurrentRequests(
      maxRequests: 4,
      maxRequestsPerHost: 2,
    );
    final styles = OfflineMapConfig.downloadableStyles(
      includeTerrain3d: includeTerrain3d,
    ).entries.toList();
    final sectionBounds = region.downloadBounds();
    var finished = 0;
    final total = styles.length * (sectionBounds.length + points.length);

    for (final style in styles) {
      for (var part = 0; part < sectionBounds.length; part++) {
        final bounds = sectionBounds[part];
        await _downloadPack(
          region: region,
          layer: style.key,
          styleUrl: style.value,
          bounds: ml.LatLngBounds(
            southwest: ml.LatLng(bounds.south, bounds.west),
            northeast: ml.LatLng(bounds.north, bounds.east),
          ),
          minZoom: 5,
          maxZoom: 13,
          detail: false,
          sectionPart: part,
        );
        finished++;
        _mapProgress(region.id, finished, total, style.key);
      }

      for (final point in points) {
        const radius = 0.045;
        await _downloadPack(
          region: region,
          layer: style.key,
          styleUrl: style.value,
          bounds: ml.LatLngBounds(
            southwest: ml.LatLng(
              point.latitude - radius,
              point.longitude - radius,
            ),
            northeast: ml.LatLng(
              point.latitude + radius,
              point.longitude + radius,
            ),
          ),
          minZoom: 13,
          maxZoom: 16,
          detail: true,
        );
        finished++;
        _mapProgress(region.id, finished, total, style.key);
      }
    }
    final installed = await ml.getListOfRegions();
    final installedLayers = installed
        .where(
          (pack) => pack.metadata['climbOnRegionId']?.toString() == region.id,
        )
        .map((pack) => pack.metadata['layer']?.toString())
        .whereType<String>()
        .toSet();
    final mapsReady =
        installedLayers.contains('Clean 2D') &&
        installedLayers.contains('Satellite');
    final terrainReady =
        includeTerrain3d && installedLayers.contains('Satellite 3D');
    return (mapsReady: mapsReady, terrainReady: terrainReady);
  }

  Future<void> _downloadPack({
    required OfflineBcRegion region,
    required String layer,
    required String styleUrl,
    required ml.LatLngBounds bounds,
    required double minZoom,
    required double maxZoom,
    required bool detail,
    int? sectionPart,
  }) async {
    await ml.downloadOfflineRegion(
      ml.OfflineRegionDefinition(
        bounds: bounds,
        mapStyleUrl: styleUrl,
        minZoom: minZoom,
        maxZoom: maxZoom,
      ),
      metadata: {
        'climbOnRegionId': region.id,
        'layer': layer,
        'detail': detail,
        'sectionPart': ?sectionPart,
      },
    );
  }

  void _mapProgress(String regionId, int finished, int total, String layer) {
    _set(
      regionId,
      OfflineRegionStatus(
        downloading: true,
        dataReady: true,
        progress: total == 0 ? 1 : 0.5 + 0.5 * finished / total,
        message: 'Downloading $layer maps $finished of $total…',
      ),
    );
  }

  Future<void> remove(OfflineBcRegion region) async {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android)) {
      try {
        final packs = await ml.getListOfRegions();
        for (final pack in packs.where(
          (pack) => pack.metadata['climbOnRegionId'] == region.id,
        )) {
          await ml.deleteOfflineRegion(pack.id);
        }
        await ml.clearAmbientCache();
      } catch (_) {
        // Still clear the app-level pack marker if native storage is absent.
      }
    }
    _statuses.remove(region.id);
    await _persist();
    _notify();
  }

  void _set(String regionId, OfflineRegionStatus status) {
    _statuses[regionId] = status;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _persist() async {
    final store = await SharedPreferences.getInstance();
    await store.setString(
      _storageKey,
      jsonEncode({
        for (final entry in _statuses.entries) entry.key: entry.value.toJson(),
      }),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
