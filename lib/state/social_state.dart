import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/social.dart';
import '../services/database_service.dart';

final socialProvider = ChangeNotifierProvider<SocialState>((ref) {
  return SocialState()..refresh();
});

class SocialState extends ChangeNotifier {
  SocialState({this.databaseService = const DatabaseService()});

  final DatabaseService databaseService;
  List<FriendProfile> friends = const [];
  List<FriendSendActivity> friendSends = const [];
  List<UserRouteComment> recentComments = const [];
  bool loading = false;
  bool _disposed = false;

  bool get signedIn => databaseService.currentUserId != null;

  Future<void> refresh() async {
    if (loading) return;
    if (!signedIn) {
      friends = const [];
      friendSends = const [];
      recentComments = const [];
      notifyListeners();
      return;
    }

    loading = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        databaseService.loadFriends(),
        databaseService.loadFriendSends(),
        databaseService.loadMyRecentComments(),
      ]);
      friends = results[0] as List<FriendProfile>;
      friendSends = results[1] as List<FriendSendActivity>;
      recentComments = results[2] as List<UserRouteComment>;
    } catch (_) {
      // Keep the last successful social feed while reconnecting.
    } finally {
      loading = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<List<FriendProfile>> search(String query) {
    return databaseService.searchClimbers(query);
  }

  bool isFriend(String userId) {
    return friends.any((friend) => friend.id == userId);
  }

  Future<void> addFriend(FriendProfile profile) async {
    await databaseService.addFriend(profile.id);
    await refresh();
  }

  Future<void> removeFriend(FriendProfile profile) async {
    await databaseService.removeFriend(profile.id);
    await refresh();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
