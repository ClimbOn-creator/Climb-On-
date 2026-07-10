import 'package:climb_on/models/climb_route.dart';
import 'package:climb_on/models/app_visuals.dart';
import 'package:climb_on/data/sample_crags.dart' as sample_data;
import 'package:climb_on/models/social.dart';
import 'package:climb_on/services/database_service.dart';
import 'package:climb_on/screens/settings_screen.dart';
import 'package:climb_on/state/admin_state.dart';
import 'package:climb_on/state/app_visuals_state.dart';
import 'package:climb_on/state/climb_log_state.dart';
import 'package:climb_on/state/social_state.dart';
import 'package:climb_on/utils/number_parser.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('Creator app pictures override catalogue defaults', () {
    const visuals = AppVisuals({
      'range_coast-range': 'https://example.com/coast.jpg',
    });

    expect(visuals.url('range_coast-range'), 'https://example.com/coast.jpg');
    expect(AppVisuals.defaults.url('side_banner_left'), startsWith('https://'));
  });

  testWidgets('Creator sees the app picture button in settings', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isMapAdminProvider.overrideWith((ref) async => true),
          appVisualsProvider.overrideWith((ref) async => AppVisuals.defaults),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Manage app pictures'), 250);

    expect(find.text('Manage app pictures'), findsOneWidget);
    expect(find.text('Creator tools'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('Top-rope-only routes have their own climbing type', () {
    const route = ClimbRoute(
      id: 'top-rope-only',
      name: 'Learning Wall',
      grade: '5.7',
      rating: 4,
      type: ClimbRouteType.topRope,
      topRope: true,
    );

    expect(route.typeLabel, 'Top Rope');
  });

  test('Deep Water Solo and Aid are available climbing types', () {
    const deepWaterSolo = ClimbRoute(
      id: 'ocean-line',
      name: 'Ocean Line',
      grade: '5.11a',
      rating: 4.5,
      type: ClimbRouteType.deepWaterSolo,
    );
    const aid = ClimbRoute(
      id: 'aid-line',
      name: 'Aid Line',
      grade: 'A2',
      rating: 4.0,
      type: ClimbRouteType.aid,
    );

    expect(deepWaterSolo.typeLabel, 'Deep Water Solo');
    expect(aid.typeLabel, 'Aid');
    expect(routeTypeValueLabel('deep_water_solo'), 'Deep Water Solo');
  });

  test('Measurement fields accept common units', () {
    expect(parseWholeNumberWithUnits('4m'), 4);
    expect(parseWholeNumberWithUnits('60 m'), 60);
    expect(parseNumberWithUnits('13.5 km'), 13.5);
    expect(parseNumberWithUnits('-123.3117'), -123.3117);
  });

  test('Chosslandia has a Main wall ready for route submissions', () {
    final crag = sample_data.crags.singleWhere(
      (item) => item.name == 'Chosslandia',
    );

    expect(crag.walls.single.name, 'Main');
    expect(crag.walls.single.routes, isEmpty);
  });

  test('Climb log toggles completed routes', () {
    final climbLog = ClimbLogState(persistenceEnabled: false);
    final route = ClimbRoute(
      id: 'vampire-in-the-sun',
      name: 'Vampire in the Sun',
      grade: '5.10a',
      rating: 4.9,
    );

    expect(climbLog.isCompleted(route), isFalse);
    expect(climbLog.sends, isEmpty);

    climbLog.toggleRoute(route);

    expect(climbLog.isCompleted(route), isTrue);
    expect(climbLog.sends.single.routeName, 'Vampire in the Sun');

    climbLog.toggleRoute(route);

    expect(climbLog.isCompleted(route), isFalse);
    expect(climbLog.sends, isEmpty);

    climbLog.dispose();
  });

  test(
    'Climb log merges completed routes from the signed-in account',
    () async {
      final database = _SendSyncDatabaseService();
      final climbLog = ClimbLogState(
        persistenceEnabled: false,
        databaseService: database,
      );
      const localRoute = ClimbRoute(
        id: 'local-route',
        name: 'Local Route',
        grade: 'V2',
        rating: 4,
      );

      climbLog.toggleRoute(localRoute);
      await climbLog.syncCompletedRoutes();

      expect(climbLog.sends.map((send) => send.routeId), {
        'local-route',
        'cloud-route',
      });
      expect(database.savedRouteIds, contains('local-route'));
      climbLog.dispose();
    },
  );

  test('Climb log stores feed action state', () async {
    final climbLog = ClimbLogState(persistenceEnabled: false);
    final route = ClimbRoute(
      id: 'moss-boss',
      name: 'Moss Boss',
      grade: 'V4',
      rating: 4.4,
    );

    climbLog.addAttempt(route, note: 'One-hang burn');
    climbLog.addGradeOpinion(route, 'V5');
    await climbLog.addComment(route, 'Left heel beta helped.');
    climbLog.addPhoto(
      route,
      url: 'https://example.com/moss-boss.jpg',
      caption: 'Crux rail',
    );
    climbLog.toggleProject(route);

    expect(climbLog.attemptsFor(route).single.note, 'One-hang burn');
    expect(climbLog.gradeOpinionsFor(route).single.suggestedGrade, 'V5');
    expect(climbLog.commentsFor(route).single.body, 'Left heel beta helped.');
    expect(climbLog.photosFor(route).single.caption, 'Crux rail');
    expect(climbLog.isProject(route), isTrue);

    climbLog.dispose();
  });

  test('Only a route picture creator can remove their picture', () async {
    final database = _PhotoDatabaseService();
    final climbLog = ClimbLogState(
      persistenceEnabled: false,
      databaseService: database,
    );
    final route = ClimbRoute(
      id: 'moss-boss',
      name: 'Moss Boss',
      grade: 'V4',
      rating: 4.4,
    );

    await climbLog.loadPhotosFor(route);
    final ownPhoto = climbLog.photosFor(route).first;
    final otherPhoto = climbLog.photosFor(route).last;

    expect(climbLog.canDeletePhoto(ownPhoto), isTrue);
    expect(climbLog.canDeletePhoto(otherPhoto), isFalse);
    await expectLater(climbLog.removePhoto(otherPhoto), throwsStateError);

    await climbLog.removePhoto(ownPhoto);
    expect(climbLog.photosFor(route), [otherPhoto]);
    expect(database.deletedPhotoIds, ['mine']);

    climbLog.dispose();
  });

  test('Cloud comments retain their author profile and timestamp', () {
    final createdAt = DateTime.utc(2026, 6, 28, 18, 30);
    final comment = LocalRouteComment.fromCloudJson(
      {
        'id': 'comment-1',
        'user_id': 'climber-1',
        'route_id': 'moss-boss',
        'parent_comment_id': 'parent-comment',
        'body': 'Great heel hook beta.',
        'created_at': createdAt.toIso8601String(),
      },
      {
        'username': 'rockstar',
        'display_name': 'Rock Star',
        'avatar_url': 'https://example.com/avatar.jpg',
        'bio': 'Victoria climber',
        'home_area': 'The Boulders',
      },
    );

    expect(comment, isNotNull);
    expect(comment!.userId, 'climber-1');
    expect(comment.authorUsername, 'rockstar');
    expect(comment.authorDisplayName, 'Rock Star');
    expect(comment.authorHomeArea, 'The Boulders');
    expect(comment.parentCommentId, 'parent-comment');
    expect(comment.createdAt, createdAt);
  });

  test('Route comments can reply to another comment', () async {
    final climbLog = ClimbLogState(persistenceEnabled: false);
    const route = ClimbRoute(
      id: 'threaded-route',
      name: 'Threaded Route',
      grade: '5.10a',
      rating: 4.2,
    );

    await climbLog.addComment(route, 'Does the crux stay dry?');
    final parent = climbLog.commentsFor(route).single;
    await climbLog.addComment(
      route,
      'Usually, unless the wind is from the south.',
      parentCommentId: parent.id,
    );

    final comments = climbLog.commentsFor(route);
    expect(parent.id, isNotEmpty);
    expect(comments.first.parentCommentId, parent.id);
    expect(comments.first.createdAt, isNotNull);
    climbLog.dispose();
  });

  test('Social state loads real friends, sends, and recent comments', () async {
    final database = _SocialDatabaseService();
    final social = SocialState(databaseService: database);

    await social.refresh();

    expect(social.friends.single.username, 'maya');
    expect(social.friendSends.single.routeId, 'moss-boss');
    expect(social.recentComments.single.body, 'Great movement.');
    expect(social.isFriend('maya-id'), isTrue);

    await social.removeFriend(social.friends.single);
    expect(database.removedFriendIds, ['maya-id']);
    social.dispose();
  });
}

class _PhotoDatabaseService extends DatabaseService {
  final deletedPhotoIds = <String>[];

  @override
  String? get currentUserId => 'current-user';

  @override
  bool get isConfigured => true;

  @override
  Future<List<LocalRoutePhoto>> loadPhotos(String routeId) async {
    final now = DateTime(2026, 6, 28);
    return [
      LocalRoutePhoto(
        id: 'mine',
        userId: 'current-user',
        routeId: routeId,
        url: 'https://example.com/mine.jpg',
        caption: 'Mine',
        createdAt: now,
      ),
      LocalRoutePhoto(
        id: 'theirs',
        userId: 'another-user',
        routeId: routeId,
        url: 'https://example.com/theirs.jpg',
        caption: 'Theirs',
        createdAt: now,
      ),
    ];
  }

  @override
  Future<void> deletePhoto(LocalRoutePhoto photo) async {
    deletedPhotoIds.add(photo.id);
  }
}

class _SendSyncDatabaseService extends DatabaseService {
  final savedRouteIds = <String>[];

  @override
  bool get isCloudReady => true;

  @override
  Future<void> saveCompletedRoute(Send send) async {
    savedRouteIds.add(send.routeId);
  }

  @override
  Future<List<Send>> loadCompletedRoutes() async {
    return [
      Send(
        routeId: 'cloud-route',
        routeName: 'Cloud Route',
        grade: '5.10a',
        style: 'Redpoint',
        sentAt: DateTime.utc(2026, 7, 1),
      ),
    ];
  }
}

class _SocialDatabaseService extends DatabaseService {
  final removedFriendIds = <String>[];

  static const maya = FriendProfile(
    id: 'maya-id',
    username: 'maya',
    displayName: 'Maya',
    avatarUrl: '',
    bio: 'Climber',
    homeArea: 'Victoria',
  );

  @override
  String? get currentUserId => 'current-user';

  @override
  Future<List<FriendProfile>> loadFriends() async => const [maya];

  @override
  Future<List<FriendSendActivity>> loadFriendSends() async => [
    FriendSendActivity(
      user: maya,
      routeId: 'moss-boss',
      grade: 'V4',
      style: 'Redpoint',
      sentAt: DateTime(2026, 6, 28),
    ),
  ];

  @override
  Future<List<UserRouteComment>> loadMyRecentComments() async => [
    UserRouteComment(
      id: 'comment-id',
      routeId: 'moss-boss',
      routeName: 'Moss Boss',
      body: 'Great movement.',
      createdAt: DateTime(2026, 6, 28),
    ),
  ];

  @override
  Future<void> removeFriend(String friendId) async {
    removedFriendIds.add(friendId);
  }
}
