import 'package:climb_on/models/ar_beta_overlay.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses normalized hold and line coordinates', () {
    final overlay = ARBetaOverlay.fromJson({
      'referenceImageUrl': 'https://example.com/problem.webp',
      'holds': [
        {'x': 0.25, 'y': 0.8, 'type': 'start', 'label': 'LH'},
        {'x': 2, 'y': -1, 'type': 'finish', 'label': 'Top'},
      ],
      'line': [
        {'x': 0.25, 'y': 0.8},
        {'x': 0.5, 'y': 0.4},
      ],
    });

    expect(overlay.referenceImageUrl, 'https://example.com/problem.webp');
    expect(overlay.holds, hasLength(2));
    expect(overlay.holds.first.type, 'start');
    expect(overlay.holds.first.label, 'LH');
    expect(overlay.holds.last.x, 1);
    expect(overlay.holds.last.y, 0);
    expect(overlay.line, hasLength(2));
  });

  test('serializes only useful overlay fields', () {
    const overlay = ARBetaOverlay(
      holds: [ARBetaPoint(x: 0.4, y: 0.6, type: 'hand', label: '2')],
    );

    expect(overlay.toJson(), {
      'holds': [
        {'x': 0.4, 'y': 0.6, 'type': 'hand', 'label': '2'},
      ],
    });
  });
}
