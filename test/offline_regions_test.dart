import 'package:climb_on/models/offline_bc_region.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('BC is divided into no more than six offline sections', () {
    expect(offlineBcRegions, hasLength(6));
    expect(offlineBcRegions.map((region) => region.id).toSet(), hasLength(6));
  });

  test('key BC destinations belong to an offline section', () {
    const destinations = [
      LatLng(48.4284, -123.3656), // Victoria
      LatLng(49.2827, -123.1207), // Vancouver
      LatLng(50.1163, -122.9574), // Whistler
      LatLng(50.6745, -120.3273), // Kamloops
      LatLng(49.8880, -119.4960), // Kelowna
      LatLng(49.5120, -115.7694), // Fernie
      LatLng(53.9171, -122.7497), // Prince George
      LatLng(58.8050, -122.6972), // Fort Nelson
    ];

    for (final destination in destinations) {
      expect(
        offlineBcRegions.any((region) => region.contains(destination)),
        isTrue,
        reason: '$destination is not covered',
      );
    }
  });
}
