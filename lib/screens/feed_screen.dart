import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import '../widgets/route_card.dart';
import '../widgets/side_banner_layout.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  String query = '';

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
    final showTitleBar = MediaQuery.sizeOf(context).width >= 1024;

    final catalogCrags = catalog.valueOrNull ?? const <Crag>[];
    final allRoutes = [
      for (final crag in catalogCrags)
        for (final wall in crag.walls) ...wall.routes,
    ];
    final results = _searchResults(allRoutes);
    final skiResults = _skiSearchResults(skiRoutes);

    return Scaffold(
      appBar: showTitleBar ? AppBar(title: const Text('Feed')) : null,
      body: SideBannerLayout(
        child: RefreshIndicator(
          onRefresh: social.refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
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
                  _FriendSendsSection(
                    social: social,
                    routes: allRoutes,
                    onRouteTap: _openRouteDetails,
                    onAddFriends: () => _showFriendsManager(social, allRoutes),
                    onProfileTap: (profile) =>
                        _showFriendProfile(profile, social, allRoutes),
                  ),
                  _YourRecentSendsSection(
                    sends: climbLog.sends,
                    routes: allRoutes,
                    onRouteTap: _openRouteDetails,
                  ),
                  _RouteSection(
                    title: 'Routes near you',
                    routes: allRoutes.take(4).toList(),
                    subtitleFor: (route) => '${route.grade} - nearby Victoria',
                    onRouteTap: _openRouteDetails,
                  ),
                  _RouteSection(
                    title: 'New routes added nearby',
                    routes: allRoutes.reversed.take(3).toList(),
                    subtitleFor: (route) => '${route.grade} - added this month',
                    onRouteTap: _openRouteDetails,
                  ),
                  _RouteSection(
                    title: 'Popular climbs this week',
                    routes: [...allRoutes]
                      ..sort((a, b) => b.rating.compareTo(a.rating)),
                    maxItems: 4,
                    subtitleFor: (route) =>
                        '${route.rating}/5 community rating',
                    onRouteTap: _openRouteDetails,
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
    return Column(
      children: [
        _Section(
          title: query.trim().isEmpty ? 'Friends touring' : 'Search results',
          child: Column(
            children: [
              for (final route in routes.take(
                query.trim().isEmpty ? 2 : routes.length,
              ))
                _SkiListTile(
                  route: route,
                  subtitle:
                      '${route.distanceKm} km - ${route.elevationGainMeters} m - ${route.difficulty}',
                  onTap: () => onRouteTap(context, route),
                ),
            ],
          ),
        ),
        if (query.trim().isEmpty) ...[
          _SkiRouteSection(
            title: 'Tours near you',
            routes: routes,
            onRouteTap: onRouteTap,
          ),
          _SkiRouteSection(
            title: 'Recommended objectives',
            routes: [...routes]
              ..sort(
                (a, b) =>
                    b.elevationGainMeters.compareTo(a.elevationGainMeters),
              ),
            onRouteTap: onRouteTap,
          ),
          _SkiRouteSection(
            title: 'Popular tours this week',
            routes: routes.reversed.toList(),
            onRouteTap: onRouteTap,
          ),
        ],
      ],
    );
  }
}

class _SkiRouteSection extends StatelessWidget {
  const _SkiRouteSection({
    required this.title,
    required this.routes,
    required this.onRouteTap,
  });

  final String title;
  final List<SkiRoute> routes;
  final void Function(BuildContext context, SkiRoute route) onRouteTap;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: title,
      child: Column(
        children: [
          for (final route in routes.take(4))
            _SkiListTile(
              route: route,
              subtitle:
                  '${route.area} - ${route.distanceKm} km - ${route.avalancheTerrain}',
              onTap: () => onRouteTap(context, route),
            ),
        ],
      ),
    );
  }
}

class _SkiListTile extends StatelessWidget {
  const _SkiListTile({
    required this.route,
    required this.subtitle,
    required this.onTap,
  });

  final SkiRoute route;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const Icon(Icons.downhill_skiing),
        title: Text(route.name),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
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
                fit: BoxFit.cover,
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

class _FriendSendsSection extends StatelessWidget {
  const _FriendSendsSection({
    required this.social,
    required this.routes,
    required this.onRouteTap,
    required this.onAddFriends,
    required this.onProfileTap,
  });

  final SocialState social;
  final List<ClimbRoute> routes;
  final void Function(BuildContext context, ClimbRoute route) onRouteTap;
  final VoidCallback onAddFriends;
  final ValueChanged<FriendProfile> onProfileTap;

  @override
  Widget build(BuildContext context) {
    final routesById = {for (final route in routes) route.id: route};
    final activities = social.friendSends
        .where((activity) => routesById.containsKey(activity.routeId))
        .take(6)
        .toList(growable: false);

    return _Section(
      title: 'Friends\' sends',
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Refresh friend sends',
            onPressed: social.loading ? null : social.refresh,
            icon: const Icon(Icons.refresh),
          ),
          TextButton.icon(
            onPressed: onAddFriends,
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Add friends'),
          ),
        ],
      ),
      child: !social.signedIn
          ? const _EmptyFeedState(
              icon: Icons.people_outline,
              text: 'Sign in to add friends and see their sends.',
            )
          : social.loading && activities.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : activities.isEmpty
          ? _EmptyFeedState(
              icon: Icons.people_outline,
              text: social.friends.isEmpty
                  ? 'Add a friend to start your social feed.'
                  : 'Your friends\' recent sends will appear here.',
            )
          : Column(
              children: [
                for (final activity in activities)
                  _FriendSendTile(
                    activity: activity,
                    route: routesById[activity.routeId]!,
                    onRouteTap: () =>
                        onRouteTap(context, routesById[activity.routeId]!),
                    onProfileTap: () => onProfileTap(activity.user),
                  ),
              ],
            ),
    );
  }
}

class _FriendSendTile extends StatelessWidget {
  const _FriendSendTile({
    required this.activity,
    required this.route,
    required this.onRouteTap,
    required this.onProfileTap,
  });

  final FriendSendActivity activity;
  final ClimbRoute route;
  final VoidCallback onRouteTap;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    final username = activity.user.username.isEmpty
        ? activity.user.displayName
        : '@${activity.user.username}';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onRouteTap,
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: route.imageUrl,
            width: 58,
            height: 58,
            fit: BoxFit.cover,
            errorWidget: (_, _, _) => const SizedBox.square(
              dimension: 58,
              child: Icon(Icons.terrain),
            ),
          ),
        ),
        title: Text(route.name),
        subtitle: Text(
          '$username sent ${activity.grade} · ${_socialTime(activity.sentAt)}',
        ),
        trailing: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onProfileTap,
          child: CircleAvatar(
            backgroundImage: activity.user.avatarUrl.isEmpty
                ? null
                : NetworkImage(activity.user.avatarUrl),
            child: activity.user.avatarUrl.isEmpty
                ? const Icon(Icons.person_outline)
                : null,
          ),
        ),
      ),
    );
  }
}

class _YourRecentSendsSection extends StatelessWidget {
  const _YourRecentSendsSection({
    required this.sends,
    required this.routes,
    required this.onRouteTap,
  });

  final List<Send> sends;
  final List<ClimbRoute> routes;
  final void Function(BuildContext context, ClimbRoute route) onRouteTap;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Your recent sends',
      child: sends.isEmpty
          ? const _EmptyFeedState(
              icon: Icons.check_circle_outline,
              text: 'Completed routes will show up here.',
            )
          : Column(
              children: [
                for (final send in sends.take(4))
                  _RouteListTile(
                    route: routes.firstWhere(
                      (route) => route.id == send.routeId,
                      orElse: () => routes.first,
                    ),
                    subtitle: '${send.grade} - ${send.style}',
                    onTap: () => onRouteTap(
                      context,
                      routes.firstWhere(
                        (route) => route.id == send.routeId,
                        orElse: () => routes.first,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _RouteSection extends StatelessWidget {
  const _RouteSection({
    required this.title,
    required this.routes,
    required this.subtitleFor,
    required this.onRouteTap,
    this.maxItems,
  });

  final String title;
  final List<ClimbRoute> routes;
  final String Function(ClimbRoute route) subtitleFor;
  final void Function(BuildContext context, ClimbRoute route) onRouteTap;
  final int? maxItems;

  @override
  Widget build(BuildContext context) {
    final visibleRoutes = routes.take(maxItems ?? routes.length);

    return _Section(
      title: title,
      child: Column(
        children: [
          for (final route in visibleRoutes)
            _RouteListTile(
              route: route,
              subtitle: subtitleFor(route),
              onTap: () => onRouteTap(context, route),
            ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.action});

  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(title: title, action: action),
          const SizedBox(height: 8),
          child,
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
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
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
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 64,
            height: 64,
            child: CachedNetworkImage(
              imageUrl: route.imageUrl,
              fit: BoxFit.cover,
              errorWidget: (context, error, stackTrace) => ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.terrain_outlined),
              ),
            ),
          ),
        ),
        title: Text(route.name),
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
