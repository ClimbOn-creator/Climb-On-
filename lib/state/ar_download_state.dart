import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/climb_route.dart';
import '../utils/optimized_image_url.dart';

final arDownloadProvider = ChangeNotifierProvider<ARDownloadState>((ref) {
  return ARDownloadState()..restore();
});

class ARPackStatus {
  const ARPackStatus({
    this.downloading = false,
    this.ready = false,
    this.progress = 0,
    this.downloadedAt,
    this.message = '',
  });

  final bool downloading;
  final bool ready;
  final double progress;
  final DateTime? downloadedAt;
  final String message;

  Map<String, Object?> toJson() => {
    'ready': ready,
    'progress': progress,
    'downloadedAt': downloadedAt?.toIso8601String(),
    'message': message,
  };

  factory ARPackStatus.fromJson(Map<String, Object?> json) {
    return ARPackStatus(
      ready: json['ready'] == true,
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      downloadedAt: DateTime.tryParse(json['downloadedAt']?.toString() ?? ''),
      message: json['message']?.toString() ?? '',
    );
  }
}

class ARDownloadState extends ChangeNotifier {
  static const _storageKey = 'climb_on_route_ar_packs_v1';

  final Map<String, ARPackStatus> _statuses = {};
  bool _disposed = false;

  ARPackStatus statusFor(String routeId) {
    return _statuses[routeId] ?? const ARPackStatus();
  }

  Future<void> restore() async {
    final store = await SharedPreferences.getInstance();
    final raw = store.getString(_storageKey);
    if (raw == null || raw.isEmpty) return;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return;
    for (final entry in decoded.entries) {
      if (entry.value is Map) {
        _statuses[entry.key.toString()] = ARPackStatus.fromJson(
          Map<String, Object?>.from(entry.value as Map),
        );
      }
    }
    _notify();
  }

  Future<void> download(ClimbRoute route) async {
    final scan = route.arScan;
    if (scan == null || !scan.isAvailable) return;
    final previous = statusFor(route.id);
    if (previous.downloading) return;

    _set(
      route.id,
      ARPackStatus(
        downloading: true,
        ready: previous.ready,
        progress: 0.05,
        message: 'Preparing AR pack...',
      ),
    );

    try {
      final urls = <String>[
        scan.assetUrl,
        scan.anchorImageUrl,
        ?scan.betaOverlay?.referenceImageUrl,
      ].where((url) => url.trim().isNotEmpty).toList(growable: false);

      for (var index = 0; index < urls.length; index++) {
        final url = urls[index];
        await _downloadUrl(url);
        _set(
          route.id,
          ARPackStatus(
            downloading: true,
            ready: previous.ready,
            progress: 0.08 + 0.88 * (index + 1) / urls.length,
            message: 'Saving AR file ${index + 1} of ${urls.length}...',
          ),
        );
      }

      _set(
        route.id,
        ARPackStatus(
          ready: true,
          progress: 1,
          downloadedAt: DateTime.now(),
          message: 'AR pack downloaded.',
        ),
      );
      await _persist();
    } catch (error) {
      _set(
        route.id,
        ARPackStatus(
          ready: previous.ready,
          progress: previous.progress,
          message: 'AR download paused: $error',
        ),
      );
      await _persist();
    }
  }

  Future<void> _downloadUrl(String url) async {
    final optimized = _isLikelyImage(url)
        ? optimizedImageUrl(url, ImageVariant.offline)
        : url;
    await DefaultCacheManager().downloadFile(optimized);
  }

  bool _isLikelyImage(String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
    return path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png') ||
        path.endsWith('.webp') ||
        path.endsWith('.heic');
  }

  void _set(String routeId, ARPackStatus status) {
    _statuses[routeId] = status;
    _notify();
  }

  Future<void> _persist() async {
    final store = await SharedPreferences.getInstance();
    await store.setString(
      _storageKey,
      jsonEncode(_statuses.map((key, value) => MapEntry(key, value.toJson()))),
    );
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
