import 'package:latlong2/latlong.dart';

class MapPathCatalog {
  const MapPathCatalog({
    this.cragApproaches = const {},
    this.skiRoutes = const {},
  });

  final Map<String, List<LatLng>> cragApproaches;
  final Map<String, List<LatLng>> skiRoutes;

  List<LatLng> cragPath(String cragId) {
    return cragApproaches[cragId] ?? const [];
  }

  List<LatLng> skiPath(String routeName) {
    return skiRoutes[routeName] ?? const [];
  }
}
