import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_profile.dart';
import '../services/profile_service.dart';

final currentProfileProvider = FutureProvider<UserProfile?>((ref) {
  return const ProfileService().loadCurrentProfile();
});
