import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/saved_trail.dart';

const _trailLibraryKey = 'climb_on_trail_library_v1';

final trailLibraryProvider = ChangeNotifierProvider<TrailLibraryState>((ref) {
  return TrailLibraryState()..load();
});

final selectedLibraryTrailProvider = StateProvider<SavedTrail?>((ref) => null);

class TrailLibraryState extends ChangeNotifier {
  List<SavedTrail> _trails = const [];
  bool _loaded = false;

  List<SavedTrail> get trails => _trails;
  bool get loaded => _loaded;
  int get nextColorValue => savedTrailColorFor(_trails.length);

  Future<void> load() async {
    final store = await SharedPreferences.getInstance();
    final raw = store.getString(_trailLibraryKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        _trails = (jsonDecode(raw) as List)
            .whereType<Map>()
            .map((item) => SavedTrail.fromJson(Map<String, Object?>.from(item)))
            .where((trail) => trail.id.isNotEmpty && trail.points.length >= 2)
            .toList(growable: false);
      } catch (_) {
        _trails = const [];
      }
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> add(SavedTrail trail) async {
    _trails = [trail, ..._trails];
    notifyListeners();
    await _persist();
  }

  Future<void> remove(String id) async {
    _trails = _trails.where((trail) => trail.id != id).toList(growable: false);
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    final store = await SharedPreferences.getInstance();
    await store.setString(
      _trailLibraryKey,
      jsonEncode([for (final trail in _trails) trail.toJson()]),
    );
  }
}
