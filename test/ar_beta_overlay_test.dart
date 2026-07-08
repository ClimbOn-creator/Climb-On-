import 'package:climb_on/models/ar_beta_overlay.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses normalized hold and line coordinates', () {
    final overlay = ARBetaOverlay.fromJson({
      'referenceImageUrl': 'https://example.com/problem.webp',
      'holds': [
        {
          'x': 0.25,
          'y': 0.8,
          'type': 'start',
          'label': 'LH',
          'title': 'Left start rail',
          'imageUrl': 'https://example.com/left-hand.webp',
          'description': 'Start matched low and keep the right hip in.',
        },
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
    expect(overlay.holds.first.title, 'Left start rail');
    expect(overlay.holds.first.imageUrl, 'https://example.com/left-hand.webp');
    expect(
      overlay.holds.first.description,
      'Start matched low and keep the right hip in.',
    );
    expect(overlay.holds.first.hasBetaDetails, isTrue);
    expect(overlay.holds.last.x, 1);
    expect(overlay.holds.last.y, 0);
    expect(overlay.line, hasLength(2));
  });

  test('serializes only useful overlay fields', () {
    const overlay = ARBetaOverlay(
      holds: [
        ARBetaPoint(
          x: 0.4,
          y: 0.6,
          type: 'hand',
          label: '2',
          title: 'Right-hand crimp',
          imageUrl: 'https://example.com/crimp.webp',
          description: 'Use the thumb catch and turn the left knee in.',
        ),
      ],
    );

    expect(overlay.toJson(), {
      'holds': [
        {
          'x': 0.4,
          'y': 0.6,
          'type': 'hand',
          'label': '2',
          'title': 'Right-hand crimp',
          'imageUrl': 'https://example.com/crimp.webp',
          'description': 'Use the thumb catch and turn the left knee in.',
        },
      ],
    });
  });
}
