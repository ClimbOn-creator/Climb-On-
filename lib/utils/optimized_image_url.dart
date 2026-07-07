enum ImageVariant { avatar, thumbnail, card, detail, offline }

String optimizedImageUrl(String url, ImageVariant variant) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return trimmed;

  final cloudinary = _cloudinaryUrl(trimmed, variant);
  if (cloudinary != null) return cloudinary;

  final unsplash = _unsplashUrl(trimmed, variant);
  if (unsplash != null) return unsplash;

  return trimmed;
}

String? _cloudinaryUrl(String url, ImageVariant variant) {
  const marker = '/image/upload/';
  final markerIndex = url.indexOf(marker);
  if (markerIndex == -1) return null;

  final afterMarker = markerIndex + marker.length;
  final suffix = url.substring(afterMarker);
  if (suffix.startsWith('c_') ||
      suffix.startsWith('f_') ||
      suffix.startsWith('q_') ||
      suffix.startsWith('w_')) {
    return url;
  }

  return '${url.substring(0, afterMarker)}${_cloudinaryTransform(variant)}/$suffix';
}

String _cloudinaryTransform(ImageVariant variant) {
  return switch (variant) {
    ImageVariant.avatar => 'f_auto,q_auto:eco,c_fill,g_auto,w_160,h_160',
    ImageVariant.thumbnail => 'f_auto,q_auto:eco,c_fill,w_480,h_320',
    ImageVariant.card => 'f_auto,q_auto:eco,c_fill,w_720,h_480',
    ImageVariant.detail => 'f_auto,q_auto:good,c_limit,w_1400',
    ImageVariant.offline => 'f_auto,q_auto:eco,c_limit,w_1000',
  };
}

String? _unsplashUrl(String url, ImageVariant variant) {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.host.contains('images.unsplash.com')) return null;

  final width = switch (variant) {
    ImageVariant.avatar => '160',
    ImageVariant.thumbnail => '480',
    ImageVariant.card => '720',
    ImageVariant.detail => '1400',
    ImageVariant.offline => '1000',
  };
  return uri
      .replace(
        queryParameters: {
          ...uri.queryParameters,
          'auto': 'format',
          'fit': 'crop',
          'w': width,
          'q': variant == ImageVariant.detail ? '78' : '65',
        },
      )
      .toString();
}
