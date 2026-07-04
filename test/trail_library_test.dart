import 'package:climb_on/models/saved_trail.dart';
import 'package:climb_on/state/trail_library_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('saved trails round-trip through local storage', () async {
    SharedPreferences.setMockInitialValues({});
    final state = TrailLibraryState();
    await state.load();

    final trail = SavedTrail(
      id: 'trail-1',
      name: 'North ridge approach',
      createdAt: DateTime.utc(2026, 7, 3),
      points: const [LatLng(48.4, -123.5), LatLng(48.41, -123.49)],
      distanceMeters: 820,
      ascentMeters: 140,
      descentMeters: 12,
      durationSeconds: 900,
      colorValue: state.nextColorValue,
    );
    await state.add(trail);

    final restored = TrailLibraryState();
    await restored.load();

    expect(restored.trails, hasLength(1));
    expect(restored.trails.single.name, 'North ridge approach');
    expect(restored.trails.single.points, hasLength(2));
    expect(restored.trails.single.colorValue, savedTrailColors.first);
  });

  test('successive trails receive different colors', () {
    expect(savedTrailColorFor(0), isNot(savedTrailColorFor(1)));
    expect(savedTrailColorFor(1), isNot(savedTrailColorFor(2)));
  });
}
