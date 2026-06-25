import 'package:latlong2/latlong.dart';

class MapService {
  const MapService();

  double metersBetween(LatLng first, LatLng second) {
    const distance = Distance();
    return distance.as(LengthUnit.Meter, first, second);
  }
}
