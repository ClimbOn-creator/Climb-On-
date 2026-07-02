import 'package:latlong2/latlong.dart';

class Gym {
  const Gym({
    required this.id,
    required this.name,
    required this.location,
    required this.address,
  });

  final String id;
  final String name;
  final LatLng location;
  final String address;
}
