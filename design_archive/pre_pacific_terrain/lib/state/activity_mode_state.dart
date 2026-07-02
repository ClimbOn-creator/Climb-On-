import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ActivityMode { climb, ski }

final activityModeProvider = StateProvider<ActivityMode>((ref) {
  return ActivityMode.climb;
});

extension ActivityModeLabels on ActivityMode {
  String get label {
    return switch (this) {
      ActivityMode.climb => 'Climb',
      ActivityMode.ski => 'Ski',
    };
  }
}
