import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../data/sample_ski_routes.dart';
import '../models/climb_route.dart';
import '../models/crag.dart';
import '../models/ski_route.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../state/activity_mode_state.dart';
import '../state/catalog_state.dart';
import '../state/climb_log_state.dart';
import '../state/profile_state.dart';
import '../state/ski_log_state.dart';
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
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final user = authService.currentUser;
    final signedIn = user != null;
    final showTitleBar = MediaQuery.sizeOf(context).width >= 1024;

    return Scaffold(
      appBar: showTitleBar ? AppBar(title: const Text('Profile')) : null,
      body: SideBannerLayout(
        child: mode == ActivityMode.ski
            ? _SkiProfileBody(
                authService: authService,
                publicProfile: publicProfile,
                onPrivacyChanged: (value) {
                  setState(() => publicProfile = value);
                },
                skiLog: skiLog,
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
                  final pyramid = _gradePyramid(completedRoutes);
                  final climbedAreas = _climbedAreas(
                    completedRoutes,
                    catalogCrags,
                  );
                  return _ProfileDataScope(
                    profile: profile,
                    user: user,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
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
                          sendCount: completedRoutes.length,
                          projectCount: projectRoutes.length,
                        ),
                        const SizedBox(height: 16),
                        _SectionCard(
                          title: 'Best sends',
                          child: Wrap(
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
                        ),
                        _SectionCard(
                          title: 'Progress',
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _StatTile(
                                label: 'Completed',
                                value: '${completedRoutes.length}',
                              ),
                              _StatTile(
                                label: 'Projects',
                                value: '${projectRoutes.length}',
                              ),
                              _StatTile(
                                label: 'Attempts',
                                value: '${climbLog.attempts.length}',
                              ),
                            ],
                          ),
                        ),
                        _SectionCard(
                          title: 'Grade pyramid',
                          child: pyramid.isEmpty
                              ? const _EmptyProfileState(
                                  text: 'Send routes to build your pyramid.',
                                )
                              : Column(
                                  children: [
                                    for (final entry in pyramid.entries)
                                      _PyramidRow(
                                        grade: entry.key,
                                        count: entry.value,
                                        maxCount: pyramid.values.reduce(
                                          (a, b) => a > b ? a : b,
                                        ),
                                      ),
                                  ],
                                ),
                        ),
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
                          title: 'Recent activity',
                          child: _RecentActivity(
                            sends: climbLog.sends,
                            attempts: climbLog.attempts,
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
                        _SectionCard(
                          title: 'Tick list',
                          child: projectRoutes.isEmpty
                              ? const _EmptyProfileState(
                                  text:
                                      'Save routes to projects from the feed.',
                                )
                              : _RouteList(routes: projectRoutes),
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
    final boulders = routes
        .where(
          (route) =>
              route.type == ClimbRouteType.boulder ||
              route.pitchType == PitchType.boulder ||
              route.grade.toUpperCase().startsWith('V'),
        )
        .toList();
    return _hardestSend(boulders);
  }

  ClimbRoute? _hardestSportSend(List<ClimbRoute> routes) {
    final sportRoutes = routes
        .where(
          (route) =>
              route.type == ClimbRouteType.sport ||
              route.grade.startsWith('5.'),
        )
        .toList();
    return _hardestSend(sportRoutes);
  }

  ClimbRoute? _hardestSend(List<ClimbRoute> routes) {
    if (routes.isEmpty) return null;
    final sorted = [...routes]
      ..sort((a, b) {
        return _gradeScore(b.grade).compareTo(_gradeScore(a.grade));
      });
    return sorted.first;
  }

  Map<String, int> _gradePyramid(List<ClimbRoute> routes) {
    final counts = <String, int>{};
    for (final route in routes) {
      counts.update(route.grade, (count) => count + 1, ifAbsent: () => 1);
    }

    final entries = counts.entries.toList()
      ..sort((a, b) => _gradeScore(b.key).compareTo(_gradeScore(a.key)));
    return Map.fromEntries(entries);
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

class _SkiProfileBody extends StatelessWidget {
  const _SkiProfileBody({
    required this.authService,
    required this.publicProfile,
    required this.onPrivacyChanged,
    required this.skiLog,
    required this.profile,
    required this.user,
    required this.onAuthChanged,
  });

  final AuthService authService;
  final bool publicProfile;
  final ValueChanged<bool> onPrivacyChanged;
  final SkiLogState skiLog;
  final UserProfile? profile;
  final User? user;
  final VoidCallback onAuthChanged;

  @override
  Widget build(BuildContext context) {
    final completedTours = _completedTours(skiLog);
    final savedTours = _savedTours(skiLog);
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
          title: 'Recent ski tours',
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

  List<SkiRoute> _completedTours(SkiLogState skiLog) {
    final ids = skiLog.sends.map((send) => send.routeId).toSet();
    return skiRoutes.where((route) => ids.contains(route.id)).toList();
  }

  List<SkiRoute> _savedTours(SkiLogState skiLog) {
    return skiRoutes
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
  const _ProfileHeader({required this.sendCount, required this.projectCount});

  final int sendCount;
  final int projectCount;

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
              displayName,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle.isEmpty ? 'Your climbing logbook' : subtitle,
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
                _StatTile(label: 'Sends', value: '$sendCount'),
                _StatTile(label: 'Projects', value: '$projectCount'),
              ],
            ),
          ],
        ),
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
        color: const Color(0xFFFFF0C2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE4C968)),
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
        : user?.userMetadata?['full_name']?.toString() ?? 'Ski tourer';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
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
            const SizedBox(height: 12),
            Text(
              profileName,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            const Text('Backcountry days, objectives, and terrain history'),
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
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
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
        color: const Color(0xFFFFF0C2),
        borderRadius: BorderRadius.circular(8),
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

class _PyramidRow extends StatelessWidget {
  const _PyramidRow({
    required this.grade,
    required this.count,
    required this.maxCount,
  });

  final String grade;
  final int count;
  final int maxCount;

  @override
  Widget build(BuildContext context) {
    final factor = maxCount == 0 ? 0.0 : count / maxCount;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 54, child: Text(grade)),
          Expanded(
            child: LinearProgressIndicator(
              value: factor,
              minHeight: 12,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 10),
          Text('$count'),
        ],
      ),
    );
  }
}

class _RecentActivity extends StatelessWidget {
  const _RecentActivity({required this.sends, required this.attempts});

  final List<Send> sends;
  final List<Attempt> attempts;

  @override
  Widget build(BuildContext context) {
    final activity = <_ActivityItem>[
      for (final send in sends)
        _ActivityItem(
          icon: Icons.check_circle_outline,
          title: send.routeName,
          subtitle: 'Sent ${send.grade} - ${send.style}',
          date: send.sentAt,
        ),
      for (final attempt in attempts)
        _ActivityItem(
          icon: Icons.add_task,
          title: attempt.routeName,
          subtitle: attempt.note,
          date: attempt.attemptedAt,
        ),
    ]..sort((a, b) => b.date.compareTo(a.date));

    if (activity.isEmpty) {
      return const _EmptyProfileState(text: 'Attempts and sends show up here.');
    }

    return Column(
      children: [
        for (final item in activity.take(6))
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(item.icon),
            title: Text(item.title),
            subtitle: Text(item.subtitle),
          ),
      ],
    );
  }
}

class _ActivityItem {
  const _ActivityItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.date,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final DateTime date;
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
