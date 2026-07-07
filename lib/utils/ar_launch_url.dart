import 'package:flutter/foundation.dart';

enum ARAssetFormat { usdz, glb, gltf, unknown }

ARAssetFormat inferARAssetFormat(String url) {
  final uri = Uri.tryParse(url.trim());
  final path = (uri?.path ?? url).toLowerCase();
  if (path.endsWith('.usdz')) return ARAssetFormat.usdz;
  if (path.endsWith('.glb')) return ARAssetFormat.glb;
  if (path.endsWith('.gltf')) return ARAssetFormat.gltf;
  return ARAssetFormat.unknown;
}

String arAssetFormatLabel(ARAssetFormat format) {
  return switch (format) {
    ARAssetFormat.usdz => 'USDZ',
    ARAssetFormat.glb => 'GLB',
    ARAssetFormat.gltf => 'GLTF',
    ARAssetFormat.unknown => 'External',
  };
}

Uri? platformARLaunchUri(
  String assetUrl, {
  TargetPlatform? platform,
  String? fallbackUrl,
}) {
  final trimmed = assetUrl.trim();
  final assetUri = Uri.tryParse(trimmed);
  if (assetUri == null || !assetUri.hasScheme) return null;

  final targetPlatform = platform ?? defaultTargetPlatform;
  final format = inferARAssetFormat(trimmed);
  if (targetPlatform == TargetPlatform.iOS && format == ARAssetFormat.usdz) {
    return assetUri;
  }

  if (targetPlatform == TargetPlatform.android &&
      (format == ARAssetFormat.glb || format == ARAssetFormat.gltf)) {
    final fallback = Uri.encodeComponent(
      fallbackUrl?.trim().isNotEmpty == true ? fallbackUrl!.trim() : trimmed,
    );
    return Uri.parse(
      'intent://arvr.google.com/scene-viewer/1.0'
      '?file=${Uri.encodeComponent(trimmed)}'
      '&mode=ar_preferred'
      '#Intent;scheme=https;package=com.google.ar.core;'
      'action=android.intent.action.VIEW;'
      'S.browser_fallback_url=$fallback;end;',
    );
  }

  return assetUri;
}

bool canUseNativeARViewer(String assetUrl, {TargetPlatform? platform}) {
  final targetPlatform = platform ?? defaultTargetPlatform;
  final format = inferARAssetFormat(assetUrl);
  return (targetPlatform == TargetPlatform.iOS &&
          format == ARAssetFormat.usdz) ||
      (targetPlatform == TargetPlatform.android &&
          (format == ARAssetFormat.glb || format == ARAssetFormat.gltf));
}
