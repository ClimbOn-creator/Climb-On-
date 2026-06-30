import 'package:latlong2/latlong.dart';

class SkiRoute {
  const SkiRoute({
    required this.id,
    required this.name,
    required this.area,
    required this.region,
    required this.location,
    required this.trailhead,
    required this.distanceKm,
    required this.elevationGainMeters,
    required this.difficulty,
    required this.aspect,
    required this.avalancheTerrain,
    required this.season,
    required this.description,
    required this.approachNotes,
    required this.descentNotes,
    required this.dangerInfo,
    required this.imageUrl,
    this.createdBy = '',
    this.sourceUrl = '',
  });

  final String id;
  final String name;
  final String area;
  final String region;
  final LatLng location;
  final LatLng trailhead;
  final double distanceKm;
  final int elevationGainMeters;
  final String difficulty;
  final String aspect;
  final String avalancheTerrain;
  final String season;
  final String description;
  final String approachNotes;
  final String descentNotes;
  final String dangerInfo;
  final String imageUrl;
  final String createdBy;
  final String sourceUrl;
}
