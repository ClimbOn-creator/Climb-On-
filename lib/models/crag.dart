import 'package:latlong2/latlong.dart';

import 'wall.dart';

class Crag {
  const Crag({
    required this.id,
    required this.name,
    required this.province,
    required this.region,
    required this.location,
    required this.parking,
    required this.approachTrail,
    required this.accessNotes,
    required this.season,
    required this.dangerInfo,
    required this.walls,
  });

  final String id;
  final String name;
  final String province;
  final String region;
  final LatLng location;
  final LatLng parking;
  final String approachTrail;
  final String accessNotes;
  final String season;
  final String dangerInfo;
  final List<Wall> walls;
}
