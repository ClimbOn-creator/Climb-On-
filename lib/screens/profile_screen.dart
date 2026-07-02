import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../models/climb_route.dart';
import '../models/crag.dart';
import '../models/ski_route.dart';
import '../models/user_profile.dart';
import '../models/social.dart';
import '../services/auth_service.dart';
import '../state/activity_mode_state.dart';
import '../state/catalog_state.dart';
import '../state/climb_log_state.dart';
import '../state/profile_state.dart';
import '../state/ski_log_state.dart';
import '../state/ski_route_state.dart';
import '../state/social_state.dart';
import '../theme/climb_on_theme.dart';
import '../widgets/native_ad_card.dart';
import '../widgets/side_banner_layout.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final authService = const AuthService();
  bool publicProfile = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(socialProvider).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogProvider);
    final mode = ref.watch(activityModeProvider);
    final catalogCrags = catalog.valueOrNull ?? const <Crag>[];
    final allRoutes = [
      for (final crag in catalogCrags)
        for (final wall in crag.walls) ...wall.routes,
    ];
    final climbLog = ref.watch(climbLogProvider);
    final skiLog = ref.watch(skiLogProvider);
    final skiRoutes =
        ref.watch(skiRouteCatalogProvider).valueOrNull ?? const <SkiRoute>[];
    final social = ref.watch(socialProvider);
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final user = authService.currentUser;
    final signedIn = user != null;
    final desktop = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SideBannerLayout(
        maxContentWidth: 980,
        child: mode == ActivityMode.ski
            ? _SkiProfileBody(
                authService: authService,
                publicProfile: publicProfile,
                onPrivacyChanged: (value) {
                  setState(() => publicProfile = value);
                },
                skiLog: skiLog,
                skiRoutes: skiRoutes,
                profile: profile,
                user: user,
                onAuthChanged: () => setState(() {}),
              )
            : AnimatedBuilder(
                animation: climbLog,
                builder: (context, _) {
                  final completedRoutes = _completedRoutes(climbLog, allRoutes);
                  final projectRoutes = _projectRoutes(climbLog, allRoutes);
                  final hardestBoulder = _hardestBoulderSend(completedRoutes);
                  final hardestSport = _hardestSportSend(completedRoutes);
                  final boulderProgression = _gradeProgression(
                    climbLog.sends,
                    allRoutes,
                    boulder: true,
                  );
                  final sportProgression = _gradeProgression(
                    climbLog.sends,
                    allRoutes,
                    boulder: false,
                  );
                  final climbedAreas = _climbedAreas(
                    completedRoutes,
                    catalogCrags,
                  );
                  return _ProfileDataScope(
                    profile: profile,
                    user: user,
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        desktop ? 28 : 16,
                        desktop ? 30 : 22,
                        desktop ? 28 : 16,
                        40,
                      ),
                      children: [
                        if (!signedIn) ...[
                          _AccountCard(
                            authService: authService,
                            publicProfile: publicProfile,
                            onPrivacyChanged: (value) {
                              setState(() => publicProfile = value);
                            },
                            onAuthChanged: () => setState(() {}),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (catalog.isLoading)
                          const LinearProgressIndicator(minHeight: 3),
                        if (catalog.hasError)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: Text(
                              'Using saved route data while the cloud reconnects.',
                            ),
                          ),
                        _ProfileHeader(
                          completedCount: completedRoutes.length,
                          projectCount: projectRoutes.length,
                          areaCount: climbedAreas.length,
                        ),
                        const SizedBox(height: 16),
                        NativeAdCard(mode: mode, compact: !desktop),
                        if (desktop)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _BestSendsPanel(
                                  hardestBoulder: hardestBoulder,
                                  hardestSport: hardestSport,
                                  completedCount: completedRoutes.length,
                                  projectCount: projectRoutes.length,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  children: [
                                    _SectionCard(
                                      title: 'Bouldering progression',
                                      child: _GradeProgressChart(
                                        points: boulderProgression,
                                        emptyText:
                                            'Send boulders to chart your grade progression.',
                                      ),
                                    ),
                                    _SectionCard(
                                      title: 'Sport progression',
                                      child: _GradeProgressChart(
                                        points: sportProgression,
                                        emptyText:
                                            'Send sport climbs to chart your grade progression.',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        else ...[
                          _BestSendsPanel(
                            hardestBoulder: hardestBoulder,
                            hardestSport: hardestSport,
                            completedCount: completedRoutes.length,
                            projectCount: projectRoutes.length,
                          ),
                          _SectionCard(
                            title: 'Bouldering progression',
                            child: _GradeProgressChart(
                              points: boulderProgression,
                              emptyText:
                                  'Send boulders to chart your grade progression.',
                            ),
                          ),
                          _SectionCard(
                            title: 'Sport progression',
                            child: _GradeProgressChart(
                              points: sportProgression,
                              emptyText:
                                  'Send sport climbs to chart your grade progression.',
                            ),
                          ),
                        ],
                        _SectionCard(
                          title: 'Map of areas climbed',
                          child: climbedAreas.isEmpty
                              ? const _EmptyProfileState(
                                  text: 'Areas appear after your first send.',
                                )
                              : Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final area in climbedAreas)
                                      Chip(
                                        avatar: const Icon(
                                          Icons.place,
                                          size: 16,
                                        ),
                                        label: Text(
                                          '${area.name}, ${area.region}',
                                        ),
                                      ),
                                  ],
                                ),
                        ),
                        _SectionCard(
                          title: 'Completed routes',
                          child: completedRoutes.isEmpty
                              ? const _EmptyProfileState(
                                  text: 'Mark routes as sent from the feed.',
                                )
                              : _RouteList(routes: completedRoutes),
                        ),
                        if (signedIn)
                          _SectionCard(
                            title: 'Recent comments',
                            child:
                                social.loading && social.recentComments.isEmpty
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : social.recentComments.isEmpty
                                ? const _EmptyProfileState(
                                    text:
                                        'Comments you make on routes will appear here.',
                                  )
                                : Column(
                                    children: [
                                      for (final comment
                                          in social.recentComments.take(6))
                                        _RecentCommentTile(
                                          comment: comment,
                                          onTap: () => _openCommentRoute(
                                            comment.routeId,
                                            allRoutes,
                                          ),
                                        ),
                                    ],
                                  ),
                          ),
                        if (signedIn)
                          _AccountCard(
                            authService: authService,
                            publicProfile: publicProfile,
                            onPrivacyChanged: (value) {
                              setState(() => publicProfile = value);
                            },
                            onAuthChanged: () => setState(() {}),
                          ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  void _openCommentRoute(String routeId, List<ClimbRoute> routes) {
    ClimbRoute? selected;
    for (final route in routes) {
      if (route.id == routeId) selected = route;
    }
    if (selected == null) return;
    ref.read(focusedRouteProvider.notifier).state = selected;
    context.go('/feed');
  }

  List<ClimbRoute> _completedRoutes(
    ClimbLogState climbLog,
    List<ClimbRoute> allRoutes,
  ) {
    final routeIds = climbLog.sends.map((send) => send.routeId).toSet();
    return allRoutes.where((route) => routeIds.contains(route.id)).toList();
  }

  List<ClimbRoute> _projectRoutes(
    ClimbLogState climbLog,
    List<ClimbRoute> allRoutes,
  ) {
    return allRoutes
        .where((route) => climbLog.projectRouteIds.contains(route.id))
        .toList();
  }

  ClimbRoute? _hardestBoulderSend(List<ClimbRoute> routes) {
    final boulders = routes.where(_isBoulder).toList();
    return _hardestSend(boulders);
  }

  ClimbRoute? _hardestSportSend(List<ClimbRoute> routes) {
    final sportRoutes = routes.where(_isSport).toList();
    return _hardestSend(sportRoutes);
  }

  bool _isBoulder(ClimbRoute route) {
    return route.type == ClimbRouteType.boulder ||
        route.pitchType == PitchType.boulder ||
        route.grade.toUpperCase().startsWith('V');
  }

  bool _isSport(ClimbRoute route) {
    return !_isBoulder(route) && route.type == ClimbRouteType.sport;
  }

  ClimbRoute? _hardestSend(List<ClimbRoute> routes) {
    if (routes.isEmpty) return null;
    final sorted = [...routes]
      ..sort((a, b) {
        return _gradeScore(b.grade).compareTo(_gradeScore(a.grade));
      });
    return sorted.first;
  }

  List<_GradeProgressPoint> _gradeProgression(
    List<Send> sends,
    List<ClimbRoute> routes, {
    required bool boulder,
  }) {
    final routesById = {for (final route in routes) route.id: route};
    final ordered = sends.where((send) {
      final route = routesById[send.routeId];
      if (route == null) return false;
      return boulder ? _isBoulder(route) : _isSport(route);
    }).toList()..sort((a, b) => a.sentAt.compareTo(b.sentAt));

    var bestScore = -1;
    var bestGrade = '';
    final points = <_GradeProgressPoint>[];
    for (final send in ordered) {
      final score = _gradeScore(send.grade);
      if (score > bestScore) {
        bestScore = score;
        bestGrade = send.grade;
      }
      points.add(
        _GradeProgressPoint(
          date: send.sentAt,
          grade: bestGrade,
          score: bestScore,
        ),
      );
    }
    return points;
  }

  List<Crag> _climbedAreas(List<ClimbRoute> routes, List<Crag> catalogCrags) {
    final routeIds = routes.map((route) => route.id).toSet();
    return catalogCrags.where((crag) {
      return crag.walls.any((wall) {
        return wall.routes.any((route) => routeIds.contains(route.id));
      });
    }).toList();
  }

  int _gradeScore(String grade) {
    if (grade.startsWith('V')) {
      return 1000 + (int.tryParse(grade.replaceAll(RegExp('[^0-9]'), '')) ?? 0);
    }

    final match = RegExp(r'5\.(\d+)([abcd+-]?)').firstMatch(grade);
    if (match == null) return 0;

    final number = int.tryParse(match.group(1) ?? '') ?? 0;
    final suffix = match.group(2) ?? '';
    const suffixScores = {
      '-': 0,
      '': 1,
      '+': 2,
      'a': 1,
      'b': 2,
      'c': 3,
      'd': 4,
    };
    return number * 10 + (suffixScores[suffix] ?? 0);
  }
}

class _RecentCommentTile extends StatelessWidget {
  const _RecentCommentTile({required this.comment, required this.onTap});

  final UserRouteComment comment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(child: Icon(Icons.comment_outlined)),
      title: Text(comment.routeName),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(comment.body, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          Text(
            _profileActivityTime(comment.createdAt),
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

String _profileActivityTime(DateTime dateTime) {
  final local = dateTime.toLocal();
  final elapsed = DateTime.now().difference(local);
  if (elapsed.inMinutes < 1) return 'Just now';
  if (elapsed.inHours < 1) return '${elapsed.inMinutes}m ago';
  if (elapsed.inDays < 1) return '${elapsed.inHours}h ago';
  if (elapsed.inDays < 7) return '${elapsed.inDays}d ago';
  return '${local.month}/${local.day}/${local.year}';
}

class _SkiProfileBody extends StatelessWidget {
  const _SkiProfileBody({
    required this.authService,
    required this.publicProfile,
    required this.onPrivacyChanged,
    required this.skiLog,
    required this.skiRoutes,
    required this.profile,
    required this.user,
    required this.onAuthChanged,
  });

  final AuthService authService;
  final bool publicProfile;
  final ValueChanged<bool> onPrivacyChanged;
  final SkiLogState skiLog;
  final List<SkiRoute> skiRoutes;
  final UserProfile? profile;
  final User? user;
  final VoidCallback onAuthChanged;

  @override
  Widget build(BuildContext context) {
    final completedTours = _completedTours(skiLog, skiRoutes);
    final savedTours = _savedTours(skiLog, skiRoutes);
    final totalDistance = skiLog.sends.fold<double>(
      0,
      (total, send) => total + send.distanceKm,
    );
    final totalGain = skiLog.sends.fold<int>(
      0,
      (total, send) => total + send.elevationGainMeters,
    );
    final terrainTypes = completedTours
        .map((route) => route.avalancheTerrain)
        .toSet()
        .toList(growable: false);
    final aspects = completedTours
        .map((route) => route.aspect)
        .toSet()
        .toList(growable: false);
    final signedIn = user != null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (!signedIn) ...[
          _AccountCard(
            authService: authService,
            publicProfile: publicProfile,
            onPrivacyChanged: onPrivacyChanged,
            onAuthChanged: onAuthChanged,
          ),
          const SizedBox(height: 16),
        ],
        _SkiProfileHeader(
          skiDays: skiLog.sends.length,
          savedCount: savedTours.length,
          lastTour: skiLog.sends.isEmpty ? '-' : skiLog.sends.first.routeName,
          profile: profile,
          user: user,
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Ski season',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _StatTile(label: 'Ski days', value: '${skiLog.sends.length}'),
              _StatTile(
                label: 'Distance',
                value: '${totalDistance.toStringAsFixed(1)} km',
              ),
              _StatTile(label: 'Vert', value: '$totalGain m'),
              _StatTile(label: 'Saved', value: '${savedTours.length}'),
            ],
          ),
        ),
        _SectionCard(
          title: 'Recent ski routes',
          child: skiLog.sends.isEmpty
              ? const _EmptyProfileState(
                  text: 'Mark ski tours completed from the feed.',
                )
              : _SkiRecentActivity(sends: skiLog.sends),
        ),
        _SectionCard(
          title: 'Terrain you ski',
          child: terrainTypes.isEmpty
              ? const _EmptyProfileState(
                  text: 'Terrain types appear after your first ski day.',
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final terrain in terrainTypes)
                      Chip(
                        avatar: const Icon(Icons.terrain, size: 16),
                        label: Text(terrain),
                      ),
                  ],
                ),
        ),
        _SectionCard(
          title: 'Aspects skied',
          child: aspects.isEmpty
              ? const _EmptyProfileState(
                  text: 'Aspects appear from completed ski tours.',
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final aspect in aspects)
                      Chip(
                        avatar: const Icon(Icons.explore, size: 16),
                        label: Text(aspect),
                      ),
                  ],
                ),
        ),
        _SectionCard(
          title: 'Map of areas toured',
          child: completedTours.isEmpty
              ? const _EmptyProfileState(
                  text: 'Tour areas appear after your first ski day.',
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final route in completedTours)
                      Chip(
                        avatar: const Icon(Icons.place, size: 16),
                        label: Text('${route.area}, ${route.region}'),
                      ),
                  ],
                ),
        ),
        _SectionCard(
          title: 'Saved objectives',
          child: savedTours.isEmpty
              ? const _EmptyProfileState(
                  text: 'Save ski objectives from the feed.',
                )
              : _SkiRouteList(routes: savedTours),
        ),
        if (signedIn)
          _AccountCard(
            authService: authService,
            publicProfile: publicProfile,
            onPrivacyChanged: onPrivacyChanged,
            onAuthChanged: onAuthChanged,
          ),
      ],
    );
  }

  List<SkiRoute> _completedTours(SkiLogState skiLog, List<SkiRoute> routes) {
    final ids = skiLog.sends.map((send) => send.routeId).toSet();
    return routes.where((route) => ids.contains(route.id)).toList();
  }

  List<SkiRoute> _savedTours(SkiLogState skiLog, List<SkiRoute> routes) {
    return routes
        .where((route) => skiLog.projectTourIds.contains(route.id))
        .toList();
  }
}

class _AccountCard extends ConsumerWidget {
  const _AccountCard({
    required this.authService,
    required this.publicProfile,
    required this.onPrivacyChanged,
    required this.onAuthChanged,
  });

  final AuthService authService;
  final bool publicProfile;
  final ValueChanged<bool> onPrivacyChanged;
  final VoidCallback onAuthChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!authService.isConfigured) {
      return _SectionCard(
        title: 'Account',
        child: Text(
          'Google sign-in is ready in code. ${SupabaseConfig.setupMessage}',
        ),
      );
    }

    return StreamBuilder<AuthState>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        final user = authService.currentUser;
        final signedIn = user != null;
        final profile = ref.watch(currentProfileProvider).valueOrNull;
        final profileComplete = profile?.isComplete == true;
        final accountLabel = signedIn
            ? (profile?.username.isNotEmpty == true
                  ? '@${profile!.username}'
                  : user.email ??
                        user.userMetadata?['full_name']?.toString() ??
                        'Signed in')
            : 'Save your logbook with Google.';

        return _SectionCard(
          title: signedIn ? 'Signed in' : 'Account',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (signedIn)
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundImage: _avatarFor(profile, user) == null
                          ? null
                          : NetworkImage(_avatarFor(profile, user)!),
                      child: _avatarFor(profile, user) == null
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(accountLabel)),
                  ],
                )
              else
                Text(accountLabel),
              const SizedBox(height: 12),
              if (!signedIn)
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () async {
                          try {
                            await authService.signInWithGoogle(
                              redirectPath: '/profile/setup',
                            );
                          } on AuthException catch (error) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(error.message)),
                            );
                          }
                        },
                        icon: const Icon(Icons.login),
                        label: const Text('Continue with Google'),
                      ),
                    ),
                  ],
                ),
              if (signedIn) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => context.go('/profile/setup'),
                      icon: Icon(
                        profileComplete ? Icons.edit : Icons.person_add,
                      ),
                      label: Text(
                        profileComplete ? 'Edit profile' : 'Finish profile',
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        try {
                          await authService.signOut();
                          ref.invalidate(currentProfileProvider);
                          onAuthChanged();
                        } on AuthException catch (error) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(error.message)),
                          );
                        }
                      },
                      icon: const Icon(Icons.logout),
                      label: const Text('Sign out'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Public profile'),
                  subtitle: Text(
                    profileComplete
                        ? (profile!.isPublic ? 'Visible to others' : 'Private')
                        : (publicProfile ? 'Visible to friends' : 'Private'),
                  ),
                  value: profileComplete ? profile!.isPublic : publicProfile,
                  onChanged: profileComplete ? null : onPrivacyChanged,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String? _avatarFor(UserProfile? profile, User user) {
    final profileAvatar = profile?.avatarUrl;
    if (profileAvatar != null && profileAvatar.isNotEmpty) {
      return profileAvatar;
    }
    final googleAvatar = user.userMetadata?['avatar_url']?.toString();
    return googleAvatar == null || googleAvatar.isEmpty ? null : googleAvatar;
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.completedCount,
    required this.projectCount,
    required this.areaCount,
  });

  final int completedCount;
  final int projectCount;
  final int areaCount;

  @override
  Widget build(BuildContext context) {
    final profile = context
        .dependOnInheritedWidgetOfExactType<_ProfileDataScope>()
        ?.profile;
    final user = context
        .dependOnInheritedWidgetOfExactType<_ProfileDataScope>()
        ?.user;
    final avatarUrl =
        profile?.avatarUrl ?? user?.userMetadata?['avatar_url']?.toString();
    final displayName = profile?.username.isNotEmpty == true
        ? '@${profile!.username}'
        : profile?.displayName.isNotEmpty == true
        ? profile!.displayName
        : user?.userMetadata?['full_name']?.toString() ?? 'Climber';
    final subtitle = [
      if (profile?.displayName.isNotEmpty == true) profile!.displayName,
      if (profile?.homeArea.isNotEmpty == true) profile!.homeArea,
      if (profile?.bio.isNotEmpty == true) profile!.bio,
    ].join(' - ');

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [PacificTerrainColors.navy, PacificTerrainColors.navySoft],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24112D3B),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              'FIELD LOG · 2026',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: PacificTerrainColors.sand,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: PacificTerrainColors.seaGlass,
                  backgroundImage: avatarUrl == null || avatarUrl.isEmpty
                      ? null
                      : NetworkImage(avatarUrl),
                  child: avatarUrl == null || avatarUrl.isEmpty
                      ? const Icon(Icons.person, size: 42)
                      : null,
                ),
                if (user != null)
                  Positioned(
                    right: -6,
                    bottom: -6,
                    child: IconButton.filled(
                      tooltip: 'Edit profile picture',
                      onPressed: () => context.go('/profile/setup'),
                      icon: const Icon(Icons.photo_camera_outlined),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              displayName,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle.isEmpty ? 'Your outdoor logbook' : subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _ProfileHeroStat(label: 'SENDS', value: '$completedCount'),
                  _ProfileHeroStat(label: 'PROJECTS', value: '$projectCount'),
                  _ProfileHeroStat(label: 'AREAS', value: '$areaCount'),
                ],
              ),
            ),
            if (user != null) ...[
              const SizedBox(height: 6),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                ),
                onPressed: () => context.go('/profile/setup'),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit username and profile'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfileHeroStat extends StatelessWidget {
  const _ProfileHeroStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(color: Colors.white),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Colors.white60,
            fontSize: 9,
            letterSpacing: 1.1,
          ),
        ),
      ],
    );
  }
}

class _BestSendsPanel extends StatelessWidget {
  const _BestSendsPanel({
    required this.hardestBoulder,
    required this.hardestSport,
    required this.completedCount,
    required this.projectCount,
  });

  final ClimbRoute? hardestBoulder;
  final ClimbRoute? hardestSport;
  final int completedCount;
  final int projectCount;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Best sends',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _BestSendTile(
                icon: Icons.landscape_outlined,
                label: 'Best boulder',
                route: hardestBoulder,
              ),
              _BestSendTile(
                icon: Icons.bolt,
                label: 'Best sport climb',
                route: hardestSport,
              ),
            ],
          ),
          const Divider(height: 28),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _StatTile(label: 'Completed', value: '$completedCount'),
              _StatTile(label: 'Projects', value: '$projectCount'),
            ],
          ),
        ],
      ),
    );
  }
}

class _BestSendTile extends StatelessWidget {
  const _BestSendTile({
    required this.icon,
    required this.label,
    required this.route,
  });

  final IconData icon;
  final String label;
  final ClimbRoute? route;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      constraints: const BoxConstraints(minHeight: 126),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PacificTerrainColors.seaGlass.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PacificTerrainColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 26),
          const SizedBox(height: 9),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            route?.grade ?? '-',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          Text(
            route?.name ?? 'No sends yet',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ProfileDataScope extends InheritedWidget {
  const _ProfileDataScope({
    required this.profile,
    required this.user,
    required super.child,
  });

  final UserProfile? profile;
  final User? user;

  @override
  bool updateShouldNotify(_ProfileDataScope oldWidget) {
    return profile != oldWidget.profile || user != oldWidget.user;
  }
}

class _SkiProfileHeader extends StatelessWidget {
  const _SkiProfileHeader({
    required this.skiDays,
    required this.savedCount,
    required this.lastTour,
    required this.profile,
    required this.user,
  });

  final int skiDays;
  final int savedCount;
  final String lastTour;
  final UserProfile? profile;
  final User? user;

  @override
  Widget build(BuildContext context) {
    final avatarUrl =
        profile?.avatarUrl ?? user?.userMetadata?['avatar_url']?.toString();
    final profileName = profile?.username.isNotEmpty == true
        ? '@${profile!.username}'
        : profile?.displayName.isNotEmpty == true
        ? profile!.displayName
        : user?.userMetadata?['full_name']?.toString() ?? 'Climber';
    final subtitle = [
      if (profile?.displayName.isNotEmpty == true) profile!.displayName,
      if (profile?.homeArea.isNotEmpty == true) profile!.homeArea,
      if (profile?.bio.isNotEmpty == true) profile!.bio,
    ].join(' - ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundImage: avatarUrl == null || avatarUrl.isEmpty
                      ? null
                      : NetworkImage(avatarUrl),
                  child: avatarUrl == null || avatarUrl.isEmpty
                      ? const Icon(Icons.person, size: 42)
                      : null,
                ),
                if (user != null)
                  Positioned(
                    right: -6,
                    bottom: -6,
                    child: IconButton.filled(
                      tooltip: 'Edit profile picture',
                      onPressed: () => context.go('/profile/setup'),
                      icon: const Icon(Icons.photo_camera_outlined),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              profileName,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle.isEmpty ? 'Your outdoor logbook' : subtitle,
              textAlign: TextAlign.center,
            ),
            if (user != null) ...[
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: () => context.go('/profile/setup'),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit username and profile'),
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                _StatTile(label: 'Ski days', value: '$skiDays'),
                _StatTile(label: 'Saved', value: '$savedCount'),
                _StatTile(label: 'Last tour', value: lastTour),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SizedBox(
        width: 104,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 3),
              Text(label, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class _GradeProgressPoint {
  const _GradeProgressPoint({
    required this.date,
    required this.grade,
    required this.score,
  });

  final DateTime date;
  final String grade;
  final int score;
}

class _GradeProgressChart extends StatelessWidget {
  const _GradeProgressChart({required this.points, required this.emptyText});

  final List<_GradeProgressPoint> points;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return _EmptyProfileState(text: emptyText);
    }
    final first = points.first;
    final latest = points.last;
    final dateStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  latest.grade,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                Text('CURRENT HIGH', style: dateStyle),
              ],
            ),
            const Spacer(),
            Text(
              '${points.length} logged ${points.length == 1 ? 'send' : 'sends'}',
              style: dateStyle,
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 170,
          width: double.infinity,
          child: CustomPaint(
            painter: _GradeLinePainter(
              points: points,
              accent: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(_chartDate(first.date), style: dateStyle),
            const Spacer(),
            Text(_chartDate(latest.date), style: dateStyle),
          ],
        ),
      ],
    );
  }
}

String _chartDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.year}';
}

class _GradeLinePainter extends CustomPainter {
  const _GradeLinePainter({required this.points, required this.accent});

  final List<_GradeProgressPoint> points;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 8.0;
    final chart = Rect.fromLTRB(
      inset,
      inset,
      size.width - inset,
      size.height - inset,
    );
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    for (var line = 0; line <= 4; line++) {
      final y = chart.top + chart.height * line / 4;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), grid);
    }

    var minScore = points.first.score;
    var maxScore = points.first.score;
    for (final point in points.skip(1)) {
      if (point.score < minScore) minScore = point.score;
      if (point.score > maxScore) maxScore = point.score;
    }
    if (minScore == maxScore) {
      minScore -= 1;
      maxScore += 1;
    }

    Offset offsetFor(int index) {
      final x = points.length == 1
          ? chart.center.dx
          : chart.left + chart.width * index / (points.length - 1);
      final normalized =
          (points[index].score - minScore) / (maxScore - minScore);
      return Offset(x, chart.bottom - chart.height * normalized);
    }

    final linePath = Path();
    for (var index = 0; index < points.length; index++) {
      final point = offsetFor(index);
      if (index == 0) {
        linePath.moveTo(point.dx, point.dy);
      } else {
        linePath.lineTo(point.dx, point.dy);
      }
    }
    final fillPath = Path.from(linePath)
      ..lineTo(offsetFor(points.length - 1).dx, chart.bottom)
      ..lineTo(offsetFor(0).dx, chart.bottom)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [accent.withValues(alpha: 0.22), Colors.transparent],
        ).createShader(chart),
    );
    canvas.drawPath(
      linePath,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    for (var index = 0; index < points.length; index++) {
      canvas.drawCircle(offsetFor(index), 4, Paint()..color = accent);
      canvas.drawCircle(
        offsetFor(index),
        2,
        Paint()..color = PacificTerrainColors.navy,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GradeLinePainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.accent != accent;
  }
}

class _RouteList extends StatelessWidget {
  const _RouteList({required this.routes});

  final List<ClimbRoute> routes;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final route in routes)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.route),
            title: Text(route.name),
            subtitle: Text('${route.grade} - ${route.typeLabel}'),
          ),
      ],
    );
  }
}

class _SkiRecentActivity extends StatelessWidget {
  const _SkiRecentActivity({required this.sends});

  final List<SkiSend> sends;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final send in sends.take(6))
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.downhill_skiing),
            title: Text(send.routeName),
            subtitle: Text(
              '${send.distanceKm.toStringAsFixed(1)} km - '
              '${send.elevationGainMeters} m gain - ${send.difficulty}',
            ),
          ),
      ],
    );
  }
}

class _SkiRouteList extends StatelessWidget {
  const _SkiRouteList({required this.routes});

  final List<SkiRoute> routes;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final route in routes)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.ac_unit),
            title: Text(route.name),
            subtitle: Text(
              '${route.area} - ${route.distanceKm} km - ${route.difficulty}',
            ),
          ),
      ],
    );
  }
}

class _EmptyProfileState extends StatelessWidget {
  const _EmptyProfileState({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.bodyMedium);
  }
}
