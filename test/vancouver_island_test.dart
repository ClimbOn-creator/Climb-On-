import 'package:climb_on/utils/vancouver_island.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('accepts Vancouver Island ski areas', () {
    const islandLocations = [
      LatLng(50.2350, -126.3200), // Mount Cain
      LatLng(49.707658, -125.323884), // Mount Elma
      LatLng(49.191611, -125.282476), // 5040 Peak
      LatLng(49.223611, -124.594444), // Mount Arrowsmith
      LatLng(48.4284, -123.3656), // Victoria
    ];

    expect(islandLocations.every(isOnVancouverIsland), isTrue);
  });

  test('rejects mainland and Olympic Peninsula locations', () {
    const offIslandLocations = [
      LatLng(49.9120, -123.1050), // Garibaldi
      LatLng(50.3760, -122.5320), // Duffey Lake
      LatLng(49.6040, -121.0770), // Coquihalla
      LatLng(47.8021, -123.6044), // Olympic Peninsula
    ];

    expect(
      offIslandLocations.every((point) => !isOnVancouverIsland(point)),
      isTrue,
    );
  });
}
