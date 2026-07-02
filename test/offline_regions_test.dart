import 'package:climb_on/models/offline_bc_region.dart';
import 'package:climb_on/state/offline_region_state.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('official BC tourism boundary asset contains all six regions', () async {
    final source = await rootBundle.loadString(
      'assets/data/bc_tourism_regions.geojson',
    );
    final regions = parseOfficialTourismRegions(source);

    expect(
      regions.keys,
      containsAll(offlineBcRegions.map((region) => region.id)),
    );
    expect(regions['vancouver-coast-mountains']!.single, hasLength(6443));
    expect(regions['thompson-okanagan']!.single, hasLength(9840));
    expect(regions['bc-rockies']!.single, hasLength(3985));
    expect(
      regions['bc-rockies']!.single
          .map((point) => point.longitude)
          .reduce((a, b) => a > b ? a : b),
      lessThan(-114.05),
      reason: 'The Rockies boundary must not cross into Alberta.',
    );
  });

  test('six downloadable regions and one expansion preview are shown', () {
    expect(offlineBcRegions, hasLength(7));
    expect(offlineBcRegions.map((region) => region.id).toSet(), hasLength(7));
    expect(
      offlineBcRegions.where((region) => region.isComingSoon),
      hasLength(1),
    );
  });

  test('offline sections use the requested BC region names', () {
    expect(offlineBcRegions.map((region) => region.name), [
      'The Coast',
      'Mainland and Sunshine Coast',
      'Thompson Okanagan',
      'Rockies',
      'Cariboo, Chilcotin Coast',
      'Northern BC',
      'Coming soon!',
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
