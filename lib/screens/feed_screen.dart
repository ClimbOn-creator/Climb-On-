import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../models/climb_route.dart';
import '../models/crag.dart';
import '../models/ski_route.dart';
import '../models/social.dart';
import '../state/activity_mode_state.dart';
import '../state/catalog_state.dart';
import '../state/climb_log_state.dart';
import '../state/ski_log_state.dart';
import '../state/ski_route_state.dart';
import '../state/social_state.dart';
import '../theme/climb_on_theme.dart';
import '../widgets/route_card.dart';
import '../widgets/side_banner_layout.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  String query = '';
  final Set<String> likedRouteIds = {};

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
    final climbLog = ref.watch(climbLogProvider);
    final social = ref.watch(socialProvider);
    final focusedRoute = ref.watch(focusedRouteProvider);
    final skiCatalog = ref.watch(skiRouteCatalogProvider);
    final skiRoutes = skiCatalog.valueOrNull ?? const <SkiRoute>[];
    final desktop = MediaQuery.sizeOf(context).width >= 900;

    final catalogCrags = catalog.valueOrNull ?? const <Crag>[];
    final allRoutes = [
      for (final crag in catalogCrags)
        for (final wall in crag.walls) ...wall.routes,
    ];
    final results = _searchResults(allRoutes);
    final skiResults = _skiSearchResults(skiRoutes);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SideBannerLayout(
        maxContentWidth: 980,
        child: RefreshIndicator(
          onRefresh: social.refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              desktop ? 28 : 16,
              desktop ? 30 : 22,
              desktop ? 28 : 16,
              40,
            ),
            children: [
              Text(
                mode == ActivityMode.ski
                    ? 'WINTER FIELD NOTES'
                    : 'FROM THE COMMUNITY',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.7,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                mode == ActivityMode.ski ? 'Touring feed' : 'The climbing feed',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 7),
              Text(
                mode == ActivityMode.ski
                    ? 'Recent objectives, conditions, and routes from your touring circle.'
                    : 'Fresh sends, new lines, and crag notes from climbers near you.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 22),
              TextField(
                onChanged: (value) => setState(() => query = value),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search routes, grades, tours, or areas',
                ),
              ),
              const SizedBox(height: 16),
              if (mode == ActivityMode.ski) ...[
                if (skiCatalog.isLoading)
                  const LinearProgressIndicator(minHeight: 3),
                if (query.trim().isEmpty && skiRoutes.isNotEmpty) ...[
                  _FeaturedStory(
                    imageUrl: skiRoutes.first.imageUrl,
                    eyebrow: 'FEATURED TOUR',
                    title: skiRoutes.first.name,
                    subtitle:
                        '${skiRoutes.first.area}, ${skiRoutes.first.region}',
                    meta:
                        '${skiRoutes.first.distanceKm} km · ${skiRoutes.first.elevationGainMeters} m gain · ${skiRoutes.first.difficulty}',
                    onTap: () => _openSkiDetails(context, skiRoutes.first),
                  ),
                  const SizedBox(height: 18),
                ],
                _SkiFeed(
                  query: query,
                  routes: skiResults,
                  onRouteTap: _openSkiDetails,
                ),
              ] else ...[
                if (catalog.isLoading)
                  const LinearProgressIndicator(minHeight: 3),
                if (catalog.hasError)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Using saved route data while the cloud reconnects.',
                    ),
                  ),
                if (focusedRoute != null) ...[
                  _SectionHeader(
                    title: 'Selected route',
                    action: TextButton.icon(
                      onPressed: () {
                        ref.read(focusedRouteProvider.notifier).state = null;
                      },
                      icon: const Icon(Icons.close),
                      label: const Text('Clear'),
                    ),
                  ),
                  RouteCard(route: focusedRoute, expanded: true),
                  const SizedBox(height: 24),
                ],
                if (focusedRoute == null &&
                    query.trim().isEmpty &&
                    allRoutes.isNotEmpty) ...[
                  _FeaturedStory(
                    imageUrl: allRoutes.first.imageUrl,
                    eyebrow: 'ROUTE OF THE WEEK',
                    title: allRoutes.first.name,
                    subtitle: 'A community favourite from the field guide',
                    meta:
                        '${allRoutes.first.grade} · ${allRoutes.first.typeLabel} · ${allRoutes.first.rating}/5',
                    onTap: () => _openRouteDetails(context, allRoutes.first),
                  ),
                  const SizedBox(height: 18),
                ],
                if (query.trim().isNotEmpty) ...[
                  _SectionHeader(title: 'Search results (${results.length})'),
                  for (final route in results)
                    _RouteListTile(
                      route: route,
                      subtitle: '${route.grade} - ${route.typeLabel}',
                      onTap: () => _openRouteDetails(context, route),
                    ),
                  const SizedBox(height: 24),
                ] else ...[
                  _PhotoSocialFeed(
                    social: social,
                    routes: allRoutes,
                    climbLog: climbLog,
                    likedRouteIds: likedRouteIds,
                    onRouteTap: _openRouteDetails,
                    onProfileTap: (profile) =>
                        _showFriendProfile(profile, social, allRoutes),
                    onLike: (route) {
                      setState(() {
                        if (!likedRouteIds.add(route.id)) {
                          likedRouteIds.remove(route.id);
                        }
                      });
                    },
                    onSave: (route) => climbLog.toggleProject(route),
                    onSend: (route) => _sendRoute(route, social),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<ClimbRoute> _searchResults(List<ClimbRoute> routes) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return routes;

    return routes.where((route) {
      return route.name.toLowerCase().contains(needle) ||
          route.grade.toLowerCase().contains(needle) ||
          route.typeLabel.toLowerCase().contains(needle) ||
          route.pitchLabel.toLowerCase().contains(needle);
    }).toList();
  }

  List<SkiRoute> _skiSearchResults(List<SkiRoute> routes) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return routes;
    return routes.where((route) {
      return route.name.toLowerCase().contains(needle) ||
          route.area.toLowerCase().contains(needle) ||
          route.region.toLowerCase().contains(needle) ||
          route.difficulty.toLowerCase().contains(needle);
    }).toList();
  }

  void _openRouteDetails(BuildContext context, ClimbRoute route) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.92,
          minChildSize: 0.65,
          maxChildSize: 0.98,
          builder: (context, scrollController) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            route.name,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    RouteCard(route: route, expanded: true),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showFriendsManager(SocialState social, List<ClimbRoute> routes) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _FriendsManager(
        social: social,
        onProfileTap: (profile) => _showFriendProfile(profile, social, routes),
      ),
    );
  }

  void _sendRoute(ClimbRoute route, SocialState social) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => _SendRouteSheet(
        route: route,
        friends: social.friends,
        onAddFriends: () {
          Navigator.pop(sheetContext);
          _showFriendsManager(social, const []);
        },
      ),
    );
  }

  void _showFriendProfile(
    FriendProfile profile,
    SocialState social,
    List<ClimbRoute> routes,
  ) {
    final routesById = {for (final route in routes) route.id: route};
    final sends = social.friendSends
        .where((send) => send.user.id == profile.id)
        .where((send) => routesById.containsKey(send.routeId))
        .toList(growable: false);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (pageContext) => _FriendProfilePage(
          profile: profile,
          sends: sends,
          routesById: routesById,
          onRouteTap: (route) => _openRouteDetails(pageContext, route),
        ),
      ),
    );
  }

  void _openSkiDetails(BuildContext context, SkiRoute route) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.82,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text(
              route.name,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            _SkiTourCard(route: route),
          ],
        ),
      ),
    );
  }
}

class _FeaturedStory extends StatelessWidget {
  const _FeaturedStory({
    required this.imageUrl,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.onTap,
  });

  final String imageUrl;
  final String eyebrow;
  final String title;
  final String subtitle;
  final String meta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: MediaQuery.sizeOf(context).width >= 700 ? 330 : 280,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                errorWidget: (_, _, _) => const ColoredBox(
                  color: PacificTerrainColors.navySoft,
                  child: Icon(
                    Icons.landscape_outlined,
                    size: 52,
                    color: Colors.white,
                  ),
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x08112D3B), Color(0xE8112D3B)],
                    stops: [0.25, 1],
                  ),
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 18,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            eyebrow,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: PacificTerrainColors.sand,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.5,
                                ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            title,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(color: Colors.white),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.white70),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            meta,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_outward,
                        color: PacificTerrainColors.navy,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkiFeed extends StatelessWidget {
  const _SkiFeed({
    required this.query,
    required this.routes,
    required this.onRouteTap,
  });

  final String query;
  final List<SkiRoute> routes;
  final void Function(BuildContext context, SkiRoute route) onRouteTap;

  @override
  Widget build(BuildContext context) {
    final visibleRoutes = routes.take(query.trim().isEmpty ? 6 : routes.length);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        Text(
          query.trim().isEmpty ? 'Touring community' : 'Search results',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        for (final route in visibleRoutes)
          _SkiSocialPost(route: route, onTap: () => onRouteTap(context, route)),
      ],
    );
  }
}

class _SkiSocialPost extends ConsumerWidget {
  const _SkiSocialPost({required this.route, required this.onTap});

  final SkiRoute route;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skiLog = ref.watch(skiLogProvider);
    final saved = skiLog.isProject(route);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                    child: Icon(
                      Icons.downhill_skiing,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Climb On Touring',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        Text(
                          '${route.area} · ${route.difficulty}',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.more_horiz),
                ],
              ),
            ),
            InkWell(
              onTap: onTap,
              child: SizedBox(
                height: MediaQuery.sizeOf(context).width >= 700 ? 410 : 280,
                child: CachedNetworkImage(
                  imageUrl: route.imageUrl,
                  width: double.infinity,
                  fit: BoxFit.contain,
                  errorWidget: (_, _, _) => ColoredBox(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: const Icon(Icons.landscape_outlined, size: 56),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'View tour',
                    onPressed: onTap,
                    icon: const Icon(Icons.mode_comment_outlined),
                  ),
                  IconButton(
                    tooltip: 'Send to a friend',
                    onPressed: () => SharePlus.instance.share(
                      ShareParams(
                        text:
                            '${route.name} — ${route.area}\n${route.distanceKm} km · ${route.elevationGainMeters} m gain',
                      ),
                    ),
                    icon: const Icon(Icons.send_outlined),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: saved ? 'Remove saved tour' : 'Save tour',
                    onPressed: () =>
                        ref.read(skiLogProvider).toggleProject(route),
                    icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    route.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${route.distanceKm} km · ${route.elevationGainMeters} m gain · ${route.avalancheTerrain}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkiTourCard extends ConsumerWidget {
  const _SkiTourCard({required this.route});

  final SkiRoute route;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skiLog = ref.watch(skiLogProvider);
    final completed = skiLog.isCompleted(route);
    final saved = skiLog.isProject(route);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: route.imageUrl,
                height: 220,
                width: double.infinity,
                fit: BoxFit.contain,
                errorWidget: (_, _, _) => const Icon(Icons.broken_image),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => ref.read(skiLogProvider).toggleTour(route),
                  icon: Icon(
                    completed ? Icons.check_circle : Icons.check_circle_outline,
                  ),
                  label: Text(completed ? 'Completed' : 'Mark completed'),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      ref.read(skiLogProvider).toggleProject(route),
                  icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
                  label: Text(saved ? 'Saved' : 'Save objective'),
                ),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.ios_share),
                  label: const Text('Share'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text('${route.distanceKm} km')),
                Chip(label: Text('${route.elevationGainMeters} m gain')),
                Chip(label: Text(route.difficulty)),
                Chip(label: Text(route.aspect)),
                Chip(label: Text(route.avalancheTerrain)),
              ],
            ),
            const SizedBox(height: 12),
            Text(route.description),
            const Divider(),
            Text('Approach: ${route.approachNotes}'),
            const SizedBox(height: 8),
            Text('Descent: ${route.descentNotes}'),
            const SizedBox(height: 8),
            Text('Safety: ${route.dangerInfo}'),
          ],
        ),
      ),
    );
  }
}

class _PhotoSocialFeed extends StatelessWidget {
  const _PhotoSocialFeed({
    required this.social,
    required this.routes,
    required this.climbLog,
    required this.likedRouteIds,
    required this.onRouteTap,
    required this.onProfileTap,
    required this.onLike,
    required this.onSave,
    required this.onSend,
  });

  final SocialState social;
  final List<ClimbRoute> routes;
  final ClimbLogState climbLog;
  final Set<String> likedRouteIds;
  final void Function(BuildContext context, ClimbRoute route) onRouteTap;
  final ValueChanged<FriendProfile> onProfileTap;
  final ValueChanged<ClimbRoute> onLike;
  final ValueChanged<ClimbRoute> onSave;
  final ValueChanged<ClimbRoute> onSend;

  @override
  Widget build(BuildContext context) {
    final routesById = {for (final route in routes) route.id: route};
    final friendPosts = social.friendSends
        .where((activity) => routesById.containsKey(activity.routeId))
        .take(8)
        .toList(growable: false);
    final discoveryRoutes = routes.skip(routes.length > 1 ? 1 : 0).take(6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                friendPosts.isEmpty ? 'Discover' : 'Following',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            Text(
              'PHOTO FIELD NOTES',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (friendPosts.isNotEmpty)
          for (final activity in friendPosts)
            _SocialRoutePost(
              route: routesById[activity.routeId]!,
              displayName: activity.user.displayName.isEmpty
                  ? activity.user.username
                  : activity.user.displayName,
              username: activity.user.username,
              avatarUrl: activity.user.avatarUrl,
              activityLine:
                  '${activity.style} · ${activity.grade} · ${_socialTime(activity.sentAt)}',
              liked: likedRouteIds.contains(activity.routeId),
              saved: climbLog.isProject(routesById[activity.routeId]!),
              onProfileTap: () => onProfileTap(activity.user),
              onRouteTap: () =>
                  onRouteTap(context, routesById[activity.routeId]!),
              onLike: () => onLike(routesById[activity.routeId]!),
              onSave: () => onSave(routesById[activity.routeId]!),
              onSend: () => onSend(routesById[activity.routeId]!),
            )
        else if (discoveryRoutes.isEmpty)
          const _EmptyFeedState(
            icon: Icons.photo_library_outlined,
            text: 'Route pictures will appear here as the catalogue grows.',
          )
        else
          for (final route in discoveryRoutes)
            _SocialRoutePost(
              route: route,
              displayName: 'Climb On Field Team',
              username: 'climbon.beta',
              avatarUrl: '',
              activityLine: 'Field guide feature · ${route.typeLabel}',
              liked: likedRouteIds.contains(route.id),
              saved: climbLog.isProject(route),
              onRouteTap: () => onRouteTap(context, route),
              onLike: () => onLike(route),
              onSave: () => onSave(route),
              onSend: () => onSend(route),
            ),
      ],
    );
  }
}

class _SocialRoutePost extends StatelessWidget {
  const _SocialRoutePost({
    required this.route,
    required this.displayName,
    required this.username,
    required this.avatarUrl,
    required this.activityLine,
    required this.liked,
    required this.saved,
    required this.onRouteTap,
    required this.onLike,
    required this.onSave,
    required this.onSend,
    this.onProfileTap,
  });

  final ClimbRoute route;
  final String displayName;
  final String username;
  final String avatarUrl;
  final String activityLine;
  final bool liked;
  final bool saved;
  final VoidCallback onRouteTap;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final VoidCallback onSend;
  final VoidCallback? onProfileTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
              child: Row(
                children: [
                  InkWell(
                    onTap: onProfileTap,
                    customBorder: const CircleBorder(),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                      backgroundImage: avatarUrl.isEmpty
                          ? null
                          : NetworkImage(avatarUrl),
                      child: avatarUrl.isEmpty
                          ? Icon(
                              Icons.landscape_outlined,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName.isEmpty ? '@$username' : displayName,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        Text(
                          activityLine,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'More',
                    onPressed: () {},
                    icon: const Icon(Icons.more_horiz),
                  ),
                ],
              ),
            ),
            InkWell(
              onTap: onRouteTap,
              child: SizedBox(
                height: MediaQuery.sizeOf(context).width >= 700 ? 410 : 280,
                child: CachedNetworkImage(
                  imageUrl: route.imageUrl,
                  width: double.infinity,
                  fit: BoxFit.contain,
                  errorWidget: (_, _, _) => ColoredBox(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: const Icon(Icons.landscape_outlined, size: 56),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: liked ? 'Unlike' : 'Like',
                    onPressed: onLike,
                    icon: Icon(liked ? Icons.favorite : Icons.favorite_border),
                    color: liked ? Theme.of(context).colorScheme.primary : null,
                  ),
                  IconButton(
                    tooltip: 'Comment',
                    onPressed: onRouteTap,
                    icon: const Icon(Icons.mode_comment_outlined),
                  ),
                  IconButton(
                    tooltip: 'Send to a friend',
                    onPressed: onSend,
                    icon: const Icon(Icons.send_outlined),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: saved ? 'Remove from saved climbs' : 'Save climb',
                    onPressed: onSave,
                    icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${route.name}  ${route.grade}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    route.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${route.rating}/5 · ${route.typeLabel} · ${route.pitchLabel}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SendRouteSheet extends StatelessWidget {
  const _SendRouteSheet({
    required this.route,
    required this.friends,
    required this.onAddFriends,
  });

  final ClimbRoute route;
  final List<FriendProfile> friends;
  final VoidCallback onAddFriends;

  Future<void> _share([FriendProfile? friend]) async {
    final recipient = friend == null
        ? ''
        : 'Hey ${friend.displayName.isEmpty ? friend.username : friend.displayName}, ';
    await SharePlus.instance.share(
      ShareParams(
        text:
            '${recipient}check out ${route.name} (${route.grade}) on Climb On. ${route.description}',
        subject: '${route.name} · Climb On',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Send climb', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            '${route.name} · ${route.grade}',
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 18),
          if (friends.isEmpty)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(child: Icon(Icons.person_add_alt_1)),
              title: const Text('Add friends on Climb On'),
              subtitle: const Text(
                'Build your circle to send climbs directly.',
              ),
              onTap: onAddFriends,
            )
          else
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: friends.length,
                separatorBuilder: (_, _) => const SizedBox(width: 16),
                itemBuilder: (context, index) {
                  final friend = friends[index];
                  return InkWell(
                    onTap: () => _share(friend),
                    child: SizedBox(
                      width: 72,
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 27,
                            backgroundImage: friend.avatarUrl.isEmpty
                                ? null
                                : NetworkImage(friend.avatarUrl),
                            child: friend.avatarUrl.isEmpty
                                ? const Icon(Icons.person_outline)
                                : null,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            friend.username,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _share,
              icon: const Icon(Icons.ios_share),
              label: const Text('Share another way'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        ?action,
      ],
    );
  }
}

class _RouteListTile extends StatelessWidget {
  const _RouteListTile({
    required this.route,
    required this.subtitle,
    required this.onTap,
  });

  final ClimbRoute route;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.all(10),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 78,
            height: 72,
            child: CachedNetworkImage(
              imageUrl: route.imageUrl,
              fit: BoxFit.contain,
              errorWidget: (context, error, stackTrace) => ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.terrain_outlined),
              ),
            ),
          ),
        ),
        title: Text(route.name, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _EmptyFeedState extends StatelessWidget {
  const _EmptyFeedState({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}

class _FriendsManager extends StatefulWidget {
  const _FriendsManager({required this.social, required this.onProfileTap});

  final SocialState social;
  final ValueChanged<FriendProfile> onProfileTap;

  @override
  State<_FriendsManager> createState() => _FriendsManagerState();
}

class _FriendsManagerState extends State<_FriendsManager> {
  final searchController = TextEditingController();
  List<FriendProfile> results = const [];
  bool searching = false;
  String busyUserId = '';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.social.signedIn) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: _EmptyFeedState(
          icon: Icons.login,
          text: 'Sign in from your profile before adding friends.',
        ),
      );
    }

    return FractionallySizedBox(
      heightFactor: 0.85,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Text(
            'Friends',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              hintText: 'Search username or name',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                tooltip: 'Search climbers',
                onPressed: searching ? null : _search,
                icon: searching
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.arrow_forward),
              ),
            ),
          ),
          if (results.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              'Search results',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            for (final profile in results) _profileTile(profile),
          ],
          const SizedBox(height: 20),
          Text(
            'Your friends',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          if (widget.social.friends.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text('Search for a climber to add your first friend.'),
            )
          else
            for (final profile in widget.social.friends) _profileTile(profile),
        ],
      ),
    );
  }

  Widget _profileTile(FriendProfile profile) {
    final isFriend = widget.social.isFriend(profile.id);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: () => widget.onProfileTap(profile),
      leading: CircleAvatar(
        backgroundImage: profile.avatarUrl.isEmpty
            ? null
            : NetworkImage(profile.avatarUrl),
        child: profile.avatarUrl.isEmpty
            ? const Icon(Icons.person_outline)
            : null,
      ),
      title: Text(
        profile.username.isEmpty ? profile.displayName : '@${profile.username}',
      ),
      subtitle: Text(
        [
          profile.displayName,
          profile.homeArea,
        ].where((value) => value.isNotEmpty).join(' · '),
      ),
      trailing: busyUserId == profile.id
          ? const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : isFriend
          ? TextButton(
              onPressed: () => _remove(profile),
              child: const Text('Remove'),
            )
          : FilledButton(
              onPressed: () => _add(profile),
              child: const Text('Add'),
            ),
    );
  }

  Future<void> _search() async {
    final query = searchController.text.trim();
    if (query.isEmpty) return;
    setState(() => searching = true);
    try {
      final found = await widget.social.search(query);
      if (mounted) setState(() => results = found);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not search climbers: $error')),
      );
    } finally {
      if (mounted) setState(() => searching = false);
    }
  }

  Future<void> _add(FriendProfile profile) async {
    setState(() => busyUserId = profile.id);
    try {
      await widget.social.addFriend(profile);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not add friend: $error')));
    } finally {
      if (mounted) setState(() => busyUserId = '');
    }
  }

  Future<void> _remove(FriendProfile profile) async {
    setState(() => busyUserId = profile.id);
    try {
      await widget.social.removeFriend(profile);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not remove friend: $error')),
      );
    } finally {
      if (mounted) setState(() => busyUserId = '');
    }
  }
}

class _FriendProfilePage extends StatelessWidget {
  const _FriendProfilePage({
    required this.profile,
    required this.sends,
    required this.routesById,
    required this.onRouteTap,
  });

  final FriendProfile profile;
  final List<FriendSendActivity> sends;
  final Map<String, ClimbRoute> routesById;
  final ValueChanged<ClimbRoute> onRouteTap;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Climber profile')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          children: [
            Center(
              child: CircleAvatar(
                radius: 48,
                backgroundImage: profile.avatarUrl.isEmpty
                    ? null
                    : NetworkImage(profile.avatarUrl),
                child: profile.avatarUrl.isEmpty
                    ? const Icon(Icons.person, size: 44)
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              profile.username.isEmpty
                  ? profile.displayName
                  : '@${profile.username}',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            if (profile.username.isNotEmpty && profile.displayName.isNotEmpty)
              Text(profile.displayName, textAlign: TextAlign.center),
            if (profile.homeArea.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                profile.homeArea,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
            if (profile.bio.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(profile.bio, textAlign: TextAlign.center),
            ],
            const SizedBox(height: 28),
            Text(
              'Recent sends',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            if (sends.isEmpty)
              const _EmptyFeedState(
                icon: Icons.check_circle_outline,
                text: 'No recent sends shared yet.',
              )
            else
              for (final send in sends)
                _RouteListTile(
                  route: routesById[send.routeId]!,
                  subtitle:
                      '${send.grade} · ${send.style} · ${_socialTime(send.sentAt)}',
                  onTap: () => onRouteTap(routesById[send.routeId]!),
                ),
          ],
        ),
      ),
    );
  }
}

String _socialTime(DateTime dateTime) {
  final elapsed = DateTime.now().difference(dateTime.toLocal());
  if (elapsed.inMinutes < 1) return 'just now';
  if (elapsed.inHours < 1) return '${elapsed.inMinutes}m ago';
  if (elapsed.inDays < 1) return '${elapsed.inHours}h ago';
  if (elapsed.inDays < 7) return '${elapsed.inDays}d ago';
  return '${dateTime.toLocal().month}/${dateTime.toLocal().day}/${dateTime.toLocal().year}';
}
