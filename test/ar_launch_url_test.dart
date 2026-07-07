import 'package:climb_on/utils/ar_launch_url.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('infers AR asset format without being confused by query strings', () {
    expect(
      inferARAssetFormat('https://cdn.example.com/route.usdz?token=abc'),
      ARAssetFormat.usdz,
    );
    expect(
      inferARAssetFormat('https://cdn.example.com/route.glb?token=abc'),
      ARAssetFormat.glb,
    );
  });

  test('uses direct USDZ links for iOS Quick Look', () {
    final uri = platformARLaunchUri(
      'https://cdn.example.com/route.usdz',
      platform: TargetPlatform.iOS,
    );

    expect(uri.toString(), 'https://cdn.example.com/route.usdz');
  });

  test('builds Android Scene Viewer intent for GLB assets', () {
    final uri = platformARLaunchUri(
      'https://cdn.example.com/route.glb',
      platform: TargetPlatform.android,
    );

    expect(uri.toString(), contains('arvr.google.com/scene-viewer/1.0'));
    expect(uri.toString(), contains('file=https%3A%2F%2Fcdn.example.com'));
    expect(uri.toString(), contains('package=com.google.ar.core'));
  });

  test('falls back to plain URL for unsupported platform format pairs', () {
    final uri = platformARLaunchUri(
      'https://cdn.example.com/route.usdz',
      platform: TargetPlatform.android,
    );

    expect(uri.toString(), 'https://cdn.example.com/route.usdz');
  });
}
