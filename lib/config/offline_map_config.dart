class OfflineMapConfig {
  const OfflineMapConfig._();

  static const mapboxAccessToken = String.fromEnvironment(
    'MAPBOX_ACCESS_TOKEN',
  );

  static const _mapServiceBaseUrl = String.fromEnvironment(
    'OFFLINE_MAP_BASE_URL',
  );
  static const _cleanStyleUrl = String.fromEnvironment(
    'OFFLINE_CLEAN_STYLE_URL',
  );
  static const _satelliteStyleUrl = String.fromEnvironment(
    'OFFLINE_SATELLITE_STYLE_URL',
  );
  static const _terrain3dStyleUrl = String.fromEnvironment(
    'OFFLINE_3D_STYLE_URL',
  );

  static String get mapServiceBaseUrl =>
      _mapServiceBaseUrl.replaceFirst(RegExp(r'/+$'), '');

  static String _style(String override, String name) {
    if (override.isNotEmpty) return override;
    final base = mapServiceBaseUrl;
    return base.isEmpty ? '' : '$base/styles/$name.json';
  }

  static String get cleanStyleUrl => _style(_cleanStyleUrl, 'clean');
  static String get satelliteStyleUrl =>
      _style(_satelliteStyleUrl, 'satellite-v2');
  static String get terrain3dStyleUrl => _style(_terrain3dStyleUrl, '3d-v2');

  static const openMapAttribution =
      '© OpenStreetMap contributors · Protomaps · '
      'Imagery: Esri and data providers · '
      'Terrain: Natural Resources Canada';

  static Map<String, String> downloadableStyles({
    required bool includeTerrain3d,
  }) => {
    if (cleanStyleUrl.isNotEmpty) 'Clean 2D': cleanStyleUrl,
    if (satelliteStyleUrl.isNotEmpty) 'Satellite': satelliteStyleUrl,
    if (includeTerrain3d && terrain3dStyleUrl.isNotEmpty)
      'Terrain 3D': terrain3dStyleUrl,
  };

  static bool get mapsConfigured => mapboxAccessToken.isNotEmpty;
  static bool get satelliteConfigured => mapboxAccessToken.isNotEmpty;
  static bool get terrainConfigured => mapboxAccessToken.isNotEmpty;
  static bool get allCoreMapsConfigured => mapsConfigured && terrainConfigured;
}
