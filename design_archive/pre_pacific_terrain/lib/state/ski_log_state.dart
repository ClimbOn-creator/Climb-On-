import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ski_route.dart';

final skiLogProvider = ChangeNotifierProvider<SkiLogState>((ref) {
  return SkiLogState();
});

class SkiSend {
  const SkiSend({
    required this.routeId,
    required this.routeName,
    required this.difficulty,
    required this.distanceKm,
    required this.elevationGainMeters,
    required this.completedAt,
  });

  final String routeId;
  final String routeName;
  final String difficulty;
  final double distanceKm;
  final int elevationGainMeters;
  final DateTime completedAt;

  Map<String, Object?> toJson() => {
    'routeId': routeId,
    'routeName': routeName,
    'difficulty': difficulty,
    'distanceKm': distanceKm,
    'elevationGainMeters': elevationGainMeters,
    'completedAt': completedAt.toIso8601String(),
  };

  static SkiSend? fromJson(Object? value) {
    if (value is! Map<String, Object?>) return null;
    final completedAt = DateTime.tryParse(
      value['completedAt']?.toString() ?? '',
    );
    if (completedAt == null) return null;

    return SkiSend(
      routeId: value['routeId']?.toString() ?? '',
      routeName: value['routeName']?.toString() ?? '',
      difficulty: value['difficulty']?.toString() ?? '',
      distanceKm: (value['distanceKm'] as num?)?.toDouble() ?? 0,
      elevationGainMeters: (value['elevationGainMeters'] as num?)?.toInt() ?? 0,
      completedAt: completedAt,
    );
  }
}

class SkiLogState extends ChangeNotifier {
  SkiLogState({this.preferences, this.persistenceEnabled = true}) {
    if (persistenceEnabled) {
      unawaited(_restore());
    }
  }

  static const _storageKey = 'climb_on_ski_log_v1';

  final SharedPreferences? preferences;
  final bool persistenceEnabled;
  final List<SkiSend> _sends = [];
  final Set<String> _completedTourIds = {};
  final Set<String> _projectTourIds = {};
  bool _disposed = false;

  List<SkiSend> get sends => List.unmodifiable(_sends);
  Set<String> get projectTourIds => Set.unmodifiable(_projectTourIds);

  bool isCompleted(SkiRoute route) => _completedTourIds.contains(route.id);
  bool isProject(SkiRoute route) => _projectTourIds.contains(route.id);

  void toggleTour(SkiRoute route) {
    if (_completedTourIds.contains(route.id)) {
      _completedTourIds.remove(route.id);
      _sends.removeWhere((send) => send.routeId == route.id);
    } else {
      _completedTourIds.add(route.id);
      _sends.insert(
        0,
        SkiSend(
          routeId: route.id,
          routeName: route.name,
          difficulty: route.difficulty,
          distanceKm: route.distanceKm,
          elevationGainMeters: route.elevationGainMeters,
          completedAt: DateTime.now(),
        ),
      );
    }

    unawaited(_persist());
    notifyListeners();
  }

  void toggleProject(SkiRoute route) {
    if (_projectTourIds.contains(route.id)) {
      _projectTourIds.remove(route.id);
    } else {
      _projectTourIds.add(route.id);
    }

    unawaited(_persist());
    notifyListeners();
  }

  Future<void> _restore() async {
    final store = preferences ?? await SharedPreferences.getInstance();
    final raw = store.getString(_storageKey);
    if (raw == null || raw.isEmpty) return;

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, Object?>) return;

    final sends = _jsonList(
      decoded['sends'],
    ).map(SkiSend.fromJson).whereType<SkiSend>().toList(growable: false);
    if (_disposed) return;

    _sends
      ..clear()
      ..addAll(sends);
    _completedTourIds
      ..clear()
      ..addAll(sends.map((send) => send.routeId));
    _projectTourIds
      ..clear()
      ..addAll(_jsonList(decoded['projectTourIds']).map((id) => '$id'));

    notifyListeners();
  }

  Future<void> _persist() async {
    if (!persistenceEnabled) return;

    final store = preferences ?? await SharedPreferences.getInstance();
    final encoded = jsonEncode({
      'sends': _sends.map((send) => send.toJson()).toList(),
      'projectTourIds': _projectTourIds.toList(),
    });
    await store.setString(_storageKey, encoded);
  }

  List<Object?> _jsonList(Object? value) {
    return value is List<Object?> ? value : const [];
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
