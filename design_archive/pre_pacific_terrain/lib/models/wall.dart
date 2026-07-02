import 'climb_route.dart';
import 'package:latlong2/latlong.dart';

class Wall {
  const Wall({
    required this.id,
    required this.name,
    required this.location,
    required this.routes,
  });

  final String id;
  final String name;
  final LatLng location;
  final List<ClimbRoute> routes;
}
