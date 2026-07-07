import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../models/climb_route.dart';
import '../models/crag.dart';
import '../models/ski_route.dart';
import '../state/activity_mode_state.dart';
import '../state/catalog_state.dart';
import '../state/climb_log_state.dart';
import '../state/ski_log_state.dart';
import '../state/ski_route_state.dart';
import '../theme/climb_on_theme.dart';
import '../utils/climb_grade_search.dart';
import '../utils/optimized_image_url.dart';
import '../widgets/route_card.dart';
import '../widgets/side_banner_layout.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  final climbSearchController = TextEditingController();
  final skiSearchController = TextEditingController();
  String climbQuery = '';
  String skiQuery = '';
  final Set<_ClimbGuideFilter> climbFilters = {};
  final Set<_SkiGuideFilter> skiFilters = {};

  @override
  void dispose() {
    climbSearchController.dispose();
    skiSearchController.dispose();
    super.dispose();
  }

  void _submitSearch(ActivityMode mode) {
    setState(() {
      if (mode == ActivityMode.ski) {
        skiQuery = skiSearchController.text.trim();
      } else {
        climbQuery = climbSearchController.text.trim();
      }
    });
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(activityModeProvider);
    final searchController = mode == ActivityMode.ski
        ? skiSearchController
        : climbSearchController;
    final query = mode == ActivityMode.ski ? skiQuery : climbQuery;
    final desktop = MediaQuery.sizeOf(context).width >= 900;
    final catalog = ref.watch(catalogProvider);
    final crags = catalog.valueOrNull ?? const <Crag>[];
    final climbLog = ref.watch(climbLogProvider);
    final skiCatalog = ref.watch(skiRouteCatalogProvider);
    final skiRoutes = skiCatalog.valueOrNull ?? const <SkiRoute>[];
    final skiLog = ref.watch(skiLogProvider);
    final focusedRoute = ref.watch(focusedRouteProvider);

    final entries = _climbEntries(crags);
    final climbResults = _filterClimbs(entries);
    final skiResults = _filterSkiRoutes(skiRoutes, skiLog);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SideBannerLayout(
        maxContentWidth: 1080,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(catalogProvider);
            ref.invalidate(skiRouteCatalogProvider);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              desktop ? 28 : 16,
              desktop ? 30 : 22,
              desktop ? 28 : 16,
              40,
            ),
            children: [
              _GuideHero(
                ski: mode == ActivityMode.ski,
                placeCount: mode == ActivityMode.ski
                    ? skiRoutes.map((route) => route.area).toSet().length
                    : crags.length,
                routeCount: mode == ActivityMode.ski
                    ? skiRoutes.length
                    : entries.length,
                savedCount: mode == ActivityMode.ski
                    ? skiLog.projectTourIds.length
                    : entries
                          .where((entry) => climbLog.isProject(entry.route))
                          .length,
              ),
              const SizedBox(height: 18),
              if (mode == ActivityMode.ski)
                _FilterBar<_SkiGuideFilter>(
                  values: _SkiGuideFilter.values,
                  selectedValues: skiFilters,
                  allValue: _SkiGuideFilter.all,
                  labelFor: (filter) => filter.label,
                  onSelected: (filter) => setState(() {
                    if (filter == _SkiGuideFilter.all) {
                      skiFilters.clear();
                    } else if (!skiFilters.remove(filter)) {
                      skiFilters.add(filter);
                    }
                  }),
                )
              else
                _FilterBar<_ClimbGuideFilter>(
                  values: _ClimbGuideFilter.values,
                  selectedValues: climbFilters,
                  allValue: _ClimbGuideFilter.all,
                  labelFor: (filter) => filter.label,
                  onSelected: (filter) => setState(() {
                    if (filter == _ClimbGuideFilter.all) {
                      climbFilters.clear();
                    } else if (!climbFilters.remove(filter)) {
                      climbFilters.add(filter);
                    }
                  }),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: searchController,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _submitSearch(mode),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: mode == ActivityMode.ski
                      ? 'Find a tour, area, difficulty, or aspect'
                      : 'Find a route, crag, grade, or climbing style',
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (searchController.text.isNotEmpty)
                        IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            searchController.clear();
                            setState(() {
                              if (mode == ActivityMode.ski) {
                                skiQuery = '';
                              } else {
                                climbQuery = '';
                              }
                            });
                          },
                          icon: const Icon(Icons.close),
                        ),
                      IconButton(
                        tooltip: 'Search',
                        onPressed: () => _submitSearch(mode),
                        icon: const Icon(Icons.arrow_forward),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              if (mode == ActivityMode.climb && focusedRoute != null) ...[
                _SectionHeading(
                  title: 'From the map',
                  subtitle: 'The line you selected is ready to inspect.',
                  trailing: TextButton.icon(
                    onPressed: () =>
                        ref.read(focusedRouteProvider.notifier).state = null,
                    icon: const Icon(Icons.close),
                    label: const Text('Clear'),
                  ),
                ),
                _FocusedRouteCard(
                  route: focusedRoute,
                  onTap: () => _openRouteDetails(focusedRoute),
                ),
                const SizedBox(height: 24),
              ],
              if (mode == ActivityMode.climb) ...[
                if (catalog.isLoading)
                  const LinearProgressIndicator(minHeight: 3),
                if (catalog.hasError)
                  const _GuideNotice(
                    icon: Icons.offline_bolt_outlined,
                    text: 'Showing saved field-guide data while reconnecting.',
                  ),
                if (query.isEmpty && climbFilters.isEmpty) ...[
                  _ProjectShelf(
                    entries: entries
                        .where((entry) => climbLog.isProject(entry.route))
                        .toList(growable: false),
                    onTap: _openRouteDetails,
                  ),
                ],
                if (query.trim().isNotEmpty || climbFilters.isNotEmpty) ...[
                  _SectionHeading(
                    title: 'Routes by crag',
                    subtitle: climbResults.isEmpty
                        ? 'No lines match those filters.'
                        : '${climbResults.length} lines, grouped by where you will actually climb.',
                  ),
                  if (climbResults.isEmpty)
                    const _EmptyGuideState(
                      icon: Icons.search_off,
                      text: 'Try another grade, style, or crag name.',
                    )
                  else
                    for (final group in _groupClimbs(climbResults))
                      _CragGuideGroup(
                        group: group,
                        climbLog: climbLog,
                        onRouteTap: _openRouteDetails,
                      ),
                ],
              ] else ...[
                if (skiCatalog.isLoading)
                  const LinearProgressIndicator(minHeight: 3),
                _SkiProjectShelf(
                  routes: query.isEmpty && skiFilters.isEmpty
                      ? skiRoutes
                            .where(skiLog.isProject)
                            .toList(growable: false)
                      : const [],
                  onTap: _openSkiDetails,
                ),
                if (query.trim().isNotEmpty || skiFilters.isNotEmpty) ...[
                  _SectionHeading(
                    title: 'Tours by area',
                    subtitle: skiResults.isEmpty
                        ? 'No objectives match those filters.'
                        : '${skiResults.length} objectives with the planning details up front.',
                  ),
                  if (skiResults.isEmpty)
                    const _EmptyGuideState(
                      icon: Icons.search_off,
                      text: 'Try another area, difficulty, or aspect.',
                    )
                  else
                    for (final group in _groupSkiRoutes(skiResults))
                      _SkiAreaGroup(
                        group: group,
                        skiLog: skiLog,
                        onRouteTap: _openSkiDetails,
                      ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<_ClimbEntry> _climbEntries(List<Crag> crags) {
    return [
      for (final crag in crags)
        for (final wall in crag.walls)
          for (final route in wall.routes)
            _ClimbEntry(route: route, crag: crag, wallName: wall.name),
    ];
  }

  List<_ClimbEntry> _filterClimbs(List<_ClimbEntry> entries) {
    final needle = climbQuery.trim().toLowerCase();
    if (needle.isEmpty && climbFilters.isEmpty) {
      return const [];
    }
    final typeFilters = climbFilters.where(
      (filter) => filter != _ClimbGuideFilter.multiPitch,
    );
    final requiresMultiPitch = climbFilters.contains(
      _ClimbGuideFilter.multiPitch,
    );
    final gradeQuery = isClimbGradeQuery(needle);
    return entries
        .where((entry) {
          final route = entry.route;
          final matchesQuery =
              needle.isEmpty ||
              (gradeQuery
                  ? climbGradeMatchesQuery(route.grade, needle)
                  : route.name.toLowerCase().contains(needle) ||
                        route.grade.toLowerCase().contains(needle) ||
                        route.typeLabel.toLowerCase().contains(needle) ||
                        route.pitchLabel.toLowerCase().contains(needle) ||
                        entry.crag.name.toLowerCase().contains(needle) ||
                        entry.wallName.toLowerCase().contains(needle));
          if (!matchesQuery) return false;
          final matchesType =
              typeFilters.isEmpty ||
              typeFilters.any(
                (filter) => switch (filter) {
                  _ClimbGuideFilter.boulder =>
                    route.type == ClimbRouteType.boulder ||
                        route.pitchType == PitchType.boulder,
                  _ClimbGuideFilter.sport => route.type == ClimbRouteType.sport,
                  _ClimbGuideFilter.trad => route.type == ClimbRouteType.trad,
                  _ClimbGuideFilter.deepWaterSolo =>
                    route.type == ClimbRouteType.deepWaterSolo,
                  _ClimbGuideFilter.aid => route.type == ClimbRouteType.aid,
                  _ => false,
                },
              );
          final matchesPitch =
              !requiresMultiPitch || route.pitchType == PitchType.multiPitch;
          return matchesType && matchesPitch;
        })
        .toList(growable: false);
  }

  List<SkiRoute> _filterSkiRoutes(List<SkiRoute> routes, SkiLogState log) {
    final needle = skiQuery.trim().toLowerCase();
    if (needle.isEmpty && skiFilters.isEmpty) {
      return const [];
    }
    final difficultyFilters = skiFilters.where(
      (filter) => filter != _SkiGuideFilter.saved,
    );
    return routes
        .where((route) {
          final matchesQuery =
              needle.isEmpty ||
              route.name.toLowerCase().contains(needle) ||
              route.area.toLowerCase().contains(needle) ||
              route.region.toLowerCase().contains(needle) ||
              route.difficulty.toLowerCase().contains(needle) ||
              route.aspect.toLowerCase().contains(needle) ||
              route.slopeAngleLabel.toLowerCase().contains(needle);
          if (!matchesQuery) return false;
          final matchesSaved =
              !skiFilters.contains(_SkiGuideFilter.saved) ||
              log.isProject(route);
          final matchesDifficulty =
              difficultyFilters.isEmpty ||
              difficultyFilters.any(
                (filter) => switch (filter) {
                  _SkiGuideFilter.beginner =>
                    route.difficulty.toLowerCase().contains('beginner'),
                  _SkiGuideFilter.intermediate =>
                    route.difficulty.toLowerCase().contains('intermediate'),
                  _SkiGuideFilter.advanced =>
                    route.difficulty.toLowerCase().contains('advanced') ||
                        route.difficulty.toLowerCase().contains('expert'),
                  _ => false,
                },
              );
          return matchesSaved && matchesDifficulty;
        })
        .toList(growable: false);
  }

  List<_CragGroup> _groupClimbs(List<_ClimbEntry> entries) {
    final groups = <String, List<_ClimbEntry>>{};
    for (final entry in entries) {
      groups.putIfAbsent(entry.crag.id, () => []).add(entry);
    }
    return [
      for (final entries in groups.values)
        _CragGroup(crag: entries.first.crag, entries: entries),
    ]..sort((a, b) => a.crag.name.compareTo(b.crag.name));
  }

  List<_SkiAreaRoutes> _groupSkiRoutes(List<SkiRoute> routes) {
    final groups = <String, List<SkiRoute>>{};
    for (final route in routes) {
      groups.putIfAbsent(route.area, () => []).add(route);
    }
    return [
      for (final entry in groups.entries)
        _SkiAreaRoutes(area: entry.key, routes: entry.value),
    ]..sort((a, b) => a.area.compareTo(b.area));
  }

  void _openRouteDetails(ClimbRoute route) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.92,
        minChildSize: 0.62,
        maxChildSize: 0.98,
        builder: (context, controller) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
              children: [RouteCard(route: route, expanded: true)],
            ),
          ),
        ),
      ),
    );
  }

  void _openSkiDetails(SkiRoute route) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _SkiRouteDetails(route: route),
    );
  }
}

class _GuideHero extends StatelessWidget {
  const _GuideHero({
    required this.ski,
    required this.placeCount,
    required this.routeCount,
    required this.savedCount,
  });

  final bool ski;
  final int placeCount;
  final int routeCount;
  final int savedCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: PacificTerrainColors.navy,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  ski ? Icons.downhill_skiing : Icons.menu_book_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 9),
                Text(
                  ski ? 'WINTER FIELD GUIDE' : 'CLIMBING FIELD GUIDE',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              ski ? 'Plan an objective.' : 'Choose a line. Go climb.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: Colors.white,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              ski
                  ? 'Tour details, terrain context, and your shortlist—without the noise.'
                  : 'Routes, access beta, and your projects—organized for a day outside.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 18),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                _HeroStat(value: '$placeCount', label: ski ? 'AREAS' : 'CRAGS'),
                _HeroStat(
                  value: '$routeCount',
                  label: ski ? 'TOURS' : 'ROUTES',
                ),
                _HeroStat(value: '$savedCount', label: 'SAVED'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white60,
              fontSize: 9,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar<T> extends StatelessWidget {
  const _FilterBar({
    required this.values,
    required this.selectedValues,
    required this.allValue,
    required this.labelFor,
    required this.onSelected,
  });

  final List<T> values;
  final Set<T> selectedValues;
  final T allValue;
  final String Function(T value) labelFor;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            children: [
              for (final value in values)
                ChoiceChip(
                  label: Text(labelFor(value)),
                  selected: value == allValue
                      ? selectedValues.isEmpty
                      : selectedValues.contains(value),
                  onSelected: (_) => onSelected(value),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _ProjectShelf extends StatelessWidget {
  const _ProjectShelf({required this.entries, required this.onTap});

  final List<_ClimbEntry> entries;
  final ValueChanged<ClimbRoute> onTap;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading(
            title: 'Your shortlist',
            subtitle: 'Projects saved for the next good window.',
          ),
          SizedBox(
            height: 116,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: entries.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return _ShortlistCard(
                  title: entry.route.name,
                  grade: entry.route.grade,
                  place: entry.crag.name,
                  onTap: () => onTap(entry.route),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SkiProjectShelf extends StatelessWidget {
  const _SkiProjectShelf({required this.routes, required this.onTap});

  final List<SkiRoute> routes;
  final ValueChanged<SkiRoute> onTap;

  @override
  Widget build(BuildContext context) {
    if (routes.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading(
            title: 'Your shortlist',
            subtitle: 'Saved objectives for the right conditions.',
          ),
          SizedBox(
            height: 116,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: routes.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final route = routes[index];
                return _ShortlistCard(
                  title: route.name,
                  grade: route.difficulty,
                  place: route.area,
                  onTap: () => onTap(route),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortlistCard extends StatelessWidget {
  const _ShortlistCard({
    required this.title,
    required this.grade,
    required this.place,
    required this.onTap,
  });

  final String title;
  final String grade;
  final String place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        grade,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const Icon(Icons.bookmark, size: 18),
                  ],
                ),
                const Spacer(),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  place,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CragGuideGroup extends StatelessWidget {
  const _CragGuideGroup({
    required this.group,
    required this.climbLog,
    required this.onRouteTap,
  });

  final _CragGroup group;
  final ClimbLogState climbLog;
  final ValueChanged<ClimbRoute> onRouteTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: const Icon(Icons.landscape_outlined),
        ),
        title: Text(
          group.crag.name,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          '${group.crag.region} · ${group.entries.length} ${group.entries.length == 1 ? 'route' : 'routes'}',
        ),
        children: [
          for (final entry in group.entries)
            _ClimbRouteRow(
              entry: entry,
              completed: climbLog.isCompleted(entry.route),
              saved: climbLog.isProject(entry.route),
              onTap: () => onRouteTap(entry.route),
              onSave: () => climbLog.toggleProject(entry.route),
            ),
        ],
      ),
    );
  }
}

class _ClimbRouteRow extends StatelessWidget {
  const _ClimbRouteRow({
    required this.entry,
    required this.completed,
    required this.saved,
    required this.onTap,
    required this.onSave,
  });

  final _ClimbEntry entry;
  final bool completed;
  final bool saved;
  final VoidCallback onTap;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 9, 4, 9),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    entry.route.grade,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              entry.route.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (completed) ...[
                            const SizedBox(width: 5),
                            Icon(
                              Icons.check_circle,
                              size: 17,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ],
                        ],
                      ),
                      Text(
                        '${entry.wallName} · ${entry.route.typeLabel} · ${entry.route.pitchLabel}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: saved ? 'Remove project' : 'Save project',
                  onPressed: onSave,
                  icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SkiAreaGroup extends StatelessWidget {
  const _SkiAreaGroup({
    required this.group,
    required this.skiLog,
    required this.onRouteTap,
  });

  final _SkiAreaRoutes group;
  final SkiLogState skiLog;
  final ValueChanged<SkiRoute> onRouteTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: const Icon(Icons.downhill_skiing),
        ),
        title: Text(
          group.area,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          '${group.routes.first.region} · ${group.routes.length} objectives',
        ),
        children: [
          for (final route in group.routes)
            _SkiRouteRow(
              route: route,
              completed: skiLog.isCompleted(route),
              saved: skiLog.isProject(route),
              onTap: () => onRouteTap(route),
              onSave: () => skiLog.toggleProject(route),
            ),
        ],
      ),
    );
  }
}

class _SkiRouteRow extends StatelessWidget {
  const _SkiRouteRow({
    required this.route,
    required this.completed,
    required this.saved,
    required this.onTap,
    required this.onSave,
  });

  final SkiRoute route;
  final bool completed;
  final bool saved;
  final VoidCallback onTap;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ListTile(
        tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: onTap,
        leading: SizedBox(
          width: 52,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${route.distanceKm.toStringAsFixed(1)} km',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              Text(
                '${route.elevationGainMeters} m',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                route.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (completed) ...[
              const SizedBox(width: 5),
              Icon(
                Icons.check_circle,
                size: 17,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ],
        ),
        subtitle: Text(
          '${route.difficulty} · ${route.aspect} · ${route.slopeAngleLabel}',
        ),
        trailing: IconButton(
          tooltip: saved ? 'Remove saved tour' : 'Save tour',
          onPressed: onSave,
          icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
        ),
      ),
    );
  }
}

class _SkiRouteDetails extends ConsumerWidget {
  const _SkiRouteDetails({required this.route});

  final SkiRoute route;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skiLog = ref.watch(skiLogProvider);
    final saved = skiLog.isProject(route);
    final completed = skiLog.isCompleted(route);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.6,
      maxChildSize: 0.98,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
        children: [
          Text(
            route.name,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          Text('${route.area}, ${route.region}'),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 240,
              child: CachedNetworkImage(
                imageUrl: optimizedImageUrl(route.imageUrl, ImageVariant.card),
                fit: BoxFit.cover,
                memCacheWidth: 900,
                errorWidget: (_, _, _) => const ColoredBox(
                  color: PacificTerrainColors.navySoft,
                  child: Icon(
                    Icons.landscape_outlined,
                    color: Colors.white,
                    size: 52,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text('${route.distanceKm} km')),
              Chip(label: Text('${route.elevationGainMeters} m gain')),
              Chip(label: Text(route.difficulty)),
              Chip(label: Text(route.aspect)),
              Chip(label: Text(route.avalancheTerrain)),
              Chip(label: Text(route.slopeAngleLabel)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => skiLog.toggleTour(route),
                icon: Icon(completed ? Icons.check_circle : Icons.add_task),
                label: Text(completed ? 'Completed' : 'Log ski day'),
              ),
              OutlinedButton.icon(
                onPressed: () => skiLog.toggleProject(route),
                icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
                label: Text(saved ? 'Saved' : 'Save objective'),
              ),
              IconButton.outlined(
                tooltip: 'Share objective',
                onPressed: () => SharePlus.instance.share(
                  ShareParams(
                    subject: '${route.name} · Climb On',
                    text:
                        '${route.name} — ${route.distanceKm} km, ${route.elevationGainMeters} m gain, ${route.difficulty}, ${route.slopeAngleLabel}.',
                  ),
                ),
                icon: const Icon(Icons.ios_share),
              ),
            ],
          ),
          const Divider(height: 30),
          const _DetailSection(
            title: 'Slope angle & avalanche context',
            text:
                'Slope angle is one part of avalanche assessment. Check the current bulletin, snowpack, terrain traps, aspect, and conditions before travel.',
            warning: true,
          ),
          _DetailSection(title: 'Overview', text: route.description),
          _DetailSection(title: 'Approach', text: route.approachNotes),
          _DetailSection(title: 'Descent', text: route.descentNotes),
          _DetailSection(
            title: 'Hazards & conditions',
            text: route.dangerInfo,
            warning: true,
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.title,
    required this.text,
    this.warning = false,
  });

  final String title;
  final String text;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (warning) ...[
                Icon(
                  Icons.warning_amber,
                  size: 19,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(text),
        ],
      ),
    );
  }
}

class _FocusedRouteCard extends StatelessWidget {
  const _FocusedRouteCard({required this.route, required this.onTap});

  final ClimbRoute route;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            route.grade,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        title: Text(
          route.name,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text('${route.typeLabel} · ${route.pitchLabel}'),
        trailing: const Icon(Icons.arrow_outward),
        onTap: onTap,
      ),
    );
  }
}

class _GuideNotice extends StatelessWidget {
  const _GuideNotice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _EmptyGuideState extends StatelessWidget {
  const _EmptyGuideState({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
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

enum _ClimbGuideFilter {
  all('All'),
  boulder('Boulder'),
  sport('Sport'),
  trad('Trad'),
  deepWaterSolo('Deep Water Solo'),
  aid('Aid'),
  multiPitch('Multipitch');

  const _ClimbGuideFilter(this.label);
  final String label;
}

enum _SkiGuideFilter {
  all('All'),
  saved('Saved'),
  beginner('Beginner'),
  intermediate('Intermediate'),
  advanced('Advanced+');

  const _SkiGuideFilter(this.label);
  final String label;
}

class _ClimbEntry {
  const _ClimbEntry({
    required this.route,
    required this.crag,
    required this.wallName,
  });

  final ClimbRoute route;
  final Crag crag;
  final String wallName;
}

class _CragGroup {
  const _CragGroup({required this.crag, required this.entries});

  final Crag crag;
  final List<_ClimbEntry> entries;
}

class _SkiAreaRoutes {
  const _SkiAreaRoutes({required this.area, required this.routes});

  final String area;
  final List<SkiRoute> routes;
}
