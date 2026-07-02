import 'package:latlong2/latlong.dart';

/// A deliberately conservative outline used to keep the ski catalogue focused
/// on Vancouver Island. It excludes the mainland, Gulf Islands, and Olympic
/// Peninsula while allowing route locations across the Island's mountain spine.
const _vancouverIslandOutline = <LatLng>[
  LatLng(50.92, -128.65),
  LatLng(51.00, -127.10),
  LatLng(50.63, -126.60),
  LatLng(50.15, -125.05),
  LatLng(49.30, -123.72),
  LatLng(48.78, -123.27),
  LatLng(48.30, -123.30),
  LatLng(48.30, -124.30),
  LatLng(48.58, -125.05),
  LatLng(49.10, -126.15),
  LatLng(49.85, -127.20),
  LatLng(50.50, -128.35),
];

bool isOnVancouverIsland(LatLng point) {
  var inside = false;
  for (
    var i = 0, j = _vancouverIslandOutline.length - 1;
    i < _vancouverIslandOutline.length;
    j = i++
  ) {
    final a = _vancouverIslandOutline[i];
    final b = _vancouverIslandOutline[j];
    final crossesLatitude =
        (a.latitude > point.latitude) != (b.latitude > point.latitude);
    if (!crossesLatitude) continue;

    final edgeLongitude =
        (b.longitude - a.longitude) *
            (point.latitude - a.latitude) /
            (b.latitude - a.latitude) +
        a.longitude;
    if (point.longitude < edgeLongitude) inside = !inside;
  }
  return inside;
}
