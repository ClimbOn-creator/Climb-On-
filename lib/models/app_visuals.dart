class AppVisualDefinition {
  const AppVisualDefinition({
    required this.key,
    required this.label,
    required this.defaultUrl,
  });

  final String key;
  final String label;
  final String defaultUrl;
}

class AppVisuals {
  const AppVisuals(this.overrides);

  final Map<String, String> overrides;

  static const definitions = <AppVisualDefinition>[
    AppVisualDefinition(
      key: 'side_banner_left',
      label: 'Left background banner',
      defaultUrl:
          'https://images.unsplash.com/photo-1483728642387-6c3bdd6c93e5',
    ),
    AppVisualDefinition(
      key: 'side_banner_right',
      label: 'Right background banner',
      defaultUrl:
          'https://images.unsplash.com/photo-1519681393784-d120267933ba',
    ),
    AppVisualDefinition(
      key: 'default_crag',
      label: 'Default crag picture',
      defaultUrl:
          'https://images.unsplash.com/photo-1522163182402-834f871fd851',
    ),
    AppVisualDefinition(
      key: 'range_canadian-rockies',
      label: 'Canadian Rockies',
      defaultUrl:
          'https://images.unsplash.com/photo-1500534623283-312aade485b7',
    ),
    AppVisualDefinition(
      key: 'range_cariboo',
      label: 'Cariboo Mountains',
      defaultUrl:
          'https://images.unsplash.com/photo-1464278533981-50106e6176b1',
    ),
    AppVisualDefinition(
      key: 'range_selkirk',
      label: 'Selkirk Mountains',
      defaultUrl:
          'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b',
    ),
    AppVisualDefinition(
      key: 'range_monashee',
      label: 'Monashee Mountains',
      defaultUrl:
          'https://images.unsplash.com/photo-1483728642387-6c3bdd6c93e5',
    ),
    AppVisualDefinition(
      key: 'range_purcell',
      label: 'Purcell Mountains',
      defaultUrl:
          'https://images.unsplash.com/photo-1519681393784-d120267933ba',
    ),
    AppVisualDefinition(
      key: 'range_hart',
      label: 'Hart Ranges',
      defaultUrl:
          'https://images.unsplash.com/photo-1470770841072-f978cf4d019e',
    ),
    AppVisualDefinition(
      key: 'range_muskwa',
      label: 'Muskwa Ranges',
      defaultUrl:
          'https://images.unsplash.com/photo-1464278533981-50106e6176b1',
    ),
    AppVisualDefinition(
      key: 'range_coast-range',
      label: 'Coast Range',
      defaultUrl:
          'https://images.unsplash.com/photo-1522163182402-834f871fd851',
    ),
  ];

  static const defaults = AppVisuals({});

  String url(String key) {
    final override = overrides[key]?.trim() ?? '';
    if (override.isNotEmpty) return override;
    return definitions.firstWhere((item) => item.key == key).defaultUrl;
  }
}
