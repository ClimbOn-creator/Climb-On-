import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

const savedTrailColors = <int>[
  0xFFE53935,
  0xFF1E88E5,
  0xFF43A047,
  0xFFFB8C00,
  0xFF8E24AA,
  0xFF00ACC1,
  0xFFFDD835,
  0xFF6D4C41,
  0xFFD81B60,
  0xFF3949AB,
];

int savedTrailColorFor(int index) =>
    savedTrailColors[index % savedTrailColors.length];

class SavedTrail {
  const SavedTrail({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.points,
    required this.distanceMeters,
    required this.ascentMeters,
    required this.descentMeters,
    required this.durationSeconds,
    required this.colorValue,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final List<LatLng> points;
  final double distanceMeters;
  final double ascentMeters;
  final double descentMeters;
  final int durationSeconds;
  final int colorValue;

  Color get color => Color(colorValue);

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'distanceMeters': distanceMeters,
    'ascentMeters': ascentMeters,
    'descentMeters': descentMeters,
    'durationSeconds': durationSeconds,
    'colorValue': colorValue,
    'points': [
      for (final point in points)
        {'lat': point.latitude, 'lng': point.longitude},
    ],
  };

  factory SavedTrail.fromJson(Map<String, Object?> json) {
    return SavedTrail(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Saved trail',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      points: (json['points'] as List? ?? const [])
          .whereType<Map>()
          .map((item) {
            final point = Map<String, Object?>.from(item);
            return LatLng(
              (point['lat'] as num).toDouble(),
              (point['lng'] as num).toDouble(),
            );
          })
          .toList(growable: false),
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble() ?? 0,
      ascentMeters: (json['ascentMeters'] as num?)?.toDouble() ?? 0,
      descentMeters: (json['descentMeters'] as num?)?.toDouble() ?? 0,
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      colorValue:
          (json['colorValue'] as num?)?.toInt() ?? savedTrailColors.first,
    );
  }
}
