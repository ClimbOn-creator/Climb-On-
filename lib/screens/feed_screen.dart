import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/climb_route.dart';
import '../models/crag.dart';
import '../models/ski_route.dart';
import '../data/sample_ski_routes.dart';
import '../state/activity_mode_state.dart';
import '../state/catalog_state.dart';
import '../state/climb_log_state.dart';
import '../state/ski_log_state.dart';
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
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogProvider);
    final mode = ref.watch(activityModeProvider);
    final climbLog = ref.watch(climbLogProvider);
    final focusedRoute = ref.watch(focusedRouteProvider);
    final showTitleBar = MediaQuery.sizeOf(context).width >= 1024;

    final catalogCrags = catalog.valueOrNull ?? const <Crag>[];
    final allRoutes = [
      for (final crag in catalogCrags)
        for (final wall in crag.walls) ...wall.routes,
    ];
    final results = _searchResults(allRoutes);
    final skiResults = _skiSearchResults();

    return Scaffold(
      appBar: showTitleBar ? AppBar(title: const Text('Feed')) : null,
      body: SideBannerLayout(
        child: ListView(
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
                  routes: allRoutes,
                  onRouteTap: _openRouteDetails,
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
                  title: 'Recommended projects',
                  routes: _recommendedProjects(climbLog, allRoutes),
                  subtitleFor: (route) =>
                      '${route.grade} - good next ${route.typeLabel.toLowerCase()}',
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
                  subtitleFor: (route) => '${route.rating}/5 community rating',
                  onRouteTap: _openRouteDetails,
                ),
              ],
            ],
          ],
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

  List<SkiRoute> _skiSearchResults() {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return skiRoutes;
    return skiRoutes.where((route) {
      return route.name.toLowerCase().contains(needle) ||
          route.area.toLowerCase().contains(needle) ||
          route.region.toLowerCase().contains(needle) ||
          route.difficulty.toLowerCase().contains(needle);
    }).toList();
  }

  List<ClimbRoute> _recommendedProjects(
    ClimbLogState climbLog,
    List<ClimbRoute> routes,
  ) {
    final savedProjects = routes
        .where(climbLog.isProject)
        .toList(growable: false);
    if (savedProjects.isNotEmpty) return savedProjects;

    return routes
        .where((route) => !climbLog.isCompleted(route))
        .take(4)
        .toList(growable: false);
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
              child: Image.network(
                route.imageUrl,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
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
  const _FriendSendsSection({required this.routes, required this.onRouteTap});

  final List<ClimbRoute> routes;
  final void Function(BuildContext context, ClimbRoute route) onRouteTap;

  @override
  Widget build(BuildContext context) {
    final visibleRoutes = routes.take(3).toList();
    final friends = ['Maya', 'Noah', 'Priya'];

    return _Section(
      title: 'Friends\' sends',
      child: Column(
        children: [
          for (var index = 0; index < visibleRoutes.length; index++)
            _RouteListTile(
              route: visibleRoutes[index],
              leading: CircleAvatar(child: Text(friends[index][0])),
              subtitle: '${friends[index]} sent ${visibleRoutes[index].grade}',
              onTap: () => onRouteTap(context, visibleRoutes[index]),
            ),
        ],
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
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(title: title),
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
    this.leading,
  });

  final ClimbRoute route;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: leading ?? const Icon(Icons.route),
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
