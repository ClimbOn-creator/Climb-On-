import 'package:latlong2/latlong.dart';

class MapPathCatalog {
  const MapPathCatalog({
    this.cragApproaches = const {},
    this.skiAscents = const {},
    this.skiDescents = const {},
  });

  final Map<String, List<LatLng>> cragApproaches;
  final Map<String, List<LatLng>> skiAscents;
  final Map<String, List<LatLng>> skiDescents;

  List<LatLng> cragPath(String cragId) {
    return cragApproaches[cragId] ?? const [];
  }

  List<LatLng> skiAscent(String routeName) {
    return skiAscents[routeName] ?? const [];
  }

  List<LatLng> skiDescent(String routeName) {
    return skiDescents[routeName] ?? const [];
  }
}
