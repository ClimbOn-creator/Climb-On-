class OfflineMapConfig {
  const OfflineMapConfig._();

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
      _style(_satelliteStyleUrl, 'satellite');
  static String get terrain3dStyleUrl => _style(_terrain3dStyleUrl, '3d');

  static const openMapAttribution =
      '© OpenStreetMap contributors · Protomaps · '
      'Terrain: Natural Resources Canada CDEM · '
      'Satellite: Copernicus Sentinel-2';

  static Map<String, String> downloadableStyles({
    required bool includeTerrain3d,
  }) => {
    if (cleanStyleUrl.isNotEmpty) 'Clean 2D': cleanStyleUrl,
    if (satelliteStyleUrl.isNotEmpty) 'Satellite': satelliteStyleUrl,
    if (includeTerrain3d && terrain3dStyleUrl.isNotEmpty)
      'Satellite 3D': terrain3dStyleUrl,
  };

  static bool get mapsConfigured =>
      cleanStyleUrl.isNotEmpty && satelliteStyleUrl.isNotEmpty;
  static bool get terrainConfigured => terrain3dStyleUrl.isNotEmpty;
  static bool get allCoreMapsConfigured => mapsConfigured && terrainConfigured;
}
