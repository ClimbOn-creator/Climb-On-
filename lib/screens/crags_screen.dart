import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/crag.dart';
import '../models/climb_route.dart';
import '../models/ski_route.dart';
import '../services/database_service.dart';
import '../state/activity_mode_state.dart';
import '../state/admin_state.dart';
import '../state/catalog_state.dart';
import '../state/climb_log_state.dart';
import '../state/ski_route_state.dart';
import '../theme/climb_on_theme.dart';
import '../models/wall.dart';
import '../widgets/native_ad_card.dart';
import '../widgets/side_banner_layout.dart';
import '../widgets/admin_route_editor.dart';

class CragsScreen extends ConsumerStatefulWidget {
  const CragsScreen({super.key});

  @override
  ConsumerState<CragsScreen> createState() => _CragsScreenState();
}

class _CragsScreenState extends ConsumerState<CragsScreen> {
  String? selectedRangeId;

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(activityModeProvider);
    final catalog = ref.watch(catalogProvider);
    final skiCatalog = ref.watch(skiRouteCatalogProvider);
    final skiRoutes = skiCatalog.valueOrNull ?? const [];
    final catalogCrags = catalog.valueOrNull ?? const <Crag>[];
    final width = MediaQuery.sizeOf(context).width;
    final desktop = width >= 900;
    final initialRange = _mountainRanges.firstWhere(
      (range) => catalogCrags.any(range.matches),
      orElse: () => _mountainRanges.first,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SideBannerLayout(
        maxContentWidth: 1180,
        child: mode == ActivityMode.ski
            ? skiRoutes.isEmpty && skiCatalog.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _SkiCatalog(routes: skiRoutes, mode: mode, desktop: desktop)
            : catalogCrags.isEmpty && catalog.isLoading
            ? const Center(child: CircularProgressIndicator())
            : _RangeCatalog(
                crags: catalogCrags,
                selectedRangeId: selectedRangeId ?? initialRange.id,
                desktop: desktop,
                onRangeSelected: (range) {
                  setState(() => selectedRangeId = range.id);
                },
                onCragSelected: (crag) => _openCrag(context, ref, crag),
              ),
      ),
    );
  }

  void _openCrag(BuildContext context, WidgetRef ref, Crag crag) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return _CragRoutePicker(
          crag: crag,
          onRouteSelected: (route) {
            Navigator.pop(context);
            ref.read(focusedRouteProvider.notifier).state = route;
            context.go('/feed');
          },
        );
      },
    );
  }
}

class _RangeCatalog extends StatelessWidget {
  const _RangeCatalog({
    required this.crags,
    required this.selectedRangeId,
    required this.desktop,
    required this.onRangeSelected,
    required this.onCragSelected,
  });

  final List<Crag> crags;
  final String selectedRangeId;
  final bool desktop;
  final ValueChanged<_MountainRange> onRangeSelected;
  final ValueChanged<Crag> onCragSelected;

  @override
  Widget build(BuildContext context) {
    final selected = _mountainRanges.firstWhere(
      (range) => range.id == selectedRangeId,
      orElse: () => _mountainRanges.first,
    );
    final visibleCrags = crags
        .where((crag) => selected.matches(crag))
        .toList(growable: false);

    final content = ListView(
      padding: EdgeInsets.fromLTRB(
        desktop ? 28 : 16,
        desktop ? 30 : 22,
        desktop ? 28 : 16,
        40,
      ),
      children: [
        const _CatalogHeader(
          eyebrow: 'EXPLORE BRITISH COLUMBIA',
          title: 'Find your next crag',
          subtitle:
              'Choose a mountain range, then open a crag for walls, routes, access, and current conditions.',
        ),
        const SizedBox(height: 24),
        if (!desktop)
          SizedBox(
            height: 158,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _mountainRanges.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final range = _mountainRanges[index];
                return SizedBox(
                  width: 220,
                  child: _RangeCard(
                    range: range,
                    count: crags.where(range.matches).length,
                    selected: selected.id == range.id,
                    onTap: () => onRangeSelected(range),
                  ),
                );
              },
            ),
          ),
        if (!desktop) const SizedBox(height: 20),
        NativeAdCard(mode: ActivityMode.climb, compact: !desktop),
        _SelectedRangeHeader(range: selected, count: visibleCrags.length),
        const SizedBox(height: 14),
        if (visibleCrags.isEmpty)
          _EmptyRange(range: selected)
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 700 ? 2 : 1;
              final cardWidth = columns == 1
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 14) / 2;
              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  for (final crag in visibleCrags)
                    SizedBox(
                      width: cardWidth,
                      child: _CragCard(
                        crag: crag,
                        range: selected,
                        onTap: () => onCragSelected(crag),
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );

    if (!desktop) return content;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 282,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: PacificTerrainColors.mist,
              border: Border(
                right: BorderSide(color: PacificTerrainColors.line),
              ),
            ),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'MOUNTAIN RANGES',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: PacificTerrainColors.cedar,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 14),
                for (final range in _mountainRanges)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _RangeCard(
                      range: range,
                      count: crags.where(range.matches).length,
                      selected: selected.id == range.id,
                      onTap: () => onRangeSelected(range),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Expanded(child: content),
      ],
    );
  }
}

class _CatalogHeader extends StatelessWidget {
  const _CatalogHeader({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  final String eyebrow;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: PacificTerrainColors.cedar,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.7,
          ),
        ),
        const SizedBox(height: 5),
        Text(title, style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 7),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _RangeCard extends StatelessWidget {
  const _RangeCard({
    required this.range,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final _MountainRange range;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected
              ? PacificTerrainColors.cedar
              : PacificTerrainColors.line,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 136,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: range.imageUrl,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => const ColoredBox(
                  color: PacificTerrainColors.navySoft,
                  child: Icon(Icons.landscape, color: Colors.white),
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x11112D3B), Color(0xD9112D3B)],
                  ),
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 12,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            range.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(color: Colors.white),
                          ),
                          Text(
                            '$count ${count == 1 ? 'crag' : 'crags'}',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    if (selected)
                      const Icon(
                        Icons.arrow_forward,
                        size: 19,
                        color: Colors.white,
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

class _SelectedRangeHeader extends StatelessWidget {
  const _SelectedRangeHeader({required this.range, required this.count});

  final _MountainRange range;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                range.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 2),
              Text(
                range.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Text(
          '$count FOUND',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: PacificTerrainColors.cedar,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

class _CragCard extends StatelessWidget {
  const _CragCard({
    required this.crag,
    required this.range,
    required this.onTap,
  });

  final Crag crag;
  final _MountainRange range;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final routes = [for (final wall in crag.walls) ...wall.routes];
    final imageUrl = routes.isEmpty ? range.imageUrl : routes.first.imageUrl;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                CachedNetworkImage(
                  imageUrl: imageUrl,
                  height: 154,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => const SizedBox(
                    height: 154,
                    child: ColoredBox(color: PacificTerrainColors.seaGlass),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: PacificTerrainColors.cloud.withValues(alpha: 0.92),
                      shape: BoxShape.circle,
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        Icons.arrow_outward,
                        size: 18,
                        color: PacificTerrainColors.navy,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    crag.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${crag.region}, ${crag.province}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: PacificTerrainColors.cedar,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _CragMetric(label: 'ROUTES', value: '${routes.length}'),
                      _CragMetric(
                        label: 'WALLS',
                        value: '${crag.walls.length}',
                      ),
                      Expanded(
                        child: _CragMetric(label: 'SEASON', value: crag.season),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    crag.accessNotes,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      height: 1.45,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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

class _CragMetric extends StatelessWidget {
  const _CragMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 9,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: PacificTerrainColors.navy),
          ),
        ],
      ),
    );
  }
}

class _EmptyRange extends StatelessWidget {
  const _EmptyRange({required this.range});

  final _MountainRange range;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: PacificTerrainColors.seaGlass.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.landscape_outlined, size: 34),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'No ${range.name} crags are published yet. Add one when you have verified access and coordinates.',
            ),
          ),
        ],
      ),
    );
  }
}

class _SkiCatalog extends StatelessWidget {
  const _SkiCatalog({
    required this.routes,
    required this.mode,
    required this.desktop,
  });

  final List<SkiRoute> routes;
  final ActivityMode mode;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.all(desktop ? 28 : 16),
      children: [
        const _CatalogHeader(
          eyebrow: 'WINTER OBJECTIVES',
          title: 'Ski tours',
          subtitle:
              'Browse touring objectives, compare distance and vertical, then open the map for the full line.',
        ),
        const SizedBox(height: 22),
        NativeAdCard(mode: mode, compact: !desktop),
        for (final route in routes)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(12),
                leading: const CircleAvatar(
                  backgroundColor: PacificTerrainColors.seaGlass,
                  child: Icon(Icons.downhill_skiing),
                ),
                title: Text(route.name),
                subtitle: Text(
                  '${route.area} · ${route.distanceKm} km · ${route.elevationGainMeters} m',
                ),
                trailing: Chip(label: Text(route.difficulty)),
              ),
            ),
          ),
      ],
    );
  }
}

class _MountainRange {
  const _MountainRange({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.keywords,
  });

  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final List<String> keywords;

  bool matches(Crag crag) {
    final location = '${crag.region} ${crag.province}'.toLowerCase();
    return keywords.any(location.contains);
  }
}

const _mountainRanges = <_MountainRange>[
  _MountainRange(
    id: 'canadian-rockies',
    name: 'Canadian Rockies',
    description: 'Long limestone lines from the southern parks to the north.',
    imageUrl: 'https://images.unsplash.com/photo-1500534623283-312aade485b7',
    keywords: ['canadian rockies', 'rockies', 'canmore', 'banff', 'jasper'],
  ),
  _MountainRange(
    id: 'cariboo',
    name: 'Cariboo Mountains',
    description: 'The northernmost Columbia Mountains and their deep valleys.',
    imageUrl: 'https://images.unsplash.com/photo-1464278533981-50106e6176b1',
    keywords: ['cariboo', 'wells gray', 'valemount'],
  ),
  _MountainRange(
    id: 'selkirk',
    name: 'Selkirk Mountains',
    description: 'Steep Columbia Mountain terrain around Rogers Pass.',
    imageUrl: 'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b',
    keywords: ['selkirk', 'rogers pass', 'glacier national park'],
  ),
  _MountainRange(
    id: 'monashee',
    name: 'Monashee Mountains',
    description: 'Granite, alpine ridges, and the western Columbia Mountains.',
    imageUrl: 'https://images.unsplash.com/photo-1483728642387-6c3bdd6c93e5',
    keywords: ['monashee', 'revelstoke', 'north okanagan'],
  ),
  _MountainRange(
    id: 'purcell',
    name: 'Purcell Mountains',
    description: 'Bugaboo granite and the eastern Columbia Mountains.',
    imageUrl: 'https://images.unsplash.com/photo-1519681393784-d120267933ba',
    keywords: ['purcell', 'bugaboo', 'kimberley', 'cranbrook'],
  ),
  _MountainRange(
    id: 'hart',
    name: 'Hart Ranges',
    description: 'The southern Northern Rockies around the Pine Pass country.',
    imageUrl: 'https://images.unsplash.com/photo-1470770841072-f978cf4d019e',
    keywords: ['hart range', 'pine pass', 'tumbler ridge', 'chetwynd'],
  ),
  _MountainRange(
    id: 'muskwa',
    name: 'Muskwa Ranges',
    description: 'Remote limestone peaks of the northern Northern Rockies.',
    imageUrl: 'https://images.unsplash.com/photo-1464278533981-50106e6176b1',
    keywords: ['muskwa', 'northern rockies', 'muncho', 'fort nelson'],
  ),
  _MountainRange(
    id: 'coast-range',
    name: 'Coast Range',
    description: 'West-coast granite, island crags, and Sea to Sky walls.',
    imageUrl: 'https://images.unsplash.com/photo-1522163182402-834f871fd851',
    keywords: [
      'coast range',
      'coast mountain',
      'squamish',
      'whistler',
      'sea to sky',
      'lower mainland',
      'vancouver island',
      'victoria',
      'sooke',
      'uvic',
      'nanaimo',
      'comox',
    ],
  ),
];

class _CragRoutePicker extends ConsumerStatefulWidget {
  const _CragRoutePicker({required this.crag, required this.onRouteSelected});

  final Crag crag;
  final ValueChanged<ClimbRoute> onRouteSelected;

  @override
  ConsumerState<_CragRoutePicker> createState() => _CragRoutePickerState();
}

class _CragRoutePickerState extends ConsumerState<_CragRoutePicker> {
  Wall? selectedWall;
  late String dangerInfo;

  @override
  void initState() {
    super.initState();
    dangerInfo = widget.crag.dangerInfo;
  }

  @override
  Widget build(BuildContext context) {
    final walls = widget.crag.walls;
    final routes = [for (final wall in walls) ...wall.routes];
    final heroImageUrl = routes.isEmpty
        ? 'https://images.unsplash.com/photo-1522163182402-834f871fd851'
        : routes.first.imageUrl;
    final isAdmin = ref.watch(isMapAdminProvider).valueOrNull == true;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (context, scrollController) {
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.crag.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
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
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CachedNetworkImage(
                imageUrl: heroImageUrl,
                height: 230,
                width: double.infinity,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  label: Text('${widget.crag.region}, ${widget.crag.province}'),
                ),
                Chip(label: Text(widget.crag.season)),
                Chip(label: Text('${widget.crag.walls.length} walls')),
              ],
            ),
            const SizedBox(height: 12),
            _CragNotice(
              icon: Icons.warning_amber,
              label: dangerInfo,
              color: Theme.of(context).colorScheme.error,
              onEdit:
                  isAdmin ||
                      const DatabaseService().currentUserId ==
                          widget.crag.createdBy
                  ? _editWarning
                  : null,
            ),
            const SizedBox(height: 8),
            _CragNotice(
              icon: Icons.hiking,
              label: widget.crag.approachTrail,
              color: Theme.of(context).colorScheme.tertiary,
            ),
            const SizedBox(height: 8),
            _CragNotice(
              icon: Icons.lock_open,
              label: widget.crag.accessNotes,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 18),
            Text(
              'Walls',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final wall in walls)
                  ChoiceChip(
                    label: Text(wall.name),
                    selected: selectedWall == wall,
                    onSelected: (_) => setState(() => selectedWall = wall),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    selectedWall == null ? 'Select a wall' : 'Routes',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (isAdmin && selectedWall != null)
                  FilledButton.icon(
                    onPressed: () => _openRouteEditor(selectedWall!),
                    icon: const Icon(Icons.add),
                    label: const Text('Add route'),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (selectedWall == null)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Pick a wall to see its routes.'),
                ),
              )
            else if (selectedWall!.routes.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    isAdmin
                        ? 'No routes yet. Use Add route to create the first one.'
                        : 'No routes have been added to this wall yet.',
                  ),
                ),
              )
            else
              ...selectedWall!.routes.map(
                (route) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: ListTile(
                      leading: const Icon(Icons.route),
                      title: Text(route.name),
                      subtitle: Text(
                        '${route.grade} - ${route.typeLabel} - ${route.pitchLabel} - ${route.rating}/5',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isAdmin)
                            IconButton(
                              tooltip: 'Edit every route detail',
                              onPressed: () =>
                                  _openRouteEditor(selectedWall!, route: route),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                      onTap: () => widget.onRouteSelected(route),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _openRouteEditor(Wall wall, {ClimbRoute? route}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.94,
        child: AdminRouteEditor(wall: wall, route: route),
      ),
    );
    if (saved != true || !mounted) return;
    ref.invalidate(catalogProvider);
    Navigator.pop(context);
  }

  Future<void> _editWarning() async {
    final controller = TextEditingController(text: dangerInfo);
    final warning = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit crag warning'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(labelText: 'Safety warning'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (warning == null || warning.isEmpty || !mounted) return;
    try {
      await const DatabaseService().updateCreatorCragWarning(
        cragId: widget.crag.id,
        warning: warning,
      );
      if (!mounted) return;
      setState(() => dangerInfo = warning);
      ref.invalidate(catalogProvider);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update warning: $error')),
      );
    }
  }
}

class _CragNotice extends StatelessWidget {
  const _CragNotice({
    required this.icon,
    required this.label,
    required this.color,
    this.onEdit,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(label)),
            if (onEdit != null)
              IconButton(
                tooltip: 'Edit warning',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
              ),
          ],
        ),
      ),
    );
  }
}
