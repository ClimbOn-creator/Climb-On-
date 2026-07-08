class ARBetaPoint {
  const ARBetaPoint({
    required this.x,
    required this.y,
    this.type = 'hand',
    this.label = '',
    this.title = '',
    this.imageUrl = '',
    this.description = '',
  });

  final double x;
  final double y;
  final String type;
  final String label;
  final String title;
  final String imageUrl;
  final String description;

  bool get hasBetaDetails =>
      title.trim().isNotEmpty ||
      imageUrl.trim().isNotEmpty ||
      description.trim().isNotEmpty;

  factory ARBetaPoint.fromJson(Map<String, Object?> json) {
    return ARBetaPoint(
      x: _unit(json['x']),
      y: _unit(json['y']),
      type: json['type']?.toString() ?? 'hand',
      label: json['label']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
    );
  }

  Map<String, Object?> toJson() => {
    'x': x,
    'y': y,
    'type': type,
    'label': label,
    if (title.trim().isNotEmpty) 'title': title.trim(),
    if (imageUrl.trim().isNotEmpty) 'imageUrl': imageUrl.trim(),
    if (description.trim().isNotEmpty) 'description': description.trim(),
  };

  static double _unit(Object? value) {
    final parsed = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '') ?? 0;
    return parsed.clamp(0, 1).toDouble();
  }
}

class ARBetaOverlay {
  const ARBetaOverlay({
    this.referenceImageUrl = '',
    this.holds = const [],
    this.line = const [],
  });

  final String referenceImageUrl;
  final List<ARBetaPoint> holds;
  final List<ARBetaPoint> line;

  bool get isNotEmpty =>
      referenceImageUrl.trim().isNotEmpty ||
      holds.isNotEmpty ||
      line.isNotEmpty;

  factory ARBetaOverlay.fromJson(Map<String, Object?> json) {
    return ARBetaOverlay(
      referenceImageUrl: json['referenceImageUrl']?.toString() ?? '',
      holds: _points(json['holds']),
      line: _points(json['line']),
    );
  }

  Map<String, Object?> toJson() => {
    if (referenceImageUrl.trim().isNotEmpty)
      'referenceImageUrl': referenceImageUrl.trim(),
    if (holds.isNotEmpty)
      'holds': holds.map((point) => point.toJson()).toList(),
    if (line.isNotEmpty) 'line': line.map((point) => point.toJson()).toList(),
  };

  static List<ARBetaPoint> _points(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => ARBetaPoint.fromJson(Map<String, Object?>.from(item)))
        .toList(growable: false);
  }
}
