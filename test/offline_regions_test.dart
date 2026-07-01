import 'package:climb_on/models/offline_bc_region.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('BC is divided into no more than six offline sections', () {
    expect(offlineBcRegions, hasLength(6));
    expect(offlineBcRegions.map((region) => region.id).toSet(), hasLength(6));
  });

  test('offline sections use the requested BC region names', () {
    expect(offlineBcRegions.map((region) => region.name), [
      'The Islands',
      'Vancouver Coast & Mountains',
      'Thompson Okanagan',
      'BC Rockies',
      'Cariboo, Chilcotin Coast',
      'Northern BC',
    ]);
  });

  test('saved boundary polygons can replace a default section outline', () {
    final original = offlineBcRegions.first;
    const replacement = [
      LatLng(48.0, -124.0),
      LatLng(49.0, -124.0),
      LatLng(48.5, -123.0),
    ];
    final edited = original.copyWith(polygons: const [replacement]);

    expect(edited.name, original.name);
    expect(edited.polygons.single, replacement);
    expect(edited.contains(const LatLng(48.5, -123.5)), isTrue);
    expect(edited.downloadBounds(), isNotEmpty);
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
      final matchingRegions = offlineBcRegions
          .where((region) => region.contains(destination))
          .toList();
      expect(
        matchingRegions,
        hasLength(1),
        reason: '$destination is not covered',
      );
    }
  });
}
