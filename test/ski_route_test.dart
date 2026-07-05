import 'package:climb_on/models/ski_route.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  SkiRoute routeWithAngle(int angle) => SkiRoute(
    id: 'test-tour',
    name: 'Test Tour',
    area: 'Test Area',
    region: 'Vancouver Island',
    location: const LatLng(49, -125),
    trailhead: const LatLng(49, -125),
    distanceKm: 8,
    elevationGainMeters: 700,
    difficulty: 'Intermediate',
    aspect: 'North',
    avalancheTerrain: 'Challenging',
    maxSlopeAngleDegrees: angle,
    season: 'Winter',
    description: '',
    approachNotes: '',
    descentNotes: '',
    dangerInfo: '',
    imageUrl: '',
  );

  test('ski tours format known and unknown slope angles', () {
    expect(routeWithAngle(34).slopeAngleLabel, '34° max slope');
    expect(routeWithAngle(0).slopeAngleLabel, 'Slope angle not listed');
  });
}
